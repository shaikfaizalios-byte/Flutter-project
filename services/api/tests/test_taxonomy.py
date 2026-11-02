"""Canonical topics: seeded from the shared topics, suggested for learners' topics by name,
counted only once confirmed (global Phase 6)."""

import uuid
from typing import Any

from fastapi.testclient import TestClient
from sqlalchemy import func, select
from sqlalchemy.orm import Session

from app.domain.taxonomy import normalize, slug, suggest
from app.models.document import Document, DocumentStatus
from app.models.question import Question, QuestionOption, QuestionOrigin, Topic, VerificationStatus
from app.models.taxonomy import TaxonomyLabel, TaxonomyNode, TopicTaxonomyLink
from app.models.user import User
from tests.conftest import auth_headers, make_user

# --- rules -------------------------------------------------------------------------------


def test_names_compare_without_case_spacing_ampersands_or_plurals() -> None:
    assert normalize("Ratio & Proportions") == normalize("ratio and proportion")
    assert normalize("  Time,  Speed and Distance ") == normalize("Time Speed and Distance")
    assert normalize("Glass") == "glass"  # "ss" is not a plural
    assert normalize("Analogies") == normalize("Analogy")
    assert normalize("Series") == "series"
    assert slug("Time, Speed and Distance") == "time-speed-and-distance"


def test_a_suggestion_needs_exactly_one_matching_topic() -> None:
    labels = {"a": ["Percentage"], "b": ["Series"], "c": ["Number Series", "Series"]}

    found = suggest("percentages", labels)
    assert found is not None and found.node_id == "a"
    assert suggest("Series", labels) is None  # two candidates: no guess
    assert suggest("Algebra", labels) is None


# --- seeded data -------------------------------------------------------------------------


def test_every_shared_topic_is_its_own_canonical_topic(db_session: Session) -> None:
    shared = db_session.scalars(select(Topic).where(Topic.owner_id.is_(None))).all()
    links = db_session.scalars(
        select(TopicTaxonomyLink).where(TopicTaxonomyLink.topic_id.in_([t.id for t in shared]))
    ).all()

    assert len(links) == len(shared) > 0
    assert {(link.status, link.source) for link in links} == {("confirmed", "migration")}
    subjects = db_session.scalar(
        select(func.count()).select_from(TaxonomyNode).where(TaxonomyNode.kind == "subject")
    )
    assert subjects == len({t.subject for t in shared})
    languages = set(db_session.scalars(select(TaxonomyLabel.language)).all())
    assert languages == {"en"}  # no unreviewed translations


def test_the_canonical_tree_is_readable(db_client: TestClient) -> None:
    tree = db_client.get("/api/v1/taxonomy").json()

    quant = next(s for s in tree if s["label"] == "Quantitative Aptitude")
    assert quant["key"] == "quantitative-aptitude"
    assert any(t["key"] == "quantitative-aptitude/percentage" for t in quant["topics"])


# --- learners' topics --------------------------------------------------------------------


def own_topic(client: TestClient, name: str, subject: str = "Maths") -> dict[str, Any]:
    response = client.post(
        "/api/v1/topics", json={"exam_code": "SSC_CGL", "subject": subject, "name": name}
    )
    assert response.status_code == 201, response.text
    data: dict[str, Any] = response.json()
    return data


def test_an_own_topic_with_a_shared_name_gets_a_suggestion_only(db_client: TestClient) -> None:
    topic = own_topic(db_client, "Percentages")
    other = own_topic(db_client, "Vedic tricks")

    assert topic["canonical"]["status"] == "suggested"
    assert topic["canonical"]["label"] == "Percentage"
    assert topic["canonical"]["subject_label"] == "Quantitative Aptitude"
    assert "Same name" in topic["canonical"]["reason"]
    assert other["canonical"] is None
    shared = next(
        t
        for t in db_client.get("/api/v1/exams/SSC_CGL/topics").json()
        if not t["own"] and t["name"] == "Percentage"
    )
    assert shared["canonical"]["status"] == "confirmed"


def test_the_learner_confirms_or_rejects_and_a_rejection_sticks(db_client: TestClient) -> None:
    topic = own_topic(db_client, "Percentages")
    node = topic["canonical"]["node_id"]

    rejected = db_client.put(
        f"/api/v1/topics/{topic['id']}/canonical", json={"node_id": node, "confirmed": False}
    ).json()
    assert rejected["canonical"] is None
    renamed = db_client.patch(f"/api/v1/topics/{topic['id']}", json={"name": "Percentage"}).json()
    assert renamed["canonical"] is None  # not suggested again after "not the same"

    confirmed = db_client.put(
        f"/api/v1/topics/{topic['id']}/canonical", json={"node_id": node, "confirmed": True}
    ).json()
    assert confirmed["canonical"]["status"] == "confirmed"
    assert confirmed["canonical"]["reason"] is None


def test_only_the_topic_owner_decides(db_client: TestClient, db_session: Session) -> None:
    topic = own_topic(db_client, "Percentages")
    other = make_user(db_session, email="other@example.com")

    response = db_client.put(
        f"/api/v1/topics/{topic['id']}/canonical",
        json={"node_id": topic["canonical"]["node_id"], "confirmed": True},
        headers=auth_headers(other),
    )
    shared = db_session.scalar(select(Topic).where(Topic.owner_id.is_(None)).limit(1))
    assert shared is not None
    on_shared = db_client.put(
        f"/api/v1/topics/{shared.id}/canonical",
        json={"node_id": topic["canonical"]["node_id"], "confirmed": False},
    )

    assert response.status_code == 404
    assert on_shared.status_code == 404  # shared topics' links are not the learner's


# --- mocks count sections by canonical id ------------------------------------------------


def test_confirmed_own_topics_count_toward_the_right_mock_section(
    db_client: TestClient, db_session: Session, user: User
) -> None:
    topic = own_topic(db_client, "Analogies", subject="Reasoning Ability")
    doc = Document(
        owner_id=user.id,
        exam_code="SSC_CGL",
        language="en",
        original_filename="mine.pdf",
        size_bytes=1,
        sha256="0" * 64,
        storage_key=f"documents/{uuid.uuid4().hex}.pdf",
        page_count=1,
        status=DocumentStatus.COMPLETED,
    )
    db_session.add(doc)
    db_session.flush()
    for number in range(1, 4):
        question = Question(
            owner_id=user.id,
            origin=QuestionOrigin.SOURCE,
            exam_code="SSC_CGL",
            subject="Reasoning Ability",  # not the CGL section's name
            topic_id=uuid.UUID(topic["id"]),
            stem=f"Analogy {number}?",
            language="en",
            document_id=doc.id,
            source_question_number=number,
            source_pages=[1],
            correct_option_position=1,
            verification_status=VerificationStatus.VERIFIED,
        )
        question.options = [
            QuestionOption(position=i, label=str(i), text=f"opt {i}") for i in range(1, 5)
        ]
        db_session.add(question)
    db_session.flush()

    def reasoning_available() -> int:
        [cgl] = db_client.get("/api/v1/practice/mock-tests", params={"exam": "SSC_CGL"}).json()
        section = next(s for s in cgl["sections"] if s["subject"].startswith("General Intel"))
        count: int = section["available"]
        return count

    assert reasoning_available() == 0  # a suggestion doesn't count
    db_client.put(
        f"/api/v1/topics/{topic['id']}/canonical",
        json={"node_id": topic["canonical"]["node_id"], "confirmed": True},
    )
    assert reasoning_available() == 3
