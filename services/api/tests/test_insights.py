"""Repeated topics and patterns across the learner's own papers, paper dates and pattern review.

Counts must state their basis: reviewed (confirmed) classifications apart from suggestions,
years only from confirmed paper dates, and only this account's non-rejected source questions.
"""

import uuid
from typing import Any

from fastapi.testclient import TestClient
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.models.document import Document, DocumentStatus
from app.models.question import (
    Question,
    QuestionOption,
    QuestionOrigin,
    QuestionPattern,
    Topic,
    TopicStatus,
    VerificationStatus,
)
from app.models.user import User
from tests.conftest import make_user

VENN_STEM = (
    "Select the Venn diagram that best illustrates the relationship between the following "
    "classes. Nurses, Doctors, Pharmacists"
)


def _paper(db: Session, owner: User, name: str, year: int | None, confirmed: bool) -> Document:
    doc = Document(
        owner_id=owner.id,
        exam_code="SSC_CHSL",
        language="en",
        original_filename=name,
        size_bytes=1,
        sha256="0" * 64,
        storage_key=f"documents/{uuid.uuid4().hex}.pdf",
        page_count=1,
        status=DocumentStatus.COMPLETED,
        segmentation_status="completed",
        exam_year=year,
        paper_date_status="confirmed" if confirmed else ("suggested" if year else "unknown"),
    )
    db.add(doc)
    db.flush()
    return doc


_numbers = iter(range(1, 100_000))


def _question(
    db: Session,
    doc: Document,
    *,
    stem: str = VENN_STEM,
    topic: Topic | None = None,
    topic_status: str = TopicStatus.CONFIRMED,
    pattern: QuestionPattern | None = None,
    pattern_status: str = TopicStatus.CONFIRMED,
    status: str = VerificationStatus.UNVERIFIED,
    origin: str = QuestionOrigin.SOURCE,
) -> Question:
    number = next(_numbers)
    q = Question(
        owner_id=doc.owner_id,
        origin=origin,
        exam_code="SSC_CHSL",
        subject=topic.subject if topic else None,
        topic_id=topic.id if topic else None,
        topic_status=topic_status if topic else TopicStatus.UNASSIGNED,
        pattern_id=pattern.id if pattern else None,
        pattern_status=pattern_status if pattern else TopicStatus.UNASSIGNED,
        stem=stem,
        language="en",
        document_id=doc.id if origin == QuestionOrigin.SOURCE else None,
        source_question_number=number if origin == QuestionOrigin.SOURCE else None,
        source_pages=[1],
        correct_option_position=1,
        verification_status=status,
        ai_provider="fake" if origin == QuestionOrigin.AI else None,
        ai_model="fake" if origin == QuestionOrigin.AI else None,
        ai_prompt_version="v1" if origin == QuestionOrigin.AI else None,
    )
    q.options = [QuestionOption(position=i, label=str(i), text=f"o{i}") for i in range(1, 5)]
    db.add(q)
    db.flush()
    return q


def _topic(db: Session, name: str) -> Topic:
    return db.scalars(select(Topic).where(Topic.name == name)).one()


def _pattern(db: Session, topic: Topic, name: str) -> QuestionPattern:
    return db.scalars(
        select(QuestionPattern).where(
            QuestionPattern.topic_id == topic.id, QuestionPattern.name == name
        )
    ).one()


def _report(client: TestClient) -> dict[str, Any]:
    response = client.get("/api/v1/insights/repeats", params={"exam": "SSC_CHSL"})
    assert response.status_code == 200, response.text
    data: dict[str, Any] = response.json()
    return data


