"""The real Google Play pieces, without the network: the service-account token request and
the Pub/Sub push-token check (keys generated here; Google's endpoints are stubbed)."""

import io
import json
import time
import urllib.parse
import urllib.request
from pathlib import Path
from typing import Any

import jwt
import pytest
from cryptography.hazmat.primitives import serialization
from cryptography.hazmat.primitives.asymmetric import rsa

from app.integrations.play_billing import (
    GooglePlayClient,
    GooglePushTokenVerifier,
    PlayBillingError,
)

KEY = rsa.generate_private_key(public_exponent=65537, key_size=2048)
PEM = KEY.private_bytes(
    serialization.Encoding.PEM,
    serialization.PrivateFormat.PKCS8,
    serialization.NoEncryption(),
).decode()
SENDER = "pubsub-push@example-project.iam.gserviceaccount.com"
AUDIENCE = "https://api.example.com/api/v1/billing/play/rtdn"


class _Response(io.BytesIO):
    def __enter__(self) -> "_Response":
        return self

    def __exit__(self, *args: object) -> None:
        self.close()


def test_the_play_client_signs_in_with_the_service_account_and_reads_a_purchase(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    key_file = tmp_path / "service-account.json"
    key_file.write_text(
        json.dumps(
            {
                "client_email": "billing@example.iam.gserviceaccount.com",
                "private_key": PEM,
                "token_uri": "https://oauth2.googleapis.com/token",
            }
        )
    )
    calls: list[urllib.request.Request] = []

    def fake_urlopen(request: urllib.request.Request, timeout: float) -> _Response:
        calls.append(request)
        if request.full_url.endswith("/token"):
            return _Response(json.dumps({"access_token": "at-1", "expires_in": 3600}).encode())
        return _Response(json.dumps({"subscriptionState": "SUBSCRIPTION_STATE_ACTIVE"}).encode())

    monkeypatch.setattr(urllib.request, "urlopen", fake_urlopen)
    client = GooglePlayClient("com.preploop.test", key_file)

    first = client.get_subscription("a/b+c")
    client.get_subscription("again")

    assert first == {"subscriptionState": "SUBSCRIPTION_STATE_ACTIVE"}
    assert len(calls) == 3  # one sign-in, reused for both reads
    body = calls[0].data
    assert isinstance(body, bytes)
    form = dict(urllib.parse.parse_qsl(body.decode()))
    claims = jwt.decode(
        form["assertion"],
        KEY.public_key(),
        algorithms=["RS256"],
        audience="https://oauth2.googleapis.com/token",
    )
    assert claims["scope"] == "https://www.googleapis.com/auth/androidpublisher"
    assert calls[1].full_url.endswith(
        "/com.preploop.test/purchases/subscriptionsv2/tokens/a%2Fb%2Bc"
    )
    assert calls[1].headers["Authorization"] == "Bearer at-1"


class _Keys:
    def get_signing_key_from_jwt(self, token: str) -> Any:
        return type("Key", (), {"key": KEY.public_key()})()


def push_token(**overrides: Any) -> str:
    claims = {
        "iss": "https://accounts.google.com",
        "aud": AUDIENCE,
        "email": SENDER,
        "email_verified": True,
        "exp": int(time.time()) + 600,
        **overrides,
    }
    return jwt.encode(claims, PEM, algorithm="RS256")


@pytest.mark.parametrize(
    ("header", "reason"),
    [
        (None, "push_token_missing"),
        ("Bearer " + push_token(aud="https://elsewhere.example"), "push_token_invalid"),
        ("Bearer " + push_token(exp=int(time.time()) - 10), "push_token_invalid"),
        ("Bearer " + push_token(iss="https://evil.example"), "push_token_issuer"),
        ("Bearer " + push_token(email="someone@example.com"), "push_token_sender"),
        ("Bearer " + push_token(email_verified=False), "push_token_sender"),
    ],
)
def test_push_tokens_must_be_googles_for_our_audience_and_sender(
    header: str | None, reason: str
) -> None:
    verifier = GooglePushTokenVerifier(AUDIENCE, SENDER)
    verifier._jwks = _Keys()  # type: ignore[assignment]

    with pytest.raises(PlayBillingError) as caught:
        verifier.verify(header)
    assert caught.value.reason == reason


def test_a_valid_push_token_passes() -> None:
    verifier = GooglePushTokenVerifier(AUDIENCE, SENDER)
    verifier._jwks = _Keys()  # type: ignore[assignment]

    verifier.verify("Bearer " + push_token())
