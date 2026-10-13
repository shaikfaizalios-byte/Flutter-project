"""Practice sessions and mock tests: selection rules, feedback, idempotent answers and
submission, server-side timer (simulated restarts), format-based marking, bookmarks,
incorrect-answer review and history."""

import uuid
from collections.abc import Iterator
from datetime import UTC, datetime, timedelta
from typing import Any

import pytest
from fastapi.testclient import TestClient
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.api.v1.endpoints.practice import get_practice_service
from app.core.config import Settings
from app.integrations.storage import LocalDocumentStorage
from app.main import create_app
from app.models.document import Document, DocumentStatus
from app.models.question import (
    ExamFormat,
    Question,
    QuestionOption,
    QuestionOrigin,
    Topic,
    VerificationStatus,
)
from app.services.practice_service import PracticeService

T0 = datetime(2026, 10, 14, 9, 0, tzinfo=UTC)
CHSL_SUBJECTS = [
    "English Language",
    "General Intelligence",
    "Quantitative Aptitude",
    "General Awareness",
]


class Clock:
    def __init__(self) -> None:
        self.now = T0

    def __call__(self) -> datetime:
        return self.now


@pytest.fixture
def clock() -> Clock:
    return Clock()


@pytest.fixture
def api(
    settings: Settings,
    db_engine: Any,
    db_session: Session,
    storage: LocalDocumentStorage,
    clock: Clock,
) -> Iterator[TestClient]:
    from app.database.session import get_session

    app = create_app(settings, engine=db_engine, storage=storage)
    app.dependency_overrides[get_session] = lambda: db_session
    app.dependency_overrides[get_practice_service] = lambda: PracticeService(db_session, now=clock)
    with TestClient(app, raise_server_exceptions=False) as client:
        yield client


@pytest.fixture
def document(db_session: Session) -> Document:
    doc = Document(
        exam_code="SSC_CHSL",
        language="en",
        original_filename="sample.pdf",
        size_bytes=1,
        sha256="0" * 64,
        storage_key=f"documents/{uuid.uuid4().hex}.pdf",
        page_count=1,
        status=DocumentStatus.COMPLETED,
    )
    db_session.add(doc)
    db_session.flush()
    return doc


_number = iter(range(1, 100_000))


def make_question(
    db: Session,
    doc: Document,
    *,
    subject: str = "Quantitative Aptitude",
    status: VerificationStatus = VerificationStatus.VERIFIED,
    answer: int | None = 1,
    image: bool = False,
    topic: Topic | None = None,
    stem: str | None = None,
    explanation: str | None = "Because.",
) -> Question:
    number = next(_number)
    question = Question(
        origin=QuestionOrigin.SOURCE,
        exam_code="SSC_CHSL",
        section=subject,
        subject=subject,
        topic_id=topic.id if topic else None,
        stem=stem or f"Question {number}?",
        language="en",
        document_id=doc.id,
        source_question_number=number,
        source_pages=[1],
        correct_option_position=answer,
        explanation=explanation,
        image_dependent=image,
        verification_status=status,
    )
    question.options = [
        QuestionOption(position=i, label=str(i), text=f"opt {i}") for i in range(1, 5)
    ]
    db.add(question)
    db.flush()
    return question


def start(api: TestClient, **body: Any) -> dict[str, Any]:
    response = api.post("/api/v1/practice/sessions", json=body)
    assert response.status_code == 201, response.text
    data: dict[str, Any] = response.json()
    return data


def answer(api: TestClient, session_id: str, position: int, selected: int | None, seq: int) -> Any:
    return api.put(
        f"/api/v1/practice/sessions/{session_id}/answers/{position}",
        json={"selected_position": selected, "client_seq": seq},
    )


# --- practice selection ---------------------------------------------------------------


def test_practice_uses_only_reviewed_answerable_text_questions(
    api: TestClient, db_session: Session, document: Document
) -> None:
    good = make_question(db_session, document)
    make_question(db_session, document, status=VerificationStatus.UNVERIFIED)
    make_question(db_session, document, status=VerificationStatus.REJECTED)
    make_question(db_session, document, image=True)
    make_question(db_session, document, answer=None)

    session = start(api, count=10)

    assert session["mode"] == "practice"
    assert [i["question_id"] for i in session["items"]] == [str(good.id)]
    item = session["items"][0]
    assert item["verified"] is True
    assert item["origin"] == "source"
    assert item["source"] == {
        "document_filename": "sample.pdf",
        "page": 1,
        "question_number": good.source_question_number,
    }
    assert item["feedback"] is None  # nothing answered yet


