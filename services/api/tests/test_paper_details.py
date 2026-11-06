"""Paper details, other sets of a paper, translations and descriptive fields."""

import uuid
from typing import Any

import pytest
from fastapi.testclient import TestClient
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.domain.paper_duplicates import looks_like_same_paper, shared_share
from app.models.document import Document, DocumentStatus
from app.models.question import (
    Passage,
    Question,
    QuestionOption,
    QuestionOrigin,
    Topic,
    TopicStatus,
)
from app.models.user import User
from app.services.insights_service import InsightsService
from tests.conftest import auth_headers, make_user

STEMS = [f"What is the capital of country number {n} in the list given here?" for n in range(6)]
_numbers = iter(range(1, 100_000))


def test_sets_hold_the_same_questions_in_another_order() -> None:
    assert looks_like_same_paper(STEMS, list(reversed(STEMS)))
    assert shared_share(STEMS, STEMS[:3]) == 1.0


def test_the_same_questions_with_other_numbers_are_another_paper() -> None:
    other = [s.replace("number", "number 9") for s in STEMS]
    assert not looks_like_same_paper(STEMS, other)


def test_a_few_shared_questions_prove_nothing() -> None:
    assert not looks_like_same_paper(STEMS[:3], STEMS[:3])
    assert not looks_like_same_paper(STEMS, [*STEMS[:4], "x", "y"])
    assert shared_share([], STEMS) == 0.0


def _paper(db: Session, owner: User, name: str = "a.pdf", exam: str = "SSC_CHSL") -> Document:
    document = Document(
        owner_id=owner.id,
        exam_code=exam,
        language="en",
        original_filename=name,
        size_bytes=1,
        sha256=uuid.uuid4().hex + uuid.uuid4().hex,
        storage_key=f"documents/{uuid.uuid4().hex}.pdf",
        page_count=1,
        status=DocumentStatus.COMPLETED,
    )
    db.add(document)
    db.flush()
    return document


def _question(
    db: Session, document: Document, stem: str, topic: Topic | None = None, language: str = "en"
) -> Question:
    question = Question(
        owner_id=document.owner_id,
        origin=QuestionOrigin.SOURCE,
        exam_code=document.exam_code,
        subject=topic.subject if topic else None,
        topic_id=topic.id if topic else None,
        topic_status=TopicStatus.CONFIRMED if topic else TopicStatus.UNASSIGNED,
        stem=stem,
        language=language,
        document_id=document.id,
        source_question_number=next(_numbers),
        source_pages=[1],
        correct_option_position=1,
    )
    question.options = [QuestionOption(position=1, label="1", text="a")]
    db.add(question)
    db.flush()
    return question


def _topic(db: Session) -> Topic:
    return db.scalars(select(Topic).where(Topic.name == "Percentage")).one()


def test_paper_details_are_saved(db_client: TestClient, db_session: Session, user: User) -> None:
    paper = _paper(db_session, user)
    saved = db_client.put(
        f"/api/v1/documents/{paper.id}/details",
        json={
            "stage": "Tier-I",
            "session_label": "January",
            "set_code": "B",
            "extra_languages": ["hi"],
        },
    )
    assert saved.status_code == 200, saved.text
    data = saved.json()
    assert (data["stage"], data["session_label"], data["set_code"]) == ("Tier-I", "January", "B")
    assert data["extra_languages"] == ["hi"]


def test_saving_details_leaves_the_rest_alone(
    db_client: TestClient, db_session: Session, user: User
) -> None:
    paper = _paper(db_session, user)
    url = f"/api/v1/documents/{paper.id}/details"
    db_client.put(url, json={"stage": "Tier-I", "set_code": "B"})
    assert db_client.put(url, json={"set_code": "C"}).json()["stage"] == "Tier-I"


def _report(db: Session, owner: User) -> Any:
    return InsightsService(db, owner.id).repeats("SSC_CHSL")


