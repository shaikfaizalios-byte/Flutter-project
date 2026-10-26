"""The shared bank: publishing needs a rights basis and verified questions with shared topics;
other learners see only verified questions, read-only, labelled with the recorded source, in
practice, mocks, question reading and repeats. Also: verifying a paper's clean questions."""

import uuid
from collections.abc import Iterator
from typing import Any

import pytest
from fastapi.testclient import TestClient
from sqlalchemy.orm import Session

from app.core.config import Settings
from app.domain.errors import ConflictError
from app.domain.segmentation import IssueCode
from app.integrations.storage import LocalDocumentStorage
from app.main import create_app
from app.models.document import Document, DocumentStatus
from app.models.question import QuestionIssue, Topic, TopicStatus, VerificationStatus
from app.models.user import User
from app.services import shared_bank
from tests.conftest import auth_headers, make_user
from tests.test_practice import make_question

RIGHTS = "Published by the exam body on its website; may be reproduced for study."
SOURCE = "SSC CHSL 2024 Tier-I, 2 July 2024, shift 1 (official question paper)"


def make_document(db: Session, owner: User, filename: str = "publisher-notes.pdf") -> Document:
    doc = Document(
        owner_id=owner.id,
        exam_code="SSC_CHSL",
        language="en",
        original_filename=filename,
        size_bytes=1,
        sha256="0" * 64,
        storage_key=f"documents/{uuid.uuid4().hex}.pdf",
        page_count=1,
        status=DocumentStatus.COMPLETED,
        segmentation_status="completed",
    )
    db.add(doc)
    db.flush()
    return doc


@pytest.fixture
def publisher(db_session: Session) -> User:
    return make_user(db_session, "operator@example.com")


@pytest.fixture
def shared_topic(db_session: Session) -> Topic:
    topic = Topic(subject="Quantitative Aptitude", name="Shared Percentage", keywords=[])
    db_session.add(topic)
    db_session.flush()
    return topic


@pytest.fixture
def paper(db_session: Session, publisher: User, shared_topic: Topic) -> Document:
    doc = make_document(db_session, publisher)
    for _ in range(3):
        q = make_question(db_session, doc, topic=shared_topic)
        q.topic_status = TopicStatus.CONFIRMED
    make_question(db_session, doc, status=VerificationStatus.UNVERIFIED, topic=shared_topic)
    db_session.flush()
    return doc


@pytest.fixture
def api(
    settings: Settings,
    db_engine: Any,
    db_session: Session,
    storage: LocalDocumentStorage,
    user: User,
) -> Iterator[TestClient]:
    from app.database.session import get_session

    app = create_app(settings, engine=db_engine, storage=storage)
    app.dependency_overrides[get_session] = lambda: db_session
    with TestClient(app, raise_server_exceptions=False, headers=auth_headers(user)) as client:
        yield client


def test_publishing_needs_rights_verified_questions_and_shared_topics(
    db_session: Session, publisher: User, paper: Document
) -> None:
    with pytest.raises(ConflictError) as missing:
        shared_bank.publish(db_session, paper.id, rights_basis=" ", source=SOURCE)
    assert missing.value.code == "rights_required"

    empty = make_document(db_session, publisher, "empty.pdf")
    make_question(db_session, empty, status=VerificationStatus.UNVERIFIED)
    with pytest.raises(ConflictError) as nothing:
        shared_bank.publish(db_session, empty.id, rights_basis=RIGHTS, source=SOURCE)
    assert nothing.value.code == "nothing_verified"

    private = make_document(db_session, publisher, "private.pdf")
    own_topic = Topic(subject="Maths", name="My Own Topic", keywords=[], owner_id=publisher.id)
    db_session.add(own_topic)
    db_session.flush()
    make_question(db_session, private, topic=own_topic)
    with pytest.raises(ConflictError) as hidden:
        shared_bank.publish(db_session, private.id, rights_basis=RIGHTS, source=SOURCE)
    assert hidden.value.code == "private_topics"
    assert "My Own Topic" in str(hidden.value)

    result = shared_bank.publish(db_session, paper.id, rights_basis=RIGHTS, source=SOURCE)
    assert result.verified_questions == 3
    assert [d.id for d in shared_bank.shared_documents(db_session)] == [paper.id]


