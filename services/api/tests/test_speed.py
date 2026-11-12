"""Speed training: the target per question comes from the verified format only (else the
learner's own), and right-but-slow is counted per question type."""

import uuid
from datetime import date

import pytest
from fastapi.testclient import TestClient
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.domain import speed
from app.models.document import Document
from app.models.question import ExamFormat, Question, QuestionPattern, Topic
from app.schemas.practice import AnswerUpdate, PracticeCreate
from app.services.exam_formats import mock_formats
from app.services.practice_service import PracticeService
from tests.test_analytics import api, clock  # noqa: F401  (fixtures)
from tests.test_practice import Clock, document, make_question  # noqa: F401  (fixtures)

P = uuid.uuid4()


def answered(correct: bool, ms: int | None, subject: str | None = "Maths") -> speed.Answered:
    return speed.Answered(P, "Percent of a number", "Percentage", subject, correct, ms)


def test_the_target_is_the_format_s_seconds_per_question() -> None:
    whole = speed.format_target(
        name="Paper", duration_minutes=60, total_questions=100, sections=[], sectional_timing=False
    )
    assert whole is not None and whole.seconds == 36 and whole.source == "format"
    timed = speed.format_target(
        name="Paper",
        duration_minutes=60,
        total_questions=100,
        sections=[{"subject": "Maths", "timer_minutes": 15, "questions": 25}],
        sectional_timing=True,
    )
    assert timed is not None and timed.for_subject("Maths") == 36 and timed.for_subject("x") == 36
    nothing = speed.format_target(
        name=None, duration_minutes=None, total_questions=None, sections=[], sectional_timing=False
    )
    assert nothing is None
    assert speed.own_target(None) is None
    own = speed.own_target(40)
    assert own is not None and own.source == "own" and own.seconds == 40


def test_right_but_slow_needs_a_right_answer_slower_than_the_factor() -> None:
    target = speed.own_target(40)
    rows = speed.speed_by_type(
        [
            answered(True, 30_000),
            answered(True, 61_000),  # 61 s > 1.5 x 40 s: slow
            answered(True, 60_000),  # exactly 1.5 x: not slow
            answered(False, 90_000),  # wrong, so not "right but slow"
            answered(True, None),  # untimed
        ],
        target,
        1.5,
    )
    row = rows[0]
    assert (row.answered, row.correct, row.timed_answered) == (5, 4, 4)
    assert row.time_spent_ms == 241_000 and row.slow_correct == 1 and row.target_seconds == 40
    assert speed.speed_by_type([answered(True, 99_000)], None, 1.5)[0].slow_correct == 0


@pytest.fixture
def pattern(db_session: Session) -> QuestionPattern:
    topic = Topic(subject="Quantitative Aptitude", name="Speed Percentage", keywords=[])
    db_session.add(topic)
    db_session.flush()
    row = QuestionPattern(topic_id=topic.id, name="Speed: percent of a number", keywords=[])
    db_session.add(row)
    db_session.flush()
    return row


def test_the_api_uses_the_verified_format_and_counts_slow_answers(
    api: TestClient,  # noqa: F811
    db_session: Session,
    document: Document,  # noqa: F811
    clock: Clock,  # noqa: F811
    pattern: QuestionPattern,
) -> None:
    verified = next(iter(mock_formats(db_session, "SSC_CHSL", date.today())), None)
    if verified is None:
        pytest.skip("no verified SSC CHSL format in this database")
    questions = [make_question(db_session, document) for _ in range(3)]
    for q in questions:
        q.pattern_id = pattern.id
    db_session.flush()
    owner = db_session.scalar(select(Question.owner_id).where(Question.id == questions[0].id))
    assert owner is not None
    service = PracticeService(db_session, owner_id=owner, now=clock)
    session = service.start_practice(PracticeCreate(pattern_id=pattern.id, count=3))
    target = speed.format_target(
        name=verified.name,
        duration_minutes=verified.duration_minutes,
        total_questions=verified.total_questions,
        sections=verified.sections or [],
        sectional_timing=verified.sectional_timing,
    )
    assert target is not None
    seconds = target.for_subject("Quantitative Aptitude")
    assert seconds is not None
    slow_ms = int(seconds * 1.5 * 1000) + 1_000
    for position, (choice, spent) in enumerate([(1, 5_000), (1, slow_ms), (2, 5_000)], start=1):
        service.answer(
            session.id,
            position,
            AnswerUpdate(selected_position=choice, client_seq=position, time_spent_ms=spent),
        )

    report = api.get(
        "/api/v1/analytics/speed", params={"exam": "SSC_CHSL", "own_target_seconds": 300}
    ).json()
    assert report["target"]["source"] == "format"  # the learner's own target is ignored here
    assert report["target"]["format_name"] == verified.name and report["slow_factor"] == 1.5
    row = next(t for t in report["types"] if t["name"] == "Speed: percent of a number")
    assert (row["answered"], row["correct"], row["slow_correct"]) == (3, 2, 1)
    assert row["timed_answered"] == 3 and row["topic"] == "Speed Percentage"


def test_an_exam_without_a_format_uses_only_the_learners_own_target(
    api: TestClient,  # noqa: F811
    db_session: Session,
) -> None:
    exam = "NO_FORMAT_EXAM"
    assert db_session.scalar(select(ExamFormat).where(ExamFormat.exam_code == exam)) is None
    none = api.get("/api/v1/analytics/speed", params={"exam": exam}).json()
    assert none["target"] is None and none["types"] == []
    own = api.get("/api/v1/analytics/speed", params={"exam": exam, "own_target_seconds": 45}).json()
    assert own["target"] == {
        "source": "own",
        "format_name": None,
        "seconds": 45.0,
        "by_section": {},
    }


def test_a_timed_drill_keeps_its_time_per_question(
    api: TestClient,  # noqa: F811
    db_session: Session,
    document: Document,  # noqa: F811
    pattern: QuestionPattern,
) -> None:
    for _ in range(2):
        make_question(db_session, document).pattern_id = pattern.id
    db_session.flush()
    started = api.post(
        "/api/v1/practice/sessions",
        json={"pattern_id": str(pattern.id), "count": 2, "per_question_seconds": 36},
    )
    assert started.status_code == 201, started.text
    assert started.json()["per_question_seconds"] == 36
    again = api.get(f"/api/v1/practice/sessions/{started.json()['id']}").json()
    assert again["per_question_seconds"] == 36
    too_short = api.post("/api/v1/practice/sessions", json={"per_question_seconds": 2})
    assert too_short.status_code == 422
