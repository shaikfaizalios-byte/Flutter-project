"""Models: ownership, naming, merging. Repeats: counting units, marks, naming prompts."""

import json
import uuid
from datetime import date
from pathlib import Path
from typing import Any

import pytest
from fastapi.testclient import TestClient
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.domain.counting import unit_key
from app.models.document import Document, DocumentStatus
from app.models.exam import Exam
from app.models.question import (
    Question,
    QuestionOption,
    QuestionOrigin,
    QuestionPattern,
    Topic,
    TopicStatus,
)
from app.models.user import User
from app.services.insights_service import InsightsService
from app.services.patterns import pattern_candidates
from tests.conftest import auth_headers, make_user

LISTS = Path(__file__).resolve().parents[1] / "data" / "model_lists"
ALIKE = "A train {} metres long crosses a pole in {} seconds. Find the speed of the train."
_numbers = iter(range(1, 100_000))


def _paper(
    db: Session,
    owner: User,
    name: str = "a.pdf",
    exam: str = "SSC_CHSL",
    *,
    on: date | None = None,
    shift: int | None = None,
) -> Document:
    document = Document(
        owner_id=owner.id,
        exam_code=exam,
        language="en",
        original_filename=name,
        size_bytes=1,
        sha256="0" * 64,
        storage_key=f"documents/{uuid.uuid4().hex}.pdf",
        page_count=1,
        status=DocumentStatus.COMPLETED,
        exam_date=on,
        exam_year=on.year if on else None,
        exam_shift=shift,
        paper_date_status="confirmed" if on else "unknown",
    )
    db.add(document)
    db.flush()
    return document


def _question(
    db: Session,
    document: Document,
    topic: Topic,
    stem: str | None = None,
    *,
    pattern: QuestionPattern | None = None,
    marks: float | None = None,
) -> Question:
    n = next(_numbers)
    question = Question(
        owner_id=document.owner_id,
        origin=QuestionOrigin.SOURCE,
        exam_code=document.exam_code,
        subject=topic.subject,
        topic_id=topic.id,
        topic_status=TopicStatus.CONFIRMED,
        pattern_id=pattern.id if pattern else None,
        pattern_status=TopicStatus.CONFIRMED if pattern else TopicStatus.UNASSIGNED,
        stem=stem or ALIKE.format(n, n),
        language="en",
        document_id=document.id,
        source_question_number=n,
        source_pages=[1],
        correct_option_position=1,
        marks=marks,
    )
    question.options = [QuestionOption(position=1, label="1", text="a")]
    db.add(question)
    db.flush()
    return question


def _topic(db: Session, name: str = "Percentage") -> Topic:
    return db.scalars(select(Topic).where(Topic.name == name)).one()


def _create(client: TestClient, topic: Topic, name: str) -> Any:
    return client.post("/api/v1/patterns", json={"topic_id": str(topic.id), "name": name})


def test_the_starter_list_file_equals_the_database(db_session: Session) -> None:
    data = json.loads((LISTS / "shared_aptitude.json").read_text(encoding="utf-8"))
    shared = db_session.execute(
        select(Topic.subject, Topic.name, QuestionPattern.name, QuestionPattern.keywords)
        .join(Topic, Topic.id == QuestionPattern.topic_id)
        .where(QuestionPattern.owner_id.is_(None), Topic.owner_id.is_(None))
    ).all()
    assert len(shared) == 91
    for subject, topic, name, keywords in shared:
        found = [m for m in data["subjects"][subject][topic] if m["name"] == name]
        assert found and found[0]["keywords"] == list(keywords)
    assert sum(len(m) for t in data["subjects"].values() for m in t.values()) == 91


def test_a_learner_can_add_a_model_to_a_shared_topic_and_it_stays_private(
    db_client: TestClient, db_session: Session, user: User
) -> None:
    topic = _topic(db_session)
    made = _create(db_client, topic, "Mixed percentages")
    assert made.status_code == 201, made.text
    assert made.json()["own"] is True
    mine = {c.name for c in pattern_candidates(db_session, user.id)}
    assert "Mixed percentages" in mine
    other = make_user(db_session, "other@example.com")
    assert "Mixed percentages" not in {c.name for c in pattern_candidates(db_session, other.id)}
    listed = db_client.get(
        "/api/v1/patterns", params={"topic_id": str(topic.id)}, headers=auth_headers(other)
    ).json()
    assert "Mixed percentages" not in [p["name"] for p in listed]


