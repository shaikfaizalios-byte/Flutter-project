"""Google Play: the Play Developer API (subscription purchases) and verification of the
Pub/Sub push tokens that carry real-time developer notifications.

Uses a service account key (JSON) with access to the app in Play Console. Only the standard
library and PyJWT (with `cryptography` for RS256) are used. Purchase tokens and keys are never
logged.
"""

import json
import logging
import time
import urllib.error
import urllib.parse
import urllib.request
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any, Protocol

import jwt

from app.core.config import Settings

logger = logging.getLogger(__name__)

API = "https://androidpublisher.googleapis.com/androidpublisher/v3/applications"
SCOPE = "https://www.googleapis.com/auth/androidpublisher"
GOOGLE_CERTS = "https://www.googleapis.com/oauth2/v3/certs"
GOOGLE_ISSUERS = ("https://accounts.google.com", "accounts.google.com")
TIMEOUT_SECONDS = 15


class PlayBillingError(Exception):
    """The Play Developer API could not answer (network, credentials, unknown token)."""

    def __init__(self, reason: str, *, not_found: bool = False) -> None:
        super().__init__(reason)
        self.reason = reason
        self.not_found = not_found


class PlayBillingClient(Protocol):
    def get_subscription(self, purchase_token: str) -> dict[str, Any]:
        """purchases.subscriptionsv2.get for this app's package."""
        ...

    def acknowledge(self, product_id: str, purchase_token: str) -> None:
        """Acknowledges a purchase (Play refunds unacknowledged ones after three days)."""
        ...


class PushTokenVerifier(Protocol):
    def verify(self, authorization: str | None) -> None:
        """Raises PlayBillingError unless the header carries a valid push token."""
        ...


@dataclass
class GooglePlayClient:
    package_name: str
    service_account_file: Path
    _token: str | None = field(default=None, init=False, repr=False)
    _token_expires: float = field(default=0.0, init=False, repr=False)

    def get_subscription(self, purchase_token: str) -> dict[str, Any]:
        token = urllib.parse.quote(purchase_token, safe="")
        url = f"{API}/{self.package_name}/purchases/subscriptionsv2/tokens/{token}"
        return self._request("GET", url)

    def acknowledge(self, product_id: str, purchase_token: str) -> None:
        product = urllib.parse.quote(product_id, safe="")
        token = urllib.parse.quote(purchase_token, safe="")
        url = (
            f"{API}/{self.package_name}/purchases/subscriptions/{product}/tokens/{token}"
            ":acknowledge"
        )
        self._request("POST", url, body={})

    def _request(self, method: str, url: str, body: dict[str, Any] | None = None) -> dict[str, Any]:
        data = json.dumps(body).encode() if body is not None else None
        request = urllib.request.Request(  # noqa: S310 - fixed https Google API URL
            url,
            data=data,
            method=method,
            headers={
                "Authorization": f"Bearer {self._access_token()}",
                "Content-Type": "application/json",
            },
        )
        try:
            with urllib.request.urlopen(request, timeout=TIMEOUT_SECONDS) as response:  # noqa: S310
                raw = response.read()
        except urllib.error.HTTPError as exc:
            logger.warning("Play Developer API returned %s", exc.code)
            raise PlayBillingError(
                f"play_status_{exc.code}", not_found=exc.code in (404, 410)
            ) from exc
        except (urllib.error.URLError, TimeoutError) as exc:
            logger.warning("Play Developer API unreachable")
            raise PlayBillingError("play_unreachable") from exc
        if not raw:
            return {}
        parsed: dict[str, Any] = json.loads(raw)
        return parsed

    def _access_token(self) -> str:
        now = time.time()
        if self._token is not None and now < self._token_expires - 60:
            return self._token
        key = json.loads(self.service_account_file.read_text(encoding="utf-8"))
        assertion = jwt.encode(
            {
                "iss": key["client_email"],
                "scope": SCOPE,
                "aud": key["token_uri"],
                "iat": int(now),
                "exp": int(now) + 3600,
            },
            key["private_key"],
            algorithm="RS256",
        )
        form = urllib.parse.urlencode(
            {"grant_type": "urn:ietf:params:oauth:grant-type:jwt-bearer", "assertion": assertion}
        ).encode()
        request = urllib.request.Request(key["token_uri"], data=form, method="POST")  # noqa: S310
        try:
            with urllib.request.urlopen(request, timeout=TIMEOUT_SECONDS) as response:  # noqa: S310
                answer = json.loads(response.read())
        except (urllib.error.URLError, TimeoutError, ValueError) as exc:
            logger.warning("Google OAuth token request failed")
            raise PlayBillingError("play_auth_failed") from exc
        self._token = str(answer["access_token"])
        self._token_expires = now + float(answer.get("expires_in", 3600))
        return self._token


@dataclass
class GooglePushTokenVerifier:
    """Checks the OIDC token Pub/Sub attaches to push requests: signed by Google, for our
    audience, from the service account configured on the push subscription."""

    audience: str
    service_account: str
    _jwks: jwt.PyJWKClient = field(
        default_factory=lambda: jwt.PyJWKClient(GOOGLE_CERTS), init=False, repr=False
    )

    def verify(self, authorization: str | None) -> None:
        if not authorization or not authorization.lower().startswith("bearer "):
            raise PlayBillingError("push_token_missing")
        token = authorization[7:].strip()
        try:
            key = self._jwks.get_signing_key_from_jwt(token)
            claims = jwt.decode(
                token,
                key.key,
                algorithms=["RS256"],
                audience=self.audience,
                options={"require": ["iss", "aud", "exp", "email"]},
            )
        except jwt.PyJWTError as exc:
            raise PlayBillingError("push_token_invalid") from exc
        if claims.get("iss") not in GOOGLE_ISSUERS:
            raise PlayBillingError("push_token_issuer")
        if claims.get("email") != self.service_account or claims.get("email_verified") is not True:
            raise PlayBillingError("push_token_sender")


def play_client_from_settings(settings: Settings) -> PlayBillingClient | None:
    if not settings.play_package_name or settings.play_service_account_file is None:
        return None
    if not settings.play_subscription_ids:
        return None
    return GooglePlayClient(settings.play_package_name, settings.play_service_account_file)


def push_verifier_from_settings(settings: Settings) -> PushTokenVerifier | None:
    if not (settings.play_rtdn_audience and settings.play_rtdn_service_account):
        return None
    return GooglePushTokenVerifier(settings.play_rtdn_audience, settings.play_rtdn_service_account)
