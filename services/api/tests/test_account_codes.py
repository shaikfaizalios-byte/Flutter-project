"""Password reset and email verification with emailed one-time codes."""

from collections.abc import Iterator
from datetime import UTC, datetime, timedelta
from pathlib import Path
from typing import Any

import pytest
from fastapi.testclient import TestClient
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.core.config import Settings
from app.integrations.email import FileOutboxEmailSender, OutgoingEmail
from app.integrations.storage import LocalDocumentStorage
from app.main import create_app
from app.models.user import AccountCode, User
from tests.fakes import FakeEmailSender

PASSWORD = "correct horse battery"
NEW_PASSWORD = "a brand new passphrase"


@pytest.fixture
def mail() -> FakeEmailSender:
    return FakeEmailSender()


@pytest.fixture
def anon(
    settings: Settings,
    db_engine: Any,
    db_session: Session,
    storage: LocalDocumentStorage,
    mail: FakeEmailSender,
) -> Iterator[TestClient]:
    from app.database.session import get_session

    # Generous sign-in limit: these tests make many code attempts on purpose.
    app = create_app(
        settings.model_copy(update={"auth_rate_limit": 1000}),
        engine=db_engine,
        storage=storage,
        email_sender=mail,
    )
    app.dependency_overrides[get_session] = lambda: db_session
    with TestClient(app, raise_server_exceptions=False) as client:
        yield client


def register(client: TestClient, email: str = "asha@example.com") -> dict[str, Any]:
    response = client.post("/api/v1/auth/register", json={"email": email, "password": PASSWORD})
    assert response.status_code == 201, response.text
    data: dict[str, Any] = response.json()
    return data


def bearer(tokens: dict[str, Any]) -> dict[str, str]:
    return {"Authorization": f"Bearer {tokens['access_token']}"}


def test_registration_sends_a_verification_code(
    anon: TestClient, mail: FakeEmailSender, db_session: Session
) -> None:
    tokens = register(anon)

    assert tokens["user"]["email_verified"] is False
    [email] = mail.sent
    assert email.to == "asha@example.com"
    assert "confirmation code" in email.text and "पुष्टि कोड" in email.text  # EN + HI
    stored = db_session.scalars(select(AccountCode)).one()
    assert mail.last_code() not in stored.code_hash  # only an HMAC is stored

    wrong = anon.post(
        "/api/v1/auth/verify-email/confirm", json={"code": "000000"}, headers=bearer(tokens)
    )
    if mail.last_code() != "000000":
        assert wrong.status_code == 400
        assert wrong.json()["error"]["code"] == "invalid_code"
    ok = anon.post(
        "/api/v1/auth/verify-email/confirm",
        json={"code": mail.last_code()},
        headers=bearer(tokens),
    )
    assert ok.status_code == 200
    assert ok.json()["email_verified"] is True

    # Already verified: no further codes are sent.
    again = anon.post("/api/v1/auth/verify-email/request", headers=bearer(tokens))
    assert again.status_code == 202
    assert len(mail.sent) == 1


def test_password_reset_flow_signs_out_every_device(
    anon: TestClient, mail: FakeEmailSender
) -> None:
    tokens = register(anon)
    mail.sent.clear()

    response = anon.post("/api/v1/auth/password-reset/request", json={"email": "ASHA@example.com"})
    assert response.status_code == 202
    code = mail.last_code()
    assert "reset code" in mail.sent[-1].text

    confirmed = anon.post(
        "/api/v1/auth/password-reset/confirm",
        json={"email": "asha@example.com", "code": code, "new_password": NEW_PASSWORD},
    )
    assert confirmed.status_code == 204

    old = anon.post("/api/v1/auth/login", json={"email": "asha@example.com", "password": PASSWORD})
    assert old.status_code == 401
    new = anon.post(
        "/api/v1/auth/login", json={"email": "asha@example.com", "password": NEW_PASSWORD}
    )
    assert new.status_code == 200
    assert new.json()["user"]["email_verified"] is True  # the code proved the address
    stale = anon.post("/api/v1/auth/refresh", json={"refresh_token": tokens["refresh_token"]})
    assert stale.status_code == 401

    reused = anon.post(
        "/api/v1/auth/password-reset/confirm",
        json={"email": "asha@example.com", "code": code, "new_password": "yet another one!"},
    )
    assert reused.status_code == 400  # single use