def test_unverified_questions_only_on_request_and_labelled(
    api: TestClient, db_session: Session, document: Document
) -> None:
    make_question(db_session, document, status=VerificationStatus.UNVERIFIED)

    refused = api.post("/api/v1/practice/sessions", json={"count": 5})
    assert refused.status_code == 422
    assert refused.json()["error"]["code"] == "no_questions_available"

    session = start(api, count=5, include_unverified=True)
    assert [i["verified"] for i in session["items"]] == [False]


def test_topic_and_subject_filters(
    api: TestClient, db_session: Session, document: Document
) -> None:
    topic = db_session.scalars(select(Topic).where(Topic.name == "Percentage")).one()
    tagged = make_question(db_session, document, topic=topic)
    make_question(db_session, document, subject="English Language")

    by_topic = start(api, topic_id=str(topic.id))
    by_subject = start(api, subject="English Language")
    mixed = start(api, count=10)

    assert [i["question_id"] for i in by_topic["items"]] == [str(tagged.id)]
    assert [i["subject"] for i in by_subject["items"]] == ["English Language"]
    assert len(mixed["items"]) == 2


# --- answering ------------------------------------------------------------------------


def test_practice_feedback_is_immediate_and_answers_are_final(
    api: TestClient, db_session: Session, document: Document
) -> None:
    make_question(db_session, document, answer=3, explanation="x = 3")
    session = start(api)
    sid = session["id"]

    wrong = answer(api, sid, 1, 2, seq=10).json()
    assert wrong["applied"] is True
    assert wrong["feedback"] == {"correct_position": 3, "is_correct": False, "explanation": "x = 3"}

    # A second try after seeing the feedback does not change the answer.
    retry = answer(api, sid, 1, 3, seq=11).json()
    assert retry["applied"] is False
    assert retry["selected_position"] == 2


def test_answer_replays_are_idempotent_and_order_safe(
    api: TestClient, db_session: Session, document: Document, clock: Clock
) -> None:
    for _ in range(25):
        make_question(db_session, document, subject="English Language")
    make_formats_ready(db_session, document)
    mock = api.post(
        "/api/v1/practice/mock-tests", json={"exam_format_code": "SSC_CHSL_2026_TIER1"}
    ).json()
    sid = mock["id"]

    assert answer(api, sid, 1, 2, seq=100).json()["applied"] is True
    assert answer(api, sid, 1, 2, seq=100).json()["applied"] is False  # exact replay
    assert answer(api, sid, 1, 4, seq=50).json()["applied"] is False  # older, arrives late
    newer = answer(api, sid, 1, 3, seq=200).json()
    assert (newer["applied"], newer["selected_position"]) == (True, 3)
    cleared = answer(api, sid, 1, None, seq=300).json()
    assert cleared["selected_position"] is None


def test_invalid_answers_are_rejected(
    api: TestClient, db_session: Session, document: Document
) -> None:
    make_question(db_session, document)
    sid = start(api)["id"]

    assert answer(api, sid, 9, 1, seq=1).status_code == 422
    assert answer(api, sid, 1, 6, seq=1).json()["error"]["code"] == "invalid_answer"
    assert answer(api, str(uuid.uuid4()), 1, 1, seq=1).status_code == 404


# --- submission -----------------------------------------------------------------------


def test_practice_submit_scores_and_is_idempotent(
    api: TestClient, db_session: Session, document: Document, clock: Clock
) -> None:
    for answer_position in (1, 2, 3):
        make_question(db_session, document, answer=answer_position)
    session = start(api, count=3)
    sid = session["id"]
    items = session["items"]
    correct_for: dict[int, int] = {}
    for i in items:
        question = db_session.get(Question, uuid.UUID(i["question_id"]))
        assert question is not None and question.correct_option_position is not None
        correct_for[i["position"]] = question.correct_option_position
    answer(api, sid, 1, correct_for[1], seq=1)
    answer(api, sid, 2, (correct_for[2] % 4) + 1, seq=2)
    clock.now = T0 + timedelta(minutes=7)

    first = api.post(f"/api/v1/practice/sessions/{sid}/submit").json()
    clock.now = T0 + timedelta(minutes=9)
    second = api.post(f"/api/v1/practice/sessions/{sid}/submit").json()

    result = first["result"]
    assert (result["correct"], result["wrong"], result["unattempted"]) == (1, 1, 1)
    assert result["score"] == 1.0
    assert result["max_score"] == 3.0
    assert result["time_taken_seconds"] == 420
    assert "no negative marking" in result["marking_note"]
    assert result["explanation"].endswith("Total 1.00 of 3.00")
    assert second["submitted_at"] == first["submitted_at"]
    assert second["result"] == result
    # After submission every item shows its answer and explanation.
    assert all(i["feedback"] is not None for i in second["items"])
    closed = answer(api, sid, 3, 1, seq=99)
    assert closed.status_code == 409
    assert closed.json()["error"]["code"] == "session_closed"


