"""Offline practice: the pack the device keeps (verified, answer known, no figures, own +
shared bank) and uploading a session done offline (answers re-checked by the server,
idempotent, times kept within the session, invisible questions left out)."""

import uuid
from collections.abc import Iterator
from datetime import timedelta
from typing import Any

import pytest
from fastapi.testclient import TestClient
from sqlalchemy.orm import Session

from app.api.v1.endpoints.practice import get_practice_service
from app.core.config import Settings
from app.integrations.storage import LocalDocumentStorage
from app.main import create_app
from app.models.document import Document
from app.models.question import QuestionFigure, VerificationStatus
from app.models.user import User
from app.services import shared_bank
from app.services.practice_service import PracticeService
from tests.conftest import auth_headers, make_user
from tests.test_practice import T0, Clock, make_question
from tests.test_shared_bank import RIGHTS, SOURCE, make_document


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
    user: User,
) -> Iterator[TestClient]:
    from app.database.session import get_session

    app = create_app(settings, engine=db_engine, storage=storage)
    app.dependency_overrides[get_session] = lambda: db_session
    app.dependency_overrides[get_practice_service] = lambda: PracticeService(
        db_session, owner_id=user.id, now=clock
    )
    with TestClient(app, raise_server_exceptions=False, headers=auth_headers(user)) as client:
        yield client


@pytest.fixture
def paper(db_session: Session, user: User) -> Document:
    return make_document(db_session, user, "mine.pdf")


def upload(api: TestClient, client_id: uuid.UUID, items: list[dict[str, Any]]) -> Any:
    return api.post(
        "/api/v1/practice/offline-sessions",
        json={
            "client_id": str(client_id),
            "started_at": (T0 - timedelta(minutes=10)).isoformat(),
            "finished_at": (T0 - timedelta(minutes=1)).isoformat(),
            "items": items,
        },
    )


def test_offline_pack_has_verified_answerable_questions_without_figures(
    api: TestClient, db_session: Session, paper: Document
) -> None:
    good = make_question(db_session, paper)
    make_question(db_session, paper, status=VerificationStatus.UNVERIFIED)
    with_figure = make_question(db_session, paper)
    db_session.add(
        QuestionFigure(
            question_id=with_figure.id,
            kind="stem",
            sort_order=1,
            page_number=1,
            box=[0, 0, 1, 1],
            width=1,
            height=1,
            data=b"x",
        )
    )
    publisher = make_user(db_session, "operator@example.com")
    shared_paper = make_document(db_session, publisher, "operator-notes.pdf")
    shared = make_question(db_session, shared_paper)
    db_session.flush()
    shared_bank.publish(db_session, shared_paper.id, rights_basis=RIGHTS, source=SOURCE)

    pack = api.get("/api/v1/practice/offline-pack").json()
    by_id = {q["id"]: q for q in pack["questions"]}
    assert set(by_id) == {str(good.id), str(shared.id)}
    mine = by_id[str(good.id)]
    assert mine["correct_position"] == 1 and len(mine["options"]) == 4
    assert mine["document_filename"] == "mine.pdf" and mine["shared"] is False
    theirs = by_id[str(shared.id)]
    assert theirs["shared"] is True and theirs["shared_source"] == SOURCE
    assert theirs["document_filename"] is None


def test_offline_session_is_rechecked_by_the_server_and_idempotent(
    api: TestClient, db_session: Session, paper: Document
) -> None:
    right = make_question(db_session, paper, answer=2)
    wrong = make_question(db_session, paper, answer=3)
    skipped = make_question(db_session, paper)
    other = make_document(db_session, make_user(db_session, "other@example.com"), "x.pdf")
    invisible = make_question(db_session, other)
    db_session.flush()
    client_id = uuid.uuid4()
    items: list[dict[str, Any]] = [
        {"question_id": str(right.id), "selected_position": 2},
        {"question_id": str(wrong.id), "selected_position": 1, "time_spent_ms": 4000},
        {"question_id": str(skipped.id)},
        {"question_id": str(invisible.id), "selected_position": 1},
        # A device clock in the future is kept within the session.
        {
            "question_id": str(right.id),
            "selected_position": 5,  # only 4 options: unanswered
            "answered_at": (T0 + timedelta(days=3)).isoformat(),
        },
    ]
    response = upload(api, client_id, items)
    assert response.status_code == 201, response.text
    session = response.json()
    assert session["id"] == str(client_id)
    assert session["status"] == "submitted" and session["submit_reason"] == "offline"
    assert len(session["items"]) == 4  # the invisible question is left out
    assert session["result"]["correct"] == 1
    assert session["result"]["wrong"] == 1
    assert session["result"]["unattempted"] == 2

    # Re-uploading (e.g. after a lost reply) changes nothing.
    again = upload(api, client_id, items)
    assert again.status_code == 201
    assert again.json()["id"] == str(client_id)
    history = api.get("/api/v1/practice/sessions").json()
    assert [s["id"] for s in history["items"]].count(str(client_id)) == 1

    # Wrong offline answers feed "questions to revisit".
    incorrect = api.get("/api/v1/practice/incorrect").json()
    assert [q["id"] for q in incorrect["items"]] == [str(wrong.id)]


def test_offline_upload_edge_cases(api: TestClient, db_session: Session, paper: Document) -> None:
    other = make_document(db_session, make_user(db_session, "other@example.com"), "x.pdf")
    invisible = make_question(db_session, other)
    db_session.flush()
    nothing = upload(api, uuid.uuid4(), [{"question_id": str(invisible.id)}])
    assert nothing.status_code == 422

    # Someone else's session id can't be taken over.
    mine = make_question(db_session, paper)
    db_session.flush()
    theirs = uuid.uuid4()
    other_owner = PracticeService(db_session, owner_id=other.owner_id)  # type: ignore[arg-type]
    make_question(db_session, other)
    db_session.flush()
    from app.schemas.practice import OfflineAnswer, OfflineSessionUpload

    other_owner.import_offline(
        OfflineSessionUpload(
            client_id=theirs,
            started_at=T0,
            finished_at=T0,
            items=[OfflineAnswer(question_id=invisible.id, selected_position=1)],
        )
    )
    taken = upload(api, theirs, [{"question_id": str(mine.id), "selected_position": 1}])
    assert taken.status_code == 409