def test_the_same_name_as_a_shared_model_is_refused(
    db_client: TestClient, db_session: Session
) -> None:
    topic = _topic(db_session, "Venn Diagrams")
    response = _create(db_client, topic, "relationship between classes")
    assert response.status_code == 409


def test_two_learners_can_use_the_same_name(
    db_client: TestClient, db_session: Session, user: User
) -> None:
    topic = _topic(db_session)
    assert _create(db_client, topic, "Mine").status_code == 201
    other = auth_headers(make_user(db_session, "other@example.com"))
    second = db_client.post(
        "/api/v1/patterns", json={"topic_id": str(topic.id), "name": "Mine"}, headers=other
    )
    assert second.status_code == 201


def test_rename(db_client: TestClient, db_session: Session) -> None:
    topic = _topic(db_session)
    made = _create(db_client, topic, "Old").json()
    url = f"/api/v1/patterns/{made['id']}"
    renamed = db_client.patch(url, json={"name": "New"})
    assert renamed.status_code == 200, renamed.text
    assert renamed.json()["name"] == "New"


def test_rename_refuses_a_name_in_use(db_client: TestClient, db_session: Session) -> None:
    topic = _topic(db_session)
    _create(db_client, topic, "Taken")
    made = _create(db_client, topic, "Old").json()
    response = db_client.patch(f"/api/v1/patterns/{made['id']}", json={"name": "taken"})
    assert response.status_code == 409


def test_the_shared_list_cant_be_changed_by_a_learner(
    db_client: TestClient, db_session: Session
) -> None:
    shared = db_session.scalars(
        select(QuestionPattern).where(QuestionPattern.owner_id.is_(None))
    ).first()
    assert shared is not None
    url = f"/api/v1/patterns/{shared.id}"
    assert db_client.patch(url, json={"name": "Hacked"}).status_code == 404
    assert db_client.delete(url).status_code == 404


def test_merging_moves_the_questions_and_removes_the_model(
    db_client: TestClient, db_session: Session, user: User
) -> None:
    topic = _topic(db_session, "Venn Diagrams")
    made = _create(db_client, topic, "Duplicate").json()
    source = db_session.get(QuestionPattern, uuid.UUID(made["id"]))
    assert source is not None
    question = _question(db_session, _paper(db_session, user), topic, pattern=source)
    shared = db_session.scalars(
        select(QuestionPattern).where(
            QuestionPattern.topic_id == topic.id, QuestionPattern.owner_id.is_(None)
        )
    ).first()
    assert shared is not None

    merged = db_client.post(
        f"/api/v1/patterns/{made['id']}/merge", json={"into_id": str(shared.id)}
    )
    assert merged.status_code == 200, merged.text
    assert merged.json() == {"moved": 1}
    db_session.expire_all()
    assert db_session.get(Question, question.id).pattern_id == shared.id  # type: ignore[union-attr]
    assert db_session.get(QuestionPattern, uuid.UUID(made["id"])) is None


def test_merging_needs_the_same_topic(db_client: TestClient, db_session: Session) -> None:
    first = _create(db_client, _topic(db_session), "A").json()
    second = _create(db_client, _topic(db_session, "Venn Diagrams"), "B").json()
    response = db_client.post(
        f"/api/v1/patterns/{first['id']}/merge", json={"into_id": second["id"]}
    )
    assert response.status_code == 422


def test_a_model_cant_merge_into_itself(db_client: TestClient, db_session: Session) -> None:
    made = _create(db_client, _topic(db_session), "A").json()
    response = db_client.post(f"/api/v1/patterns/{made['id']}/merge", json={"into_id": made["id"]})
    assert response.status_code == 422