def test_learners_see_only_verified_shared_questions_read_only(
    api: TestClient, db_session: Session, paper: Document
) -> None:
    # Not shared yet: another learner sees nothing.
    assert api.post("/api/v1/practice/sessions", json={}).status_code == 422
    shared_bank.publish(db_session, paper.id, rights_basis=RIGHTS, source=SOURCE)

    session = api.post("/api/v1/practice/sessions", json={"count": 10})
    assert session.status_code == 201, session.text
    items = session.json()["items"]
    assert len(items) == 3  # the unverified question stays private
    for item in items:
        assert item["shared"] is True
        assert item["source"]["shared_source"] == SOURCE
        assert item["source"]["document_filename"] is None  # the publisher's file name

    question_id = items[0]["question_id"]
    read = api.get(f"/api/v1/questions/{question_id}").json()
    assert read["read_only"] is True
    assert read["shared_source"] == SOURCE
    assert read["document_filename"] is None
    # Read-only: no edits, reports or bookmarks on someone else's question.
    assert api.patch(f"/api/v1/questions/{question_id}", json={"stem": "x"}).status_code == 404
    assert api.put(f"/api/v1/questions/{question_id}/bookmark").status_code == 404

    # Opting out of the shared bank leaves the learner with their own questions only.
    opted_out = api.post("/api/v1/practice/sessions", json={"include_shared": False})
    assert opted_out.status_code == 422

    shared_bank.unpublish(db_session, paper.id)
    assert api.get(f"/api/v1/questions/{question_id}").status_code == 404


def test_repeats_count_the_shared_bank_apart(
    api: TestClient, db_session: Session, paper: Document
) -> None:
    shared_bank.publish(db_session, paper.id, rights_basis=RIGHTS, source=SOURCE)
    mine = api.get("/api/v1/insights/repeats", params={"scope": "mine"}).json()
    assert mine["papers"]["total"] == 0
    shared = api.get("/api/v1/insights/repeats", params={"scope": "shared"}).json()
    assert shared["scope"] == "shared"
    assert shared["papers"]["total"] == 1
    topic = shared["topics"][0]
    assert topic["name"] == "Shared Percentage"
    assert topic["confirmed"]["questions"] == 3  # verified ones only
    both = api.get("/api/v1/insights/repeats", params={"scope": "all"}).json()
    assert both["papers"]["total"] == 1


def test_verify_clean_questions_leaves_the_rest_for_review(
    api: TestClient, db_session: Session, user: User
) -> None:
    doc = make_document(db_session, user, "mine.pdf")
    clean = make_question(db_session, doc, status=VerificationStatus.UNVERIFIED)
    no_answer = make_question(db_session, doc, status=VerificationStatus.UNVERIFIED, answer=None)
    flagged = make_question(db_session, doc, status=VerificationStatus.UNVERIFIED)
    db_session.add(QuestionIssue(question_id=flagged.id, code=IssueCode.EMPTY_OPTION))
    picture = make_question(db_session, doc, status=VerificationStatus.UNVERIFIED, image=True)
    db_session.flush()
    db_session.expire_all()

    response = api.post(f"/api/v1/documents/{doc.id}/questions/verify-clean")
    assert response.status_code == 200, response.text
    assert response.json() == {"verified": 1, "left_for_review": 3}
    db_session.expire_all()
    assert clean.verification_status == VerificationStatus.VERIFIED
    for q in (no_answer, flagged, picture):
        assert q.verification_status == VerificationStatus.UNVERIFIED

    other = make_document(db_session, make_user(db_session, "other@example.com"))
    assert api.post(f"/api/v1/documents/{other.id}/questions/verify-clean").status_code == 404


def test_papers_say_how_many_questions_still_need_a_look(
    api: TestClient, db_session: Session, user: User
) -> None:
    doc = make_document(db_session, user, "mine.pdf")
    make_question(db_session, doc, status=VerificationStatus.UNVERIFIED)
    flagged = make_question(db_session, doc, status=VerificationStatus.UNVERIFIED)
    db_session.add(QuestionIssue(question_id=flagged.id, code=IssueCode.EMPTY_OPTION))
    db_session.add(QuestionIssue(question_id=flagged.id, code=IssueCode.MISSING_ANSWER))
    fixed = make_question(db_session, doc, status=VerificationStatus.UNVERIFIED)
    db_session.add(QuestionIssue(question_id=fixed.id, code=IssueCode.EMPTY_OPTION, resolved=True))
    rejected = make_question(db_session, doc, status=VerificationStatus.REJECTED)
    db_session.add(QuestionIssue(question_id=rejected.id, code=IssueCode.EMPTY_OPTION))
    db_session.flush()

    listed = api.get("/api/v1/documents").json()["items"]
    assert [d["questions_to_check"] for d in listed] == [1]  # one question, counted once
    assert api.get(f"/api/v1/documents/{doc.id}").json()["questions_to_check"] == 1
