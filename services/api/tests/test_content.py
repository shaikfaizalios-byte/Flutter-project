"""Content governance and the starter check (global Phase 7): every shared paper has a rights
record with its permitted uses; learners report shared content; the operator resolves reports
and takes papers down, all audited; the starter check uses only papers allowed for it."""

# The shared-bank fixtures are imported from its tests and used as arguments.
# ruff: noqa: F811

import uuid
from typing import Any

import pytest
from fastapi.testclient import TestClient
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.domain.errors import ConflictError
from app.models.content import AuditEvent, ContentReport, ContentRights
from app.models.document import Document
from app.models.question import Question, Topic
from app.models.user import User
from app.services import content, shared_bank
from tests.conftest import auth_headers
from tests.test_practice import make_question
from tests.test_shared_bank import (  # noqa: F401 - fixtures
    RIGHTS,
    SOURCE,
    api,
    make_document,
    paper,
    publisher,
    shared_topic,
)


def actions(db: Session) -> set[str]:
    return set(db.scalars(select(AuditEvent.action)).all())


# --- rights ------------------------------------------------------------------------------


def test_publishing_records_rights_and_uses_and_is_audited(
    db_session: Session, paper: Document
) -> None:
    shared_bank.publish(
        db_session,
        paper.id,
        rights_basis=RIGHTS,
        source=SOURCE,
        uses=["practice", "diagnostic"],
        decided_by="A. Operator",
        territory="IN",
    )

    rights = db_session.get(ContentRights, paper.id)
    assert rights is not None
    assert (rights.permitted_uses, rights.decided_by, rights.territory) == (
        ["diagnostic", "practice"],
        "A. Operator",
        "IN",
    )
    assert actions(db_session) == {"publish"}

    shared_bank.unpublish(db_session, paper.id, actor="A. Operator", reason="test")

    assert db_session.get(ContentRights, paper.id) is None
    assert actions(db_session) == {"publish", "unpublish"}


def test_only_known_uses_can_be_permitted(db_session: Session, paper: Document) -> None:
    with pytest.raises(ConflictError):
        shared_bank.publish(
            db_session, paper.id, rights_basis=RIGHTS, source=SOURCE, uses=["resell"]
        )
    assert db_session.get(ContentRights, paper.id) is None


# --- reports and takedown ----------------------------------------------------------------


def report(api: TestClient, **body: Any) -> Any:
    return api.post(
        "/api/v1/content-reports",
        json={"kind": "rights", "text": "This is my book's page.", **body},
    )


def test_learners_report_shared_content_and_see_its_status(
    api: TestClient, db_session: Session, paper: Document, user: User
) -> None:
    shared_bank.publish(db_session, paper.id, rights_basis=RIGHTS, source=SOURCE)
    question = db_session.scalars(select(Question).where(Question.document_id == paper.id)).first()
    assert question is not None

    created = report(api, question_id=str(question.id))

    assert created.status_code == 201, created.text
    assert created.json()["document_id"] == str(paper.id)
    [mine] = api.get("/api/v1/content-reports").json()
    assert (mine["status"], mine["kind"]) == ("open", "rights")


def test_only_shared_papers_of_others_can_be_reported(
    api: TestClient, db_session: Session, paper: Document, user: User
) -> None:
    own = make_document(db_session, user, "mine.pdf")
    own.shared_at = paper.created_at  # even shared, one's own paper uses question reports
    db_session.flush()

    assert report(api, document_id=str(paper.id)).status_code == 404  # not shared
    assert report(api, document_id=str(own.id)).status_code == 404
    assert report(api).status_code == 422  # says nothing about what


def test_reports_are_limited_per_day(api: TestClient, db_session: Session, paper: Document) -> None:
    shared_bank.publish(db_session, paper.id, rights_basis=RIGHTS, source=SOURCE)
    for _ in range(content.REPORTS_PER_DAY):
        assert report(api, document_id=str(paper.id)).status_code == 201

    assert report(api, document_id=str(paper.id)).status_code == 429