def test_another_learners_private_model_cant_be_used(
    db_client: TestClient, db_session: Session, user: User
) -> None:
    topic = _topic(db_session)
    other = make_user(db_session, "other@example.com")
    theirs = QuestionPattern(topic_id=topic.id, owner_id=other.id, name="Theirs", keywords=[])
    db_session.add(theirs)
    db_session.flush()
    question = _question(db_session, _paper(db_session, user), topic)
    response = db_client.patch(
        f"/api/v1/questions/{question.id}", json={"pattern_id": str(theirs.id)}
    )
    assert response.status_code == 422
    made = _create(db_client, topic, "Mine").json()
    merged = db_client.post(
        f"/api/v1/patterns/{made['id']}/merge", json={"into_id": str(theirs.id)}
    )
    assert merged.status_code == 422


def _alike(db: Session, owner: User, topic: Topic, papers: int) -> list[Question]:
    return [
        _question(db, _paper(db, owner, f"p{i}.pdf"), topic, ALIKE.format(100 + i, 10 + i))
        for i in range(papers)
    ]


def test_three_alike_questions_without_a_model_are_offered_for_naming(
    db_session: Session, user: User
) -> None:
    _alike(db_session, user, _topic(db_session), 3)
    report = InsightsService(db_session, user.id).repeats("SSC_CHSL")
    assert len(report.name_suggestions) == 1
    suggestion = report.name_suggestions[0]
    assert suggestion.topic_name == "Percentage" and suggestion.papers == 3
    assert len(suggestion.questions) == 3


def test_two_papers_are_not_enough(db_session: Session, user: User) -> None:
    _alike(db_session, user, _topic(db_session), 2)
    assert InsightsService(db_session, user.id).repeats("SSC_CHSL").name_suggestions == []


def test_three_in_one_paper_are_not_enough(db_session: Session, user: User) -> None:
    topic = _topic(db_session)
    paper = _paper(db_session, user)
    for i in range(3):
        _question(db_session, paper, topic, ALIKE.format(100 + i, 10 + i))
    assert InsightsService(db_session, user.id).repeats("SSC_CHSL").name_suggestions == []


def test_questions_with_a_model_arent_offered(db_session: Session, user: User) -> None:
    topic = _topic(db_session, "Venn Diagrams")
    model = db_session.scalars(
        select(QuestionPattern).where(QuestionPattern.topic_id == topic.id)
    ).first()
    for i in range(3):
        _question(
            db_session,
            _paper(db_session, user, f"p{i}.pdf"),
            topic,
            ALIKE.format(100 + i, 10 + i),
            pattern=model,
        )
    assert InsightsService(db_session, user.id).repeats("SSC_CHSL").name_suggestions == []


def test_naming_makes_a_private_model_and_confirms_the_questions(
    db_client: TestClient, db_session: Session, user: User
) -> None:
    topic = _topic(db_session)
    questions = _alike(db_session, user, topic, 3)
    named = db_client.post(
        "/api/v1/patterns/from-questions",
        json={
            "topic_id": str(topic.id),
            "name": "Speed of a train",
            "question_ids": [str(q.id) for q in questions],
        },
    )
    assert named.status_code == 201, named.text
    assert named.json()["own"] is True
    db_session.expire_all()
    for question in questions:
        fresh = db_session.get(Question, question.id)
        assert fresh is not None
        assert fresh.pattern_status == TopicStatus.CONFIRMED
    assert InsightsService(db_session, user.id).repeats("SSC_CHSL").name_suggestions == []


def test_naming_refuses_someone_elses_or_another_topics_questions(
    db_client: TestClient, db_session: Session, user: User
) -> None:
    topic = _topic(db_session)
    other = make_user(db_session, "other@example.com")
    theirs = _question(db_session, _paper(db_session, other), topic)
    elsewhere = _question(db_session, _paper(db_session, user), _topic(db_session, "Venn Diagrams"))
    for question in (theirs, elsewhere):
        response = db_client.post(
            "/api/v1/patterns/from-questions",
            json={"topic_id": str(topic.id), "name": "X", "question_ids": [str(question.id)]},
        )
        assert response.status_code == 422