def test_another_set_of_a_paper_counts_once(
    db_client: TestClient, db_session: Session, user: User
) -> None:
    topic = _topic(db_session)
    first, second = _paper(db_session, user, "set-a.pdf"), _paper(db_session, user, "set-b.pdf")
    _question(db_session, first, STEMS[0], topic)
    _question(db_session, second, STEMS[0], topic)
    before = _report(db_session, user)
    assert before.papers.total == 2 and before.topics[0].confirmed.papers == 2

    response = db_client.put(
        f"/api/v1/documents/{second.id}/details", json={"duplicate_of_id": str(first.id)}
    )
    assert response.status_code == 200, response.text

    after = _report(db_session, user)
    assert after.papers.total == 1
    assert (after.topics[0].confirmed.papers, after.topics[0].confirmed.questions) == (1, 1)


def test_a_suggestion_alone_changes_no_count(
    db_client: TestClient, db_session: Session, user: User
) -> None:
    topic = _topic(db_session)
    first, second = _paper(db_session, user, "set-a.pdf"), _paper(db_session, user, "set-b.pdf")
    for stem in STEMS:
        _question(db_session, first, stem, topic)
    for stem in reversed(STEMS):
        _question(db_session, second, stem, topic)
    found = db_client.get(f"/api/v1/documents/{second.id}/duplicate-suggestions").json()
    assert [(d["document_id"], d["shared_share"]) for d in found] == [(str(first.id), 1.0)]
    assert _report(db_session, user).papers.total == 2


def test_no_suggestion_across_exams_or_accounts(
    db_client: TestClient, db_session: Session, user: User
) -> None:
    mine = _paper(db_session, user)
    other_exam = _paper(db_session, user, exam="SSC_CGL")
    theirs = _paper(db_session, make_user(db_session, "other@example.com"))
    for paper in (mine, other_exam, theirs):
        for stem in STEMS:
            _question(db_session, paper, stem)
    assert db_client.get(f"/api/v1/documents/{mine.id}/duplicate-suggestions").json() == []


@pytest.mark.parametrize("case", ["itself", "other_exam", "theirs", "chain"])
def test_impossible_duplicates_are_refused(
    db_client: TestClient, db_session: Session, user: User, case: str
) -> None:
    paper = _paper(db_session, user)
    target = {
        "itself": paper,
        "other_exam": _paper(db_session, user, exam="SSC_CGL"),
        "theirs": _paper(db_session, make_user(db_session, "other@example.com")),
        "chain": _paper(db_session, user, "b.pdf"),
    }[case]
    if case == "chain":
        target.duplicate_of_id = _paper(db_session, user, "c.pdf").id
        db_session.flush()
    response = db_client.put(
        f"/api/v1/documents/{paper.id}/details", json={"duplicate_of_id": str(target.id)}
    )
    assert response.status_code == 422


def test_a_paper_others_point_to_cant_become_a_duplicate(
    db_client: TestClient, db_session: Session, user: User
) -> None:
    first, second = _paper(db_session, user, "a.pdf"), _paper(db_session, user, "b.pdf")
    third = _paper(db_session, user, "c.pdf")
    second.duplicate_of_id = first.id
    db_session.flush()
    response = db_client.put(
        f"/api/v1/documents/{first.id}/details", json={"duplicate_of_id": str(third.id)}
    )
    assert response.status_code == 422


def test_a_paper_can_be_unmarked(db_client: TestClient, db_session: Session, user: User) -> None:
    first, second = _paper(db_session, user, "a.pdf"), _paper(db_session, user, "b.pdf")
    url = f"/api/v1/documents/{second.id}/details"
    db_client.put(url, json={"duplicate_of_id": str(first.id)})
    assert db_client.put(url, json={"duplicate_of_id": None}).json()["duplicate_of_id"] is None