def test_takedown_withdraws_the_paper_upholds_reports_and_is_audited(
    api: TestClient, db_session: Session, paper: Document
) -> None:
    shared_bank.publish(db_session, paper.id, rights_basis=RIGHTS, source=SOURCE)
    report(api, document_id=str(paper.id))
    question = db_session.scalars(
        select(Question).where(
            Question.document_id == paper.id, Question.verification_status == "verified"
        )
    ).first()
    assert question is not None
    assert api.get(f"/api/v1/questions/{question.id}").status_code == 200

    closed = content.takedown(db_session, paper.id, reason="Rights holder asked", actor="Ops")

    assert closed == 1
    assert api.get(f"/api/v1/questions/{question.id}").status_code == 404
    [mine] = api.get("/api/v1/content-reports").json()
    assert mine["status"] == "upheld" and "Rights holder asked" in mine["resolution"]
    assert {"unpublish", "takedown"} <= actions(db_session)
    still_there = db_session.get(Document, paper.id)
    assert still_there is not None  # the owner keeps their paper
    with pytest.raises(ConflictError):
        content.takedown(db_session, paper.id, reason=" ", actor="Ops")


def test_a_report_is_resolved_once(api: TestClient, db_session: Session, paper: Document) -> None:
    shared_bank.publish(db_session, paper.id, rights_basis=RIGHTS, source=SOURCE)
    created = report(api, document_id=str(paper.id)).json()

    resolved = content.resolve(
        db_session, uuid.UUID(created["id"]), upheld=False, note="Public notice", actor="Ops"
    )

    db_session.flush()  # the CLI commits; resolve() leaves that to its caller
    assert resolved.status == "dismissed"
    assert "report_dismissed" in actions(db_session)
    with pytest.raises(ConflictError):
        content.resolve(db_session, resolved.id, upheld=True, note="", actor="Ops")
    stored = db_session.get(ContentReport, resolved.id)
    assert stored is not None and stored.resolution == "Public notice"


# --- the starter check -------------------------------------------------------------------


def availability(api: TestClient) -> dict[str, Any]:
    data: dict[str, Any] = api.get(
        "/api/v1/practice/starter-check", params={"exam": "SSC_CHSL"}
    ).json()
    return data


def test_the_starter_check_uses_only_papers_allowed_for_it(
    api: TestClient, db_session: Session, paper: Document
) -> None:
    assert availability(api)["question_count"] == 0
    refused = api.post("/api/v1/practice/starter-check", json={"exam_code": "SSC_CHSL"})
    assert refused.status_code == 422

    shared_bank.publish(db_session, paper.id, rights_basis=RIGHTS, source=SOURCE)  # practice only
    assert availability(api)["question_count"] == 0

    shared_bank.unpublish(db_session, paper.id)
    shared_bank.publish(
        db_session, paper.id, rights_basis=RIGHTS, source=SOURCE, uses=["practice", "diagnostic"]
    )
    assert availability(api)["question_count"] == 3  # the paper's verified questions


def test_a_starter_check_spans_subjects_and_hides_answers_until_submitted(
    api: TestClient, db_session: Session, publisher: User, shared_topic: Topic
) -> None:
    doc = make_document(db_session, publisher, "starter.pdf")
    for subject in ("Quantitative Aptitude", "General Awareness", "English Language"):
        for _ in range(7):
            make_question(db_session, doc, subject=subject)
    shared_bank.publish(
        db_session, doc.id, rights_basis=RIGHTS, source=SOURCE, uses=["diagnostic", "practice"]
    )

    check = api.post("/api/v1/practice/starter-check", json={"exam_code": "SSC_CHSL"})

    assert check.status_code == 201, check.text
    data = check.json()
    assert data["mode"] == "diagnostic" and data["deadline_at"] is None
    subjects = [i["subject"] for i in data["items"]]
    assert len(subjects) == 15 and {subjects.count(s) for s in set(subjects)} == {5}
    sid = data["id"]
    ack = api.put(
        f"/api/v1/practice/sessions/{sid}/answers/1",
        json={"selected_position": 1, "client_seq": 1},
    ).json()
    assert ack["feedback"] is None  # like a test: answers come after submitting
    done = api.post(f"/api/v1/practice/sessions/{sid}/submit").json()
    assert done["result"]["marking_note"].startswith("Starter check")
    assert {s["name"] for s in done["result"]["sections"]} == set(subjects)


def test_a_publisher_does_not_get_their_own_papers_as_a_starter_check(
    api: TestClient, db_session: Session, paper: Document, publisher: User
) -> None:
    shared_bank.publish(
        db_session, paper.id, rights_basis=RIGHTS, source=SOURCE, uses=["diagnostic"]
    )

    theirs = api.get(
        "/api/v1/practice/starter-check",
        params={"exam": "SSC_CHSL"},
        headers=auth_headers(publisher),
    ).json()

    assert theirs["question_count"] == 0
