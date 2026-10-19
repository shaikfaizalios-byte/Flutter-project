"""Accounts: registration, sign-in, token rotation, sign-out, export, deletion (real Postgres)."""

import uuid
from collections.abc import Callable, Iterator
from datetime import UTC, datetime, timedelta
from typing import Any

import pytest
from fastapi.testclient import TestClient
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.core.config import Settings
from app.core.security import TokenSigner
from app.integrations.storage import LocalDocumentStorage
from app.main import create_app
from app.models.concept import Concept
from app.models.document import Document
from app.models.user import RefreshToken, User
from tests.conftest import TEST_AUTH_SECRET, auth_headers, make_user

PASSWORD = "correct horse battery"


@pytest.fixture
def make_anon(
    settings: Settings, db_engine: Any, db_session: Session, storage: LocalDocumentStorage
) -> Iterator[Callable[..., TestClient]]:
    """Clients that are not signed in (each test signs in as needed)."""
    from app.database.session import get_session

    clients: list[TestClient] = []

    def build(**overrides: Any) -> TestClient:
        app = create_app(settings.model_copy(update=overrides), engine=db_engine, storage=storage)
        app.dependency_overrides[get_session] = lambda: db_session
        client = TestClient(app, raise_server_exceptions=False)
        client.__enter__()
        clients.append(client)
        return client

    yield build
    for client in clients:
        client.__exit__(None, None, None)


@pytest.fixture
def anon(make_anon: Callable[..., TestClient]) -> TestClient:
    return make_anon()


def register(client: TestClient, email: str = "Asha@Example.com", **extra: Any) -> Any:
    return client.post(
        "/api/v1/auth/register",
        json={"email": email, "password": PASSWORD, "confirms_minimum_age": True, **extra},
    )


def bearer(tokens: dict[str, Any]) -> dict[str, str]:
    return {"Authorization": f"Bearer {tokens['access_token']}"}


# --- registration and sign-in --------------------------------------------------------------


def test_register_normalises_email_and_returns_tokens(
    anon: TestClient, db_session: Session
) -> None:
    response = register(anon, display_name="Asha")

    assert response.status_code == 201, response.text
    body = response.json()
    assert body["user"]["email"] == "asha@example.com"
    assert body["user"]["display_name"] == "Asha"
    assert body["token_type"] == "bearer"
    assert body["expires_in"] == 15 * 60
    user = db_session.scalars(select(User)).one()
    assert user.password_hash.startswith("$argon2id$")  # never stored in plain text
    stored = db_session.scalars(select(RefreshToken)).one()
    assert stored.token_hash != body["refresh_token"] and len(stored.token_hash) == 64

    me = anon.get("/api/v1/auth/me", headers=bearer(body))
    assert me.json()["email"] == "asha@example.com"


def test_registration_rules(anon: TestClient) -> None:
    assert register(anon).status_code == 201
    taken = register(anon, email="ASHA@example.com ")
    assert taken.status_code == 409
    assert taken.json()["error"]["code"] == "email_taken"

    short = anon.post(
        "/api/v1/auth/register",
        json={"email": "b@example.com", "password": "short", "confirms_minimum_age": True},
    )
    assert short.status_code == 422
    bad_email = anon.post(
        "/api/v1/auth/register",
        json={"email": "not-an-email", "password": PASSWORD, "confirms_minimum_age": True},
    )
    assert bad_email.status_code == 422
    same = anon.post(
        "/api/v1/auth/register",
        json={
            "email": "longaddress@example.com",
            "password": "LongAddress@example.com",
            "confirms_minimum_age": True,
        },
    )
    assert same.status_code == 401
    assert same.json()["error"]["code"] == "invalid_credentials"


def test_registration_requires_the_minimum_age(anon: TestClient, db_session: Session) -> None:
    for extra in ({}, {"confirms_minimum_age": False}):
        refused = anon.post(
            "/api/v1/auth/register",
            json={"email": "young@example.com", "password": PASSWORD, **extra},
        )
        assert refused.status_code == 422
    assert register(anon, email="adult@example.com").status_code == 201
    user = db_session.scalars(select(User).where(User.email == "adult@example.com")).one()
    assert user.age_confirmed_at is not None


def test_login_success_and_uniform_failures(anon: TestClient) -> None:
    register(anon)
    ok = anon.post("/api/v1/auth/login", json={"email": "asha@example.com", "password": PASSWORD})
    assert ok.status_code == 200

    wrong = anon.post("/api/v1/auth/login", json={"email": "asha@example.com", "password": "nope"})
    unknown = anon.post(
        "/api/v1/auth/login", json={"email": "nobody@example.com", "password": PASSWORD}
    )
    for failed in (wrong, unknown):
        assert failed.status_code == 401
        assert failed.json()["error"]["code"] == "invalid_credentials"
    assert wrong.json()["error"]["message"] == unknown.json()["error"]["message"]


def test_sign_in_attempts_are_rate_limited(make_anon: Callable[..., TestClient]) -> None:
    client = make_anon(auth_rate_limit=3)
    body = {"email": "asha@example.com", "password": "wrong password"}
    for _ in range(3):
        assert client.post("/api/v1/auth/login", json=body).status_code == 401
    limited = client.post("/api/v1/auth/login", json=body)
    assert limited.status_code == 429
    assert int(limited.headers["Retry-After"]) >= 1


# --- access tokens -----------------------------------------------------------------------


