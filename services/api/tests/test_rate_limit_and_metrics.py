"""Shared (PostgreSQL) rate limiting and the metrics endpoint."""

from datetime import UTC, datetime, timedelta
from typing import Any

import pytest
from fastapi.testclient import TestClient
from pydantic import SecretStr
from sqlalchemy import Engine, text

from app.core.config import Settings
from app.core.rate_limit import PostgresRateLimiter
from app.domain.errors import RateLimitedError
from app.main import create_app


class Clock:
    def __init__(self) -> None:
        self.now = datetime(2026, 10, 14, 9, 0, 5, tzinfo=UTC)

    def __call__(self) -> datetime:
        return self.now


@pytest.fixture
def clean_counters(db_engine: Engine) -> Any:
    with db_engine.begin() as connection:
        connection.execute(text("DELETE FROM rate_limit_counters"))
    yield
    with db_engine.begin() as connection:
        connection.execute(text("DELETE FROM rate_limit_counters"))


def test_postgres_limiter_is_shared_between_instances(
    db_engine: Engine, clean_counters: Any
) -> None:
    clock = Clock()
    # Two limiter objects stand for two API processes using the same database.
    a = PostgresRateLimiter(db_engine, 3, 60, message="slow down", clock=clock)
    b = PostgresRateLimiter(db_engine, 3, 60, message="slow down", clock=clock)

    a.check("ip:1")
    b.check("ip:1")
    a.check("ip:1")
    with pytest.raises(RateLimitedError) as limited:
        b.check("ip:1")
    assert limited.value.retry_after_seconds == 55  # until the window ends
    b.check("ip:2")  # other keys are independent

    clock.now += timedelta(seconds=60)  # next window
    a.check("ip:1")


def test_limiter_stores_only_hashed_keys(db_engine: Engine, clean_counters: Any) -> None:
    PostgresRateLimiter(db_engine, 5, 60, message="x").check("asha@example.com")
    with db_engine.connect() as connection:
        keys = connection.execute(text("SELECT key_hash FROM rate_limit_counters")).scalars().all()
    assert len(keys) == 1 and "asha" not in keys[0] and len(keys[0]) == 64


def test_app_uses_the_postgres_limiter_when_configured(
    settings: Settings, db_engine: Engine, clean_counters: Any
) -> None:
    app = create_app(
        settings.model_copy(update={"rate_limit_backend": "postgres", "auth_rate_limit": 2}),
        engine=db_engine,
    )
    body = {"email": "x@example.com", "password": "wrong password"}
    with TestClient(app, raise_server_exceptions=False) as client:
        statuses = [client.post("/api/v1/auth/login", json=body).status_code for _ in range(3)]
    assert statuses == [401, 401, 429]
    assert isinstance(app.state.auth_rate_limiter, PostgresRateLimiter)


def test_metrics_need_the_token_and_contain_no_ids(settings: Settings) -> None:
    hidden = TestClient(create_app(settings))
    assert hidden.get("/api/v1/metrics").status_code == 404

    app = create_app(settings.model_copy(update={"metrics_token": SecretStr("m" * 32)}))
    client = TestClient(app)
    client.get("/api/v1/health")
    client.get("/api/v1/questions/0b6c1d3e-5f1a-4c7e-9a43-2a1f0e9d7b11")

    assert (
        client.get("/api/v1/metrics", headers={"Authorization": "Bearer nope"}).status_code == 404
    )
    response = client.get("/api/v1/metrics", headers={"Authorization": f"Bearer {'m' * 32}"})
    assert response.status_code == 200
    body = response.text
    assert (
        'preploop_http_requests_total{method="GET",route="/api/v1/health",status="2xx"} 1' in body
    )
    assert 'route="/api/v1/questions/{id}"' in body
    assert "0b6c1d3e" not in body