# --- mock tests -----------------------------------------------------------------------


def make_formats_ready(db: Session, doc: Document, per_section: int = 25) -> None:
    """Ensure every CHSL Tier-I section has enough verified questions."""
    for subject in CHSL_SUBJECTS:
        have = len(
            db.scalars(
                select(Question).where(
                    Question.subject == subject,
                    Question.verification_status == VerificationStatus.VERIFIED,
                )
            ).all()
        )
        for _ in range(max(0, per_section - have)):
            make_question(db, doc, subject=subject)


def test_mock_unavailable_without_enough_reviewed_questions(
    api: TestClient, db_session: Session, document: Document
) -> None:
    for _ in range(3):
        make_question(db_session, document, subject="General Awareness")

    [availability] = api.get("/api/v1/practice/mock-tests", params={"exam": "SSC_CHSL"}).json()
    response = api.post(
        "/api/v1/practice/mock-tests", json={"exam_format_code": "SSC_CHSL_2026_TIER1"}
    )

    assert availability["available"] is False
    assert availability["exam_code"] == "SSC_CHSL"
    awareness = next(s for s in availability["sections"] if s["subject"] == "General Awareness")
    assert (awareness["available"], awareness["needed"]) == (3, 25)
    assert response.status_code == 422
    assert response.json()["error"]["code"] == "not_enough_questions"
    assert "General Awareness: 3 of 25" in response.json()["error"]["message"]


def test_mock_structure_timer_and_marking_come_from_the_verified_format(
    api: TestClient, db_session: Session, document: Document
) -> None:
    make_formats_ready(db_session, document)
    exam_format = db_session.scalars(select(ExamFormat)).one()

    mock = api.post("/api/v1/practice/mock-tests", json={"exam_format_code": exam_format.code})

    assert mock.status_code == 201, mock.text
    data = mock.json()
    assert data["mode"] == "mock"
    assert data["item_count"] == exam_format.total_questions == 100
    assert data["deadline_at"] == (T0 + timedelta(minutes=60)).isoformat().replace("+00:00", "Z")
    assert data["remaining_seconds"] == 3600
    sections: dict[str, int] = {}
    for item in data["items"]:
        sections[item["section"]] = sections.get(item["section"], 0) + 1
        assert item["feedback"] is None  # no hints during a mock
    assert sorted(sections.values()) == [25, 25, 25, 25]


def test_timer_survives_restarts_and_expiry_auto_submits_saved_answers(
    api: TestClient, db_session: Session, document: Document, clock: Clock
) -> None:
    make_formats_ready(db_session, document)
    sid = api.post(
        "/api/v1/practice/mock-tests", json={"exam_format_code": "SSC_CHSL_2026_TIER1"}
    ).json()["id"]
    answer(api, sid, 1, 1, seq=1)  # every generated question's answer is option 1
    answer(api, sid, 2, 2, seq=2)

    # "Restart": a fresh service instance 10 minutes later sees the same server deadline.
    clock.now = T0 + timedelta(minutes=10)
    restarted = PracticeService(db_session, now=clock).get(uuid.UUID(sid))
    assert restarted.status == "active"
    assert restarted.remaining_seconds == 50 * 60
    assert restarted.answered_count == 2

    # Past the deadline: reading the session submits it with the saved answers.
    clock.now = T0 + timedelta(minutes=61)
    expired = api.get(f"/api/v1/practice/sessions/{sid}").json()
    assert expired["status"] == "submitted"
    assert expired["submit_reason"] == "time_up"
    assert expired["submitted_at"].startswith("2026-10-14T10:00:00")  # capped at the deadline
    result = expired["result"]
    assert (result["correct"], result["wrong"], result["unattempted"]) == (1, 1, 98)
    assert result["score"] == 1.5  # +2.00 - 0.50 from the format
    assert result["max_score"] == 200.0
    assert "Wrong answer: -0.50" in result["marking_note"]
    assert "13.8" in result["marking_note"]  # cites the official source
    assert len(result["sections"]) == 4
    assert answer(api, sid, 3, 1, seq=3).status_code == 409