def test_a_question_in_two_languages_counts_once(
    db_client: TestClient, db_session: Session, user: User
) -> None:
    topic = _topic(db_session)
    paper = _paper(db_session, user)
    english = _question(db_session, paper, STEMS[0], topic)
    hindi = _question(db_session, paper, "प्रश्न एक", topic, language="hi")
    assert _report(db_session, user).topics[0].confirmed.questions == 2

    linked = db_client.put(
        f"/api/v1/questions/{hindi.id}/translation-of", json={"question_id": str(english.id)}
    )
    assert linked.status_code == 200, linked.text
    assert linked.json()["translation_of_id"] == str(english.id)
    assert _report(db_session, user).topics[0].confirmed.questions == 1

    db_client.put(f"/api/v1/questions/{hindi.id}/translation-of", json={"question_id": None})
    assert _report(db_session, user).topics[0].confirmed.questions == 2


def test_impossible_translations_are_refused(
    db_client: TestClient, db_session: Session, user: User
) -> None:
    paper = _paper(db_session, user)
    question = _question(db_session, paper, STEMS[0])
    same_language = _question(db_session, paper, STEMS[1])
    theirs = _question(
        db_session, _paper(db_session, make_user(db_session, "o@example.com")), "x", language="hi"
    )
    url = f"/api/v1/questions/{question.id}/translation-of"
    for target in (question, same_language):
        assert db_client.put(url, json={"question_id": str(target.id)}).status_code == 422
    assert db_client.put(url, json={"question_id": str(theirs.id)}).status_code == 404


def test_another_learner_cant_touch_a_paper(
    db_client: TestClient, db_session: Session, user: User
) -> None:
    paper = _paper(db_session, user)
    other = auth_headers(make_user(db_session, "other@example.com"))
    url = f"/api/v1/documents/{paper.id}"
    assert db_client.put(f"{url}/details", json={"stage": "x"}, headers=other).status_code == 404
    assert db_client.get(f"{url}/duplicate-suggestions", headers=other).status_code == 404


def test_descriptive_fields_are_set_in_review(
    db_client: TestClient, db_session: Session, user: User
) -> None:
    question = _question(db_session, _paper(db_session, user), STEMS[0])
    parts = [{"label": "a", "text": "Define it", "marks": 2}, {"label": "b", "text": "Compare"}]
    saved = db_client.patch(
        f"/api/v1/questions/{question.id}",
        json={"marks": 10, "word_limit": 250, "sub_parts": parts, "choice_group": "Q5"},
    )
    assert saved.status_code == 200, saved.text
    data = saved.json()
    assert (data["marks"], data["word_limit"], data["choice_group"]) == (10, 250, "Q5")
    assert data["sub_parts"][0] == {"label": "a", "text": "Define it", "marks": 2.0}


@pytest.mark.parametrize(
    "body", [{"marks": -1}, {"word_limit": 0}, {"sub_parts": [{"label": "a"}]}]
)
def test_impossible_descriptive_fields_are_refused(
    db_client: TestClient, db_session: Session, user: User, body: dict[str, Any]
) -> None:
    question = _question(db_session, _paper(db_session, user), STEMS[0])
    assert db_client.patch(f"/api/v1/questions/{question.id}", json=body).status_code == 422


def test_a_passage_says_what_it_is(db_client: TestClient, db_session: Session, user: User) -> None:
    paper = _paper(db_session, user)
    passage = Passage(document_id=paper.id, text="A table of sales", source_pages=[1])
    db_session.add(passage)
    db_session.flush()
    question = _question(db_session, paper, STEMS[0])
    question.passage_id = passage.id
    db_session.flush()
    url = f"/api/v1/passages/{passage.id}/kind"
    saved = db_client.put(url, json={"kind": "table"})
    assert saved.status_code == 200, saved.text
    assert saved.json()["kind"] == "table"
    assert db_client.put(url, json={"kind": "poem"}).status_code == 422
    other = auth_headers(make_user(db_session, "other@example.com"))
    assert db_client.put(url, json={"kind": "case"}, headers=other).status_code == 404
