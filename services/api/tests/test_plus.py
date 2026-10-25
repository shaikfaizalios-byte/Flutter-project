"""PrepLoop Plus: status per account, the monthly AI allowance count, development-only test
subscriptions, operator grants (CLI) and the staging/production guard."""

from collections.abc import Callable, Iterator
from datetime import UTC, datetime, timedelta
from typing import Any

import pytest
from fastapi.testclient import TestClient
from sqlalchemy.orm import Session

from app.api.v1.endpoints.plus import get_plus_service
from app.cli import plus as plus_cli
from app.core.config import Settings
from app.integrations.storage import LocalDocumentStorage
from app.main import create_app
from app.models.ai import AIGeneration
from app.models.plus import Subscription
from app.models.user import User
from app.services.plus_service import PlusService, month_bounds
from tests.conftest import auth_headers, make_user

NOW = datetime(2026, 10, 21, 9, 0, tzinfo=UTC)


class Clock:
    def __init__(self) -> None:
        self.now = NOW

    def __call__(self) -> datetime:
        return self.now


ClientFactory = Callable[..., TestClient]


@pytest.fixture
def clock() -> Clock:
    return Clock()


@pytest.fixture
def make_client(
    settings: Settings,
    db_engine: Any,
    db_session: Session,
    storage: LocalDocumentStorage,
    clock: Clock,
) -> Iterator[ClientFactory]:
    from app.database.session import get_session

    clients: list[TestClient] = []

    def build(user: User, **overrides: Any) -> TestClient:
        configured = settings.model_copy(update=overrides)
        app = create_app(configured, engine=db_engine, storage=storage)
        app.dependency_overrides[get_session] = lambda: db_session
        app.dependency_overrides[get_plus_service] = lambda: PlusService(
            db_session, user.id, configured, now=clock
        )
        client = TestClient(app, raise_server_exceptions=False, headers=auth_headers(user))
        client.__enter__()
        clients.append(client)
        return client

    yield build
    for client in clients:
        client.__exit__(None, None, None)


def log_ai(db: Session, user: User, outcome: str, at: datetime) -> None:
    db.add(
        AIGeneration(
            owner_id=user.id,
            task="quick_answer",
            provider="fake",
            model="fake-model-1",
            prompt_version="p9.5",
            outcome=outcome,
            detail="",
            input_tokens=1,
            output_tokens=1,
            items_created=0,
            items_rejected=0,
            created_at=at,
        )
    )
    db.flush()


def test_status_counts_this_months_successful_ai_requests(
    make_client: ClientFactory, db_session: Session, user: User
) -> None:
    log_ai(db_session, user, "ok", NOW - timedelta(days=2))
    log_ai(db_session, user, "partial", NOW - timedelta(days=1))
    log_ai(db_session, user, "error", NOW - timedelta(days=1))  # failed: not counted
    log_ai(db_session, user, "ok", datetime(2026, 9, 30, 23, 0, tzinfo=UTC))  # last month
    other = make_user(db_session, "other@example.com")
    log_ai(db_session, other, "ok", NOW)

    body = make_client(user, plus_ai_monthly_allowance=250).get("/api/v1/me/plus").json()
    assert body == {
        "active": False,
        "source": None,
        "active_until": None,
        "ai_used_this_month": 2,
        "ai_monthly_allowance": 250,
        "period_resets_at": "2026-11-01T00:00:00Z",
        "test_mode": False,
        "purchases_available": False,
    }


def test_test_subscriptions_only_in_test_mode(
    make_client: ClientFactory, clock: Clock, user: User
) -> None:
    refused = make_client(user).post("/api/v1/me/plus/test", json={"days": 7})
    assert refused.status_code == 409
    assert refused.json()["error"]["code"] == "plus_test_disabled"

    api = make_client(user, plus_test_mode=True)
    started = api.post("/api/v1/me/plus/test", json={"days": 7}).json()
    assert (started["active"], started["source"], started["test_mode"]) == (True, "test", True)
    assert started["active_until"] == "2026-10-28T09:00:00Z"
    assert api.post("/api/v1/me/plus/test", json={"days": 0}).status_code == 422
    assert api.post("/api/v1/me/plus/test", json={"days": 40}).status_code == 422

    clock.now = NOW + timedelta(days=8)
    assert api.get("/api/v1/me/plus").json()["active"] is False  # ran out
    api.post("/api/v1/me/plus/test", json={})  # default 7 days, restarted
    assert api.get("/api/v1/me/plus").json()["active"] is True
    assert api.delete("/api/v1/me/plus/test").json()["active"] is False


def test_operator_grants_are_not_replaced_by_test_ones(
    make_client: ClientFactory, db_session: Session, user: User
) -> None:
    db_session.add(
        Subscription(
            owner_id=user.id, plan="plus", source="operator", active_until=NOW + timedelta(days=30)
        )
    )
    db_session.flush()
    api = make_client(user, plus_test_mode=True)
    assert api.get("/api/v1/me/plus").json()["source"] == "operator"
    conflict = api.post("/api/v1/me/plus/test", json={"days": 3})
    assert conflict.json()["error"]["code"] == "plus_active"
    assert api.delete("/api/v1/me/plus/test").json()["source"] == "operator"  # kept

    other = make_user(db_session, "other@example.com")
    assert make_client(other).get("/api/v1/me/plus").json()["active"] is False


def test_operator_cli_grants_shows_and_revokes(
    db_session: Session, user: User, monkeypatch: pytest.MonkeyPatch, capsys: Any
) -> None:
    class Maker:
        def __call__(self) -> "Maker":
            return self

        def __enter__(self) -> Session:
            return db_session

        def __exit__(self, *exc: object) -> None:
            return None

    monkeypatch.setattr(plus_cli, "build_engine", lambda settings: object())
    monkeypatch.setattr(plus_cli, "build_sessionmaker", lambda engine: Maker())

    assert plus_cli.main(["grant", "Learner@Example.com", "--days", "30", "--note", "beta"]) == 0
    sub = db_session.get(Subscription, user.id)
    assert sub is not None and (sub.source, sub.note) == ("operator", "beta")
    assert plus_cli.main(["show", user.email]) == 0
    assert "plus (operator) active" in capsys.readouterr().out
    assert plus_cli.main(["grant", user.email, "--days", "0"]) == 2
    assert plus_cli.main(["revoke", user.email]) == 0
    assert db_session.get(Subscription, user.id) is None
    assert plus_cli.main(["show", "nobody@example.com"]) == 1


def test_month_bounds_and_the_staging_guard() -> None:
    assert month_bounds(datetime(2026, 12, 31, 23, 59, tzinfo=UTC)) == (
        datetime(2026, 12, 1, tzinfo=UTC),
        datetime(2027, 1, 1, tzinfo=UTC),
    )
    with pytest.raises(ValueError, match="PLUS_TEST_MODE"):
        Settings(
            _env_file=None,
            environment="staging",
            auth_secret="s" * 40,
            rate_limit_backend="postgres",
            email_backend="smtp",
            smtp_host="smtp.example.com",
            smtp_from="PrepLoop <no-reply@example.com>",
            plus_test_mode=True,
        )