def test_mock_section_marking_matches_format(
    api: TestClient, db_session: Session, document: Document
) -> None:
    make_formats_ready(db_session, document)
    data = api.post(
        "/api/v1/practice/mock-tests", json={"exam_format_code": "SSC_CHSL_2026_TIER1"}
    ).json()
    sid = data["id"]
    awareness = [i["position"] for i in data["items"] if i["section"] == "General Awareness"]
    for n, position in enumerate(awareness[:22]):
        answer(api, sid, position, 1 if n < 18 else 2, seq=n + 1)  # 18 right, 4 wrong

    result = api.post(f"/api/v1/practice/sessions/{sid}/submit").json()["result"]

    [section] = [s for s in result["sections"] if s["name"] == "General Awareness"]
    assert (section["score"], section["max_score"]) == (34.0, 50.0)
    assert section["explanation"] == (
        "Correct 18 × 2.00 = 36.00; Wrong 4 × −0.50 = −2.00; Unattempted 3 × 0 = 0; "
        "Total 34.00 of 50.00"
    )


# --- bookmarks, incorrect answers, history ----------------------------------------------


def test_bookmarks(api: TestClient, db_session: Session, document: Document) -> None:
    question = make_question(db_session, document)
    url = f"/api/v1/questions/{question.id}/bookmark"

    assert api.put(url).status_code == 204
    assert api.put(url).status_code == 204  # idempotent
    assert [q["id"] for q in api.get("/api/v1/practice/bookmarks").json()["items"]] == [
        str(question.id)
    ]
    assert start(api)["items"][0]["bookmarked"] is True
    assert api.delete(url).status_code == 204
    assert api.get("/api/v1/practice/bookmarks").json()["items"] == []
    assert api.put(f"/api/v1/questions/{uuid.uuid4()}/bookmark").status_code == 404


def test_incorrect_review_and_history(
    api: TestClient, db_session: Session, document: Document, clock: Clock
) -> None:
    question = make_question(db_session, document, answer=1)
    sid = start(api)["id"]
    answer(api, sid, 1, 2, seq=1)

    assert [q["id"] for q in api.get("/api/v1/practice/incorrect").json()["items"]] == [
        str(question.id)
    ]

    clock.now = T0 + timedelta(hours=1)
    sid2 = start(api)["id"]
    answer(api, sid2, 1, 1, seq=1)

    assert api.get("/api/v1/practice/incorrect").json()["items"] == []  # latest answer is right
    history = api.get(f"/api/v1/questions/{question.id}/history").json()
    assert (history["attempts"], history["correct"], history["wrong"]) == (2, 1, 1)
    assert history["last_result"] == "correct"


def test_mock_answers_count_for_review_only_after_submission(
    api: TestClient, db_session: Session, document: Document
) -> None:
    make_formats_ready(db_session, document)
    data = api.post(
        "/api/v1/practice/mock-tests", json={"exam_format_code": "SSC_CHSL_2026_TIER1"}
    ).json()
    sid = data["id"]
    answer(api, sid, 1, 2, seq=1)  # wrong (generated answers are all option 1)

    assert api.get("/api/v1/practice/incorrect").json()["items"] == []
    api.post(f"/api/v1/practice/sessions/{sid}/submit")
    assert len(api.get("/api/v1/practice/incorrect").json()["items"]) == 1


def test_session_history_list(
    api: TestClient, db_session: Session, document: Document, clock: Clock
) -> None:
    make_question(db_session, document)
    first = start(api)["id"]
    api.post(f"/api/v1/practice/sessions/{first}/submit")
    clock.now = T0 + timedelta(minutes=5)
    second = start(api)["id"]

    listing = api.get("/api/v1/practice/sessions").json()

    assert [s["id"] for s in listing["items"]] == [second, first]
    assert listing["items"][1]["status"] == "submitted"
    assert listing["items"][1]["score"] == 0.0
    assert listing["items"][0]["status"] == "active"