def test_report_counts_reviewed_apart_from_suggestions_with_its_basis(
    db_client: TestClient, db_session: Session, user: User
) -> None:
    venn = _topic(db_session, "Venn Diagrams")
    classes = _pattern(db_session, venn, "Relationship between classes")
    reading = _pattern(db_session, venn, "Reading a given diagram")
    p2019 = _paper(db_session, user, "chsl-2019.pdf", 2019, confirmed=True)
    p2021 = _paper(db_session, user, "chsl-2021.pdf", 2021, confirmed=True)
    guessed = _paper(
        db_session, user, "chsl-2022.pdf", 2022, confirmed=False
    )  # not counted by year

    _question(db_session, p2019, topic=venn, pattern=classes)
    _question(db_session, p2019, topic=venn, pattern=classes, stem=VENN_STEM + " again")
    _question(db_session, p2021, topic=venn, pattern=classes)
    _question(db_session, guessed, topic=venn, pattern=classes)
    _question(db_session, p2021, topic=venn, pattern=reading, pattern_status=TopicStatus.SUGGESTED)
    _question(db_session, guessed, topic=venn, topic_status=TopicStatus.SUGGESTED)
    # Never counted: rejected, AI-generated, another account's.
    _question(db_session, p2019, topic=venn, pattern=classes, status=VerificationStatus.REJECTED)
    _question(db_session, p2019, topic=venn, origin=QuestionOrigin.AI)
    other = make_user(db_session, "other@example.com")
    _question(db_session, _paper(db_session, other, "theirs.pdf", 2019, True), topic=venn)

    report = _report(db_client)
    assert report["papers"] == {"total": 3, "dated": 2, "undated": 1, "years": [2019, 2021]}
    topic = next(t for t in report["topics"] if t["name"] == "Venn Diagrams")
    assert topic["confirmed"] == {
        "questions": 5,
        "papers": 3,
        "years": [{"year": 2019, "questions": 2}, {"year": 2021, "questions": 2}],
    }
    assert topic["unreviewed"] == 1
    assert topic["without_pattern"] == 1  # the one whose pattern is only suggested
    by_name = {p["name"]: p for p in topic["patterns"]}
    assert by_name["Relationship between classes"]["confirmed"]["questions"] == 4
    assert by_name["Relationship between classes"]["confirmed"]["papers"] == 3
    assert by_name["Reading a given diagram"]["confirmed"]["questions"] == 0
    assert by_name["Reading a given diagram"]["unreviewed"] == 1
    assert topic["patterns"][0]["name"] == "Relationship between classes"  # most papers first

    # Worded alike (numbers aside) in different papers -> one similarity group.
    group = report["similar_groups"][0]
    assert group["papers"] == 3
    assert group["topic_name"] == "Venn Diagrams"
    assert group["years"] == [2019, 2021]
    assert {q["document_filename"] for q in group["questions"]} == {
        "chsl-2019.pdf",
        "chsl-2021.pdf",
        "chsl-2022.pdf",
    }
    assert report["similarity_threshold"] == 0.8


def test_empty_report(db_client: TestClient) -> None:
    report = _report(db_client)
    assert report["papers"]["total"] == 0
    assert report["topics"] == [] and report["similar_groups"] == []


def test_paper_date_is_confirmed_by_the_reviewer(
    db_client: TestClient, db_session: Session, user: User
) -> None:
    doc = _paper(db_session, user, "chsl.pdf", 2019, confirmed=False)
    url = f"/api/v1/documents/{doc.id}/paper-date"

    response = db_client.put(url, json={"exam_date": "2019-07-02", "exam_shift": 3})
    assert response.status_code == 200, response.text
    body = response.json()
    assert (body["exam_year"], body["exam_date"], body["exam_shift"]) == (2019, "2019-07-02", 3)
    assert body["paper_date_status"] == "confirmed" and body["paper_date_reason"] is None

    mismatch = db_client.put(url, json={"exam_year": 2020, "exam_date": "2019-07-02"})
    assert mismatch.status_code == 422
    assert db_client.put(url, json={"exam_shift": 12}).status_code == 422

    unknown = db_client.put(url, json={})  # "date unknown", confirmed
    assert unknown.json()["paper_date_status"] == "confirmed"
    assert unknown.json()["exam_year"] is None

    other = make_user(db_session, "other@example.com")
    theirs = _paper(db_session, other, "theirs.pdf", None, confirmed=False)
    assert db_client.put(f"/api/v1/documents/{theirs.id}/paper-date", json={}).status_code == 404