def test_protected_routes_need_a_valid_access_token(anon: TestClient, db_session: Session) -> None:
    user = make_user(db_session)
    for path in (
        "/api/v1/concepts",
        "/api/v1/documents",
        "/api/v1/questions",
        "/api/v1/practice/sessions",
        "/api/v1/analytics/overview?timezone=UTC",
        "/api/v1/ai/status",
        "/api/v1/auth/me",
    ):
        response = anon.get(path)
        assert response.status_code == 401, path
        assert response.json()["error"]["code"] == "unauthorized"
        assert response.headers["WWW-Authenticate"] == "Bearer"

    expired = TokenSigner(TEST_AUTH_SECRET, 15).access_token(
        user.id, now=datetime.now(UTC) - timedelta(hours=1)
    )
    forged = TokenSigner("another-secret-" + "y" * 40, 15).access_token(user.id)
    for token in (expired, forged, "garbage"):
        response = anon.get("/api/v1/concepts", headers={"Authorization": f"Bearer {token}"})
        assert response.status_code == 401

    assert anon.get("/api/v1/concepts", headers=auth_headers(user)).status_code == 200
    # Public reference data and health stay open.
    assert anon.get("/api/v1/exams").status_code == 200
    assert anon.get("/api/v1/health").status_code == 200


# --- refresh tokens ----------------------------------------------------------------------


def test_refresh_rotates_and_detects_reuse(anon: TestClient) -> None:
    first = register(anon).json()

    second = anon.post("/api/v1/auth/refresh", json={"refresh_token": first["refresh_token"]})
    assert second.status_code == 200
    rotated = second.json()
    assert rotated["refresh_token"] != first["refresh_token"]
    assert anon.get("/api/v1/auth/me", headers=bearer(rotated)).status_code == 200

    # Replaying the old token (e.g. it was stolen) revokes the whole session family...
    replay = anon.post("/api/v1/auth/refresh", json={"refresh_token": first["refresh_token"]})
    assert replay.status_code == 401
    # ...including the newest token.
    after = anon.post("/api/v1/auth/refresh", json={"refresh_token": rotated["refresh_token"]})
    assert after.status_code == 401


def test_logout_and_expiry_end_the_session(anon: TestClient, db_session: Session) -> None:
    tokens = register(anon).json()
    assert (
        anon.post(
            "/api/v1/auth/logout", json={"refresh_token": tokens["refresh_token"]}
        ).status_code
        == 204
    )
    gone = anon.post("/api/v1/auth/refresh", json={"refresh_token": tokens["refresh_token"]})
    assert gone.status_code == 401

    fresh = anon.post(
        "/api/v1/auth/login", json={"email": "asha@example.com", "password": PASSWORD}
    ).json()
    for row in db_session.scalars(select(RefreshToken).where(RefreshToken.revoked_at.is_(None))):
        row.expires_at = datetime.now(UTC) - timedelta(seconds=1)
    db_session.flush()
    expired = anon.post("/api/v1/auth/refresh", json={"refresh_token": fresh["refresh_token"]})
    assert expired.status_code == 401


# --- single-tenant data → first account ----------------------------------------------------


def test_first_account_claims_existing_data_later_ones_do_not(
    anon: TestClient, db_session: Session
) -> None:
    legacy = Concept(
        exam_code="SSC_CGL",
        title="Made before accounts",
        subject="Quantitative Aptitude",
        topic="Percentage",
        language="en",
    )
    db_session.add(legacy)
    db_session.flush()

    first = register(anon, email="first@example.com").json()
    second = register(anon, email="second@example.com").json()

    mine = anon.get("/api/v1/concepts", headers=bearer(first)).json()
    assert [c["title"] for c in mine["items"]] == ["Made before accounts"]
    assert anon.get("/api/v1/concepts", headers=bearer(second)).json()["total"] == 0


# --- privacy -------------------------------------------------------------------------------


def test_export_contains_only_the_accounts_data(anon: TestClient) -> None:
    asha = register(anon, email="asha@example.com").json()
    ravi = register(anon, email="ravi@example.com").json()
    concept = {
        "exam_code": "SSC_CGL",
        "title": "Asha's note",
        "subject": "Quantitative Aptitude",
        "topic": "Percentage",
        "language": "en",
    }
    anon.post("/api/v1/concepts", json=concept, headers=bearer(asha))
    anon.post("/api/v1/concepts", json={**concept, "title": "Ravi's note"}, headers=bearer(ravi))

    export = anon.get("/api/v1/auth/me/export", headers=bearer(asha)).json()

    assert export["user"]["email"] == "asha@example.com"
    assert [c["title"] for c in export["data"]["concepts"]] == ["Asha's note"]
    assert "password_hash" not in str(export)
    assert export["data"]["account_settings"] == [{"radar_opt_in": False, "radar_opt_in_at": None}]


def test_account_deletion_removes_data_files_and_access(
    anon: TestClient, db_session: Session, storage: LocalDocumentStorage
) -> None:
    from tests.pdf_factory import text_pdf
    from tests.test_documents_upload import upload

    tokens = register(anon).json()
    anon.headers.update(bearer(tokens))
    document = upload(anon, text_pdf()).json()
    key = db_session.scalar(
        select(Document.storage_key).where(Document.id == uuid.UUID(document["id"]))
    )
    assert key is not None
    stored_file = storage.path_for(key)
    assert stored_file.exists()

    wrong = anon.post("/api/v1/auth/me/delete", json={"password": "not it"})
    assert wrong.status_code == 401
    deleted = anon.post("/api/v1/auth/me/delete", json={"password": PASSWORD})
    assert deleted.status_code == 204

    assert db_session.get(User, uuid.UUID(tokens["user"]["id"])) is None
    assert anon.get(f"/api/v1/documents/{document['id']}").status_code == 401
    assert not stored_file.exists()
    refresh = anon.post("/api/v1/auth/refresh", json={"refresh_token": tokens["refresh_token"]})
    assert refresh.status_code == 401