def test_reset_does_not_reveal_whether_an_account_exists(
    anon: TestClient, mail: FakeEmailSender
) -> None:
    register(anon)
    mail.sent.clear()

    known = anon.post("/api/v1/auth/password-reset/request", json={"email": "asha@example.com"})
    unknown = anon.post("/api/v1/auth/password-reset/request", json={"email": "who@example.com"})

    assert known.status_code == unknown.status_code == 202
    assert known.json() == unknown.json()
    assert [m.to for m in mail.sent] == ["asha@example.com"]
    bad = anon.post(
        "/api/v1/auth/password-reset/confirm",
        json={"email": "who@example.com", "code": "123456", "new_password": NEW_PASSWORD},
    )
    assert bad.status_code == 400
    assert bad.json()["error"]["code"] == "invalid_code"


def test_codes_expire_allow_few_attempts_and_newer_codes_replace_older(
    anon: TestClient, mail: FakeEmailSender, db_session: Session
) -> None:
    register(anon)

    def request_code() -> str:
        anon.post("/api/v1/auth/password-reset/request", json={"email": "asha@example.com"})
        return mail.last_code()

    def confirm(code: str) -> int:
        return anon.post(
            "/api/v1/auth/password-reset/confirm",
            json={"email": "asha@example.com", "code": code, "new_password": NEW_PASSWORD},
        ).status_code

    first = request_code()
    second = request_code()
    if first != second:
        assert confirm(first) == 400  # replaced by the newer code

    wrong = "999999" if second != "999999" else "888888"
    for _ in range(5):
        assert confirm(wrong) == 400
    assert confirm(second) == 400  # too many attempts: even the right code fails now

    third = request_code()
    row = db_session.scalars(
        select(AccountCode).where(AccountCode.used_at.is_(None), AccountCode.purpose == "reset")
    ).one()
    row.expires_at = datetime.now(UTC) - timedelta(seconds=1)
    db_session.flush()
    assert confirm(third) == 400  # expired


def test_code_format_and_password_rules(anon: TestClient) -> None:
    register(anon)
    for body in (
        {"email": "asha@example.com", "code": "12345", "new_password": NEW_PASSWORD},
        {"email": "asha@example.com", "code": "abcdef", "new_password": NEW_PASSWORD},
        {"email": "asha@example.com", "code": "123456", "new_password": "short"},
    ):
        assert anon.post("/api/v1/auth/password-reset/confirm", json=body).status_code == 422


def test_file_outbox_writes_eml_files(tmp_path: Path) -> None:
    sender = FileOutboxEmailSender(tmp_path / "outbox")
    sender.send(OutgoingEmail(to="a@example.com", subject="Hi", text="Code 123456"))

    [path] = list((tmp_path / "outbox").glob("*.eml"))
    content = path.read_text(encoding="utf-8")
    assert "To: a@example.com" in content and "Code 123456" in content


def test_staging_requires_smtp_and_a_shared_rate_limit_store() -> None:
    base: dict[str, Any] = {"_env_file": None, "environment": "staging", "auth_secret": "s" * 40}
    with pytest.raises(ValueError, match="RATE_LIMIT_BACKEND"):
        Settings(**base, email_backend="smtp", smtp_host="smtp.example.com", smtp_from="x@y.z")
    with pytest.raises(ValueError, match="SMTP"):
        Settings(**base, rate_limit_backend="postgres")
    ok = Settings(
        **base,
        rate_limit_backend="postgres",
        email_backend="smtp",
        smtp_host="smtp.example.com",
        smtp_from="PrepLoop <no-reply@example.com>",
    )
    assert ok.smtp_port == 587


def test_users_table_has_no_plain_codes(db_session: Session, anon: TestClient) -> None:
    register(anon)
    user = db_session.scalars(select(User)).one()
    assert user.email_verified is False