def test_pattern_review_rules(db_client: TestClient, db_session: Session, user: User) -> None:
    venn = _topic(db_session, "Venn Diagrams")
    analogy = _topic(db_session, "Analogy")
    classes = _pattern(db_session, venn, "Relationship between classes")
    word = _pattern(db_session, analogy, "Word analogy")
    doc = _paper(db_session, user, "p.pdf", None, confirmed=False)
    q = _question(
        db_session,
        doc,
        topic=venn,
        topic_status=TopicStatus.SUGGESTED,
        pattern=classes,
        pattern_status=TopicStatus.SUGGESTED,
    )
    url = f"/api/v1/questions/{q.id}"

    listed = db_client.get("/api/v1/patterns", params={"topic_id": str(venn.id)}).json()
    assert [p["name"] for p in listed][:2] == [
        "Relationship between classes",
        "Reading a given diagram",
    ]

    # A pattern of another topic is refused.
    assert db_client.patch(url, json={"pattern_id": str(word.id)}).status_code == 422

    # Choosing the pattern confirms it, and the topic with it.
    body = db_client.patch(url, json={"pattern_id": str(classes.id)}).json()
    assert body["pattern"]["name"] == "Relationship between classes"
    assert body["pattern_status"] == "confirmed" and body["topic_status"] == "confirmed"

    # Changing the topic re-suggests a pattern of the new topic (or none).
    body = db_client.patch(url, json={"topic_id": str(analogy.id)}).json()
    assert body["pattern"] is None and body["pattern_status"] == "unassigned"

    # Listing by pattern.
    db_client.patch(url, json={"topic_id": str(venn.id), "pattern_id": str(classes.id)})
    found = db_client.get("/api/v1/questions", params={"pattern_id": str(classes.id)}).json()
    assert [item["id"] for item in found["items"]] == [str(q.id)]


def test_approving_and_accept_all_confirm_suggested_patterns(
    db_client: TestClient, db_session: Session, user: User
) -> None:
    venn = _topic(db_session, "Venn Diagrams")
    classes = _pattern(db_session, venn, "Relationship between classes")
    doc = _paper(db_session, user, "p.pdf", None, confirmed=False)
    first = _question(
        db_session,
        doc,
        topic=venn,
        topic_status=TopicStatus.SUGGESTED,
        pattern=classes,
        pattern_status=TopicStatus.SUGGESTED,
    )
    second = _question(
        db_session,
        doc,
        topic=venn,
        topic_status=TopicStatus.SUGGESTED,
        pattern=classes,
        pattern_status=TopicStatus.SUGGESTED,
    )

    summary = db_client.get(f"/api/v1/documents/{doc.id}/parse-summary").json()
    assert summary["patterns_suggested"] == 2
    assert summary["paper_date"] == {
        "exam_year": None,
        "exam_date": None,
        "exam_shift": None,
        "status": "unknown",
        "reason": None,
    }

    body = db_client.patch(
        f"/api/v1/questions/{first.id}", json={"verification_status": "verified"}
    ).json()
    assert body["pattern_status"] == "confirmed"

    result = db_client.post(f"/api/v1/documents/{doc.id}/topics/accept").json()
    assert result == {"accepted": 1, "patterns_accepted": 1}
    assert db_client.get(f"/api/v1/questions/{second.id}").json()["pattern_status"] == "confirmed"


def test_practice_by_pattern(db_client: TestClient, db_session: Session, user: User) -> None:
    venn = _topic(db_session, "Venn Diagrams")
    classes = _pattern(db_session, venn, "Relationship between classes")
    doc = _paper(db_session, user, "p.pdf", None, confirmed=False)
    wanted = _question(db_session, doc, topic=venn, pattern=classes, status="verified")
    _question(db_session, doc, topic=venn, status="verified")

    response = db_client.post(
        "/api/v1/practice/sessions", json={"pattern_id": str(classes.id), "count": 5}
    )
    assert response.status_code == 201, response.text
    assert [i["question_id"] for i in response.json()["items"]] == [str(wanted.id)]