def test_an_answer_format_list_is_added_once_to_a_topic(
    db_client: TestClient, db_session: Session
) -> None:
    topic = _topic(db_session, "Polity")
    url = f"/api/v1/topics/{topic.id}/default-models"
    first = db_client.post(url)
    assert first.status_code == 200, first.text
    names = {m["name"] for m in first.json()}
    assert {"Define", "Short note", "Compare", "Essay", "Letter"} <= names
    assert db_client.post(url).json() == []  # nothing left to add


def test_a_descriptive_stem_gets_a_suggestion_and_nothing_is_confirmed(
    db_client: TestClient, db_session: Session, user: User
) -> None:
    topic = _topic(db_session, "Polity")
    db_client.post(f"/api/v1/topics/{topic.id}/default-models")
    candidates = [c for c in pattern_candidates(db_session, user.id) if c.topic_id == topic.id]
    assert "Compare" in {c.name for c in candidates}
    other = make_user(db_session, "other@example.com")
    assert "Compare" not in {c.name for c in pattern_candidates(db_session, other.id)}


def test_a_paper_counts_itself_unless_the_exam_counts_sessions() -> None:
    first, second = uuid.uuid4(), uuid.uuid4()
    day = date(2026, 1, 21)

    def key(unit: str, doc: uuid.UUID, *, confirmed: bool = True, on: date | None = day) -> Any:
        return unit_key(
            unit, doc, confirmed=confirmed, exam_date=on, exam_shift=1, session_label=None
        )

    assert key("paper", first) != key("paper", second)
    assert key("session", first) == key("session", second)
    assert key("session", first, confirmed=False) != key("session", second, confirmed=False)
    assert key("session", first, on=None) != key("session", second, on=None)


def _session_exam(db: Session) -> str:
    db.add(Exam(code="SHIFTS", name="Shifts", counting_unit="session"))
    db.flush()
    return "SHIFTS"


def test_a_multi_shift_exam_counts_sittings_and_still_shows_years(
    db_session: Session, user: User
) -> None:
    exam = _session_exam(db_session)
    topic = Topic(subject="S", name="T", owner_id=user.id, exam_codes=[exam], keywords=[])
    db_session.add(topic)
    db_session.flush()
    day = date(2026, 1, 21)
    for name, shift in (("a.pdf", 1), ("a-set-b.pdf", 1), ("b.pdf", 2)):
        _question(db_session, _paper(db_session, user, name, exam, on=day, shift=shift), topic)
    report = InsightsService(db_session, user.id).repeats(exam)
    assert report.counting_unit == "session"
    assert report.papers.total == 2  # two sittings, three files
    assert report.topics[0].confirmed.papers == 2
    assert report.topics[0].confirmed.questions == 3
    assert [(y.year, y.questions) for y in report.topics[0].confirmed.years] == [(2026, 3)]


def test_exams_count_papers_by_default(db_session: Session, user: User) -> None:
    topic = _topic(db_session)
    day = date(2026, 1, 21)
    _question(db_session, _paper(db_session, user, "a.pdf", on=day, shift=1), topic)
    _question(db_session, _paper(db_session, user, "b.pdf", on=day, shift=1), topic)
    report = InsightsService(db_session, user.id).repeats("SSC_CHSL")
    assert report.counting_unit == "paper"
    assert report.papers.total == 2


def test_marks_add_up_only_where_they_are_known(db_session: Session, user: User) -> None:
    topic = _topic(db_session)
    paper = _paper(db_session, user)
    _question(db_session, paper, topic, marks=10)
    _question(db_session, paper, topic, marks=5)
    _question(db_session, paper, topic)
    assert InsightsService(db_session, user.id).repeats("SSC_CHSL").topics[0].confirmed.marks == 15


def test_no_marks_means_none_not_zero(db_session: Session, user: User) -> None:
    _question(db_session, _paper(db_session, user), _topic(db_session))
    assert (
        InsightsService(db_session, user.id).repeats("SSC_CHSL").topics[0].confirmed.marks is None
    )


@pytest.mark.parametrize("scope", ["shared", "all"])
def test_naming_is_only_offered_for_your_own_papers(
    db_session: Session, user: User, scope: Any
) -> None:
    _alike(db_session, user, _topic(db_session), 3)
    assert InsightsService(db_session, user.id).repeats("SSC_CHSL", scope).name_suggestions == []
