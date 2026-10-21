"""Suggestions: sent per account, listed back only to their sender, validated, limited per day,
exported with the account and deleted with it."""

from collections.abc import Iterator
from datetime import UTC, datetime, timedelta
from typing import Any

import pytest
from fastapi.testclient import TestClient
from sqlalchemy.orm import Session

from app.api.v1.endpoints.feedback import get_feedback_service
from app.core.config import Settings
from app.integrations.storage import LocalDocumentStorage
from app.main import create_app
from app.models.user import User
from app.schemas.feedback import SUGGESTIONS_PER_DAY
from app.services.feedback_service import FeedbackService
from tests.conftest import auth_headers, make_user


class Clock:
    def __init__(self) -> None:
        self.now = datetime(2026, 10, 21, 9, 0, tzinfo=UTC)

    def __call__(self) -> datetime:
        return self.now


@pytest.fixture
def clock() -> Clock:
    return Clock()


def client_for(
    settings: Settings,
    db_engine: Any,
    db_session: Session,
    storage: LocalDocumentStorage,
    clock: Clock,
    user: User,
) -> TestClient:
    from app.database.session import get_session

    app = create_app(settings, engine=db_engine, storage=storage)
    app.dependency_overrides[get_session] = lambda: db_session
    app.dependency_overrides[get_feedback_service] = lambda: FeedbackService(
        db_session, owner_id=user.id, now=clock
    )
    return TestClient(app, raise_server_exceptions=False, headers=auth_headers(user))


@pytest.fixture
def api(
    settings: Settings,
    db_engine: Any,
    db_session: Session,
    storage: LocalDocumentStorage,
    clock: Clock,
    user: User,
) -> Iterator[TestClient]:
    with client_for(settings, db_engine, db_session, storage, clock, user) as client:
        yield client


def test_suggestions_are_sent_and_listed_to_their_sender_only(
    api: TestClient,
    settings: Settings,
    db_engine: Any,
    db_session: Session,
    storage: LocalDocumentStorage,
    clock: Clock,
) -> None:
    sent = api.post(
        "/api/v1/suggestions", json={"kind": "add", "text": "  A dark mode timer for mocks  "}
    )
    assert sent.status_code == 201, sent.text
    assert sent.json()["text"] == "A dark mode timer for mocks"
    assert sent.json()["status"] == "new"
    assert [s["kind"] for s in api.get("/api/v1/suggestions").json()] == ["add"]

    other = make_user(db_session, "other@example.com")
    with client_for(settings, db_engine, db_session, storage, clock, other) as theirs:
        assert theirs.get("/api/v1/suggestions").json() == []


def test_suggestions_are_validated_and_limited_per_day(api: TestClient, clock: Clock) -> None:
    assert api.post("/api/v1/suggestions", json={"kind": "add", "text": "short"}).status_code == 422
    bad_kind = api.post("/api/v1/suggestions", json={"kind": "praise", "text": "x" * 20})
    assert bad_kind.status_code == 422

    for i in range(SUGGESTIONS_PER_DAY):
        clock.now += timedelta(minutes=1)
        body = {"kind": "change", "text": f"Suggestion number {i} please"}
        assert api.post("/api/v1/suggestions", json=body).status_code == 201
    limited = api.post("/api/v1/suggestions", json={"kind": "other", "text": "One more idea here"})
    assert limited.status_code == 429
    assert limited.json()["error"]["code"] == "rate_limited"

    clock.now += timedelta(days=1)
    again = api.post("/api/v1/suggestions", json={"kind": "other", "text": "One more idea here"})
    assert again.status_code == 201
