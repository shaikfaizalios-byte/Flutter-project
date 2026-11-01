"""Signed-in devices: listing, remote sign-out, and access tokens that stop at once."""

import uuid
from collections.abc import Iterator
from typing import Any

import pytest
from fastapi.testclient import TestClient
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.core.config import Settings
from app.core.security import TokenSigner
from app.database.session import get_session
from app.integrations.storage import LocalDocumentStorage
from app.main import create_app
from app.models.user import RefreshToken
from tests.conftest import TEST_AUTH_SECRET, make_user
from tests.test_auth import PASSWORD, bearer, register

EMAIL = "asha@example.com"


@pytest.fixture
def anon(
    settings: Settings, db_engine: Any, db_session: Session, storage: LocalDocumentStorage
) -> Iterator[TestClient]:
    # These tests sign in several times as one learner on purpose.
    app = create_app(
        settings.model_copy(update={"auth_rate_limit": 1000}), engine=db_engine, storage=storage
    )
    app.dependency_overrides[get_session] = lambda: db_session
    with TestClient(app, raise_server_exceptions=False) as client:
        yield client


def login(client: TestClient, **extra: Any) -> dict[str, Any]:
    response = client.post(
        "/api/v1/auth/login", json={"email": EMAIL, "password": PASSWORD, **extra}
    )
    assert response.status_code == 200, response.text
    tokens: dict[str, Any] = response.json()
    return tokens


def devices(client: TestClient, tokens: dict[str, Any]) -> list[dict[str, Any]]:
    response = client.get("/api/v1/auth/sessions", headers=bearer(tokens))
    assert response.status_code == 200, response.text
    found: list[dict[str, Any]] = response.json()
    return found


def test_each_sign_in_is_a_device_and_this_one_comes_first(anon: TestClient) -> None:
    phone = register(anon, email=EMAIL, platform="android").json()
    web = login(anon, platform="web")
    login(anon)  # an older app that sends no platform

    seen = devices(anon, web)

    assert len(seen) == 3
    assert seen[0]["current"] is True
    assert seen[0]["platform"] == "web"
    assert sorted(str(d["platform"]) for d in seen) == ["None", "android", "web"]
    assert sum(d["current"] for d in seen) == 1
    assert devices(anon, phone)[0]["platform"] == "android"


def test_refreshing_keeps_one_device_and_its_platform(anon: TestClient) -> None:
    tokens = register(anon, email=EMAIL, platform="ios").json()
    refreshed = anon.post(
        "/api/v1/auth/refresh", json={"refresh_token": tokens["refresh_token"]}
    ).json()

    [device] = devices(anon, refreshed)

    assert (device["platform"], device["current"]) == ("ios", True)
    assert device["last_active_at"] >= device["signed_in_at"]


def test_signing_a_device_out_ends_its_access_and_refresh_at_once(anon: TestClient) -> None:
    phone = register(anon, email=EMAIL, platform="android").json()
    laptop = login(anon, platform="web")
    phone_id = next(d["id"] for d in devices(anon, laptop) if d["platform"] == "android")

    signed_out = anon.delete(f"/api/v1/auth/sessions/{phone_id}", headers=bearer(laptop))

    assert signed_out.status_code == 204
    # The phone's unexpired access token is refused now, not in 15 minutes.
    assert anon.get("/api/v1/auth/me", headers=bearer(phone)).status_code == 401
    refresh = anon.post("/api/v1/auth/refresh", json={"refresh_token": phone["refresh_token"]})
    assert refresh.status_code == 401
    assert [d["platform"] for d in devices(anon, laptop)] == ["web"]


def test_sign_out_others_keeps_only_this_device(anon: TestClient) -> None:
    first = register(anon, email=EMAIL, platform="android").json()
    second = login(anon, platform="ios")
    here = login(anon, platform="web")

    response = anon.post("/api/v1/auth/sessions/sign-out-others", headers=bearer(here))

    assert response.status_code == 200, response.text
    assert response.json() == {"signed_out": 2}
    for gone in (first, second):
        assert anon.get("/api/v1/auth/me", headers=bearer(gone)).status_code == 401
    assert [d["platform"] for d in devices(anon, here)] == ["web"]


def test_other_accounts_devices_are_not_found(anon: TestClient) -> None:
    mine = register(anon, email=EMAIL).json()
    theirs = register(anon, email="ravi@example.com").json()
    [their_device] = devices(anon, theirs)

    response = anon.delete(f"/api/v1/auth/sessions/{their_device['id']}", headers=bearer(mine))
    unknown = anon.delete(f"/api/v1/auth/sessions/{uuid.uuid4()}", headers=bearer(mine))

    assert (response.status_code, unknown.status_code) == (404, 404)
    assert anon.get("/api/v1/auth/me", headers=bearer(theirs)).status_code == 200


def test_tokens_without_a_device_still_work_but_must_refresh_to_sign_out_others(
    anon: TestClient, db_session: Session
) -> None:
    user = make_user(db_session, email=EMAIL)
    old = {"access_token": TokenSigner(TEST_AUTH_SECRET, 15).access_token(user.id)}

    assert anon.get("/api/v1/auth/me", headers=bearer(old)).status_code == 200
    assert anon.get("/api/v1/auth/sessions", headers=bearer(old)).status_code == 200
    response = anon.post("/api/v1/auth/sessions/sign-out-others", headers=bearer(old))
    assert response.status_code == 401  # the app refreshes (new token has a device) and retries


def test_unknown_platforms_are_refused(anon: TestClient, db_session: Session) -> None:
    response = register(anon, email=EMAIL, platform="Pixel 9 Pro")

    assert response.status_code == 422
    assert db_session.scalars(select(RefreshToken)).first() is None
