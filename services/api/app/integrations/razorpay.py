"""Razorpay Orders API: create an order and read its payments (docs/plus.md "Razorpay").

HTTP basic auth with the key id and secret. Standard library only. The secret and payment
details are never logged.
"""

import base64
import http.client
import json
import logging
import urllib.error
import urllib.parse
import urllib.request
from dataclasses import dataclass, field
from typing import Any, Protocol

from app.core.config import Settings
from app.domain import razorpay
from app.domain.paytm import Environment

logger = logging.getLogger(__name__)

TIMEOUT_SECONDS = 20


class RazorpayError(Exception):
    """Razorpay could not be reached, or refused the request."""

    def __init__(self, reason: str) -> None:
        super().__init__(reason)
        self.reason = reason


class RazorpayClient(Protocol):
    key_id: str
    environment: Environment

    def create_order(self, amount_paise: int, receipt: str) -> str:
        """Creates an INR order; returns Razorpay's order id (order_...)."""
        ...

    def order_payments(self, razorpay_order_id: str) -> dict[str, Any]:
        """Razorpay's list of payments for an order."""
        ...

    def signature_valid(self, razorpay_order_id: str, payment_id: str, signature: str) -> bool:
        """Whether the checkout's signature fits this order and payment."""
        ...

    def webhook_valid(self, body: bytes, signature: str | None) -> bool:
        """Whether a webhook body carries Razorpay's signature for it."""
        ...


@dataclass
class RazorpayGateway:
    key_id: str
    key_secret: str = field(repr=False)
    webhook_secret: str = field(repr=False)
    environment: Environment
    base_url: str = razorpay.API_BASE

    def create_order(self, amount_paise: int, receipt: str) -> str:
        data = self._call(
            "POST",
            "/orders",
            {
                "amount": amount_paise,
                "currency": "INR",
                "receipt": receipt,
                "notes": {"preploop_order": receipt},
            },
        )
        order_id = data.get("id")
        if not isinstance(order_id, str) or not order_id.startswith("order_"):
            raise RazorpayError("order refused")
        return order_id

    def order_payments(self, razorpay_order_id: str) -> dict[str, Any]:
        quoted = urllib.parse.quote(razorpay_order_id, safe="")
        return self._call("GET", f"/orders/{quoted}/payments", None)

    def signature_valid(self, razorpay_order_id: str, payment_id: str, signature: str) -> bool:
        return razorpay.payment_signature_valid(
            razorpay_order_id, payment_id, signature, self.key_secret
        )

    def webhook_valid(self, body: bytes, signature: str | None) -> bool:
        return razorpay.webhook_signature_valid(body, signature, self.webhook_secret)

    def _call(self, method: str, path: str, body: dict[str, Any] | None) -> dict[str, Any]:
        auth = base64.b64encode(f"{self.key_id}:{self.key_secret}".encode()).decode()
        headers = {"Authorization": f"Basic {auth}"}
        payload = None
        if body is not None:
            payload = json.dumps(body).encode()
            headers["Content-Type"] = "application/json"
        request = urllib.request.Request(  # noqa: S310 - fixed https Razorpay URL
            self.base_url + path, data=payload, method=method, headers=headers
        )
        try:
            with urllib.request.urlopen(request, timeout=TIMEOUT_SECONDS) as response:  # noqa: S310
                data = json.loads(response.read())
        except urllib.error.HTTPError as exc:
            raise RazorpayError(f"HTTP {exc.code}") from exc
        except (OSError, http.client.HTTPException, ValueError) as exc:
            # URLError, timeouts and dropped connections (RemoteDisconnected) are all OSErrors.
            raise RazorpayError("unreachable") from exc
        if not isinstance(data, dict):
            raise RazorpayError("unexpected answer")
        return data


def razorpay_client_from_settings(settings: Settings) -> RazorpayClient | None:
    if (
        not settings.razorpay_configured
        or not settings.razorpay_key_id
        or not settings.razorpay_key_secret
        or not settings.razorpay_webhook_secret
    ):
        return None
    environment = razorpay.environment_of(settings.razorpay_key_id)
    if environment is None:
        return None
    return RazorpayGateway(
        key_id=settings.razorpay_key_id,
        key_secret=settings.razorpay_key_secret.get_secret_value(),
        webhook_secret=settings.razorpay_webhook_secret.get_secret_value(),
        environment=environment,
    )
