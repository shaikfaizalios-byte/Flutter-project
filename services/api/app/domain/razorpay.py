"""Razorpay rules for PrepLoop Plus on the website (pure; docs/plus.md "Razorpay").

The server never trusts what the browser or a webhook says about a payment. Signatures are
checked and recorded, but a payment counts only from Razorpay's own answer to "the payments of this
order" (Orders API), read here by `outcome`.

- Checkout signature: HMAC-SHA256 of "<razorpay order id>|<payment id>" with the key secret, hex.
- Webhook signature (X-Razorpay-Signature): HMAC-SHA256 of the raw body with the webhook secret.
- Test keys start with rzp_test_ and live keys with rzp_live_; test payments move no money.
"""

import hashlib
import hmac
from collections.abc import Mapping, Sequence
from dataclasses import dataclass
from typing import Any, Literal

from app.domain.paytm import Environment

API_BASE = "https://api.razorpay.com/v1"
CHECKOUT_SCRIPT = "https://checkout.razorpay.com/v1/checkout.js"
KEY_PREFIXES: dict[str, Environment] = {"rzp_test_": "staging", "rzp_live_": "production"}

Outcome = Literal["success", "refunded", "pending", "failed", "unpaid", "mismatch"]


def environment_of(key_id: str) -> Environment | None:
    """staging for test keys, production for live keys, None for anything else."""
    for prefix, environment in KEY_PREFIXES.items():
        if key_id.startswith(prefix) and len(key_id) > len(prefix):
            return environment
    return None


def _hex_hmac(secret: str, message: bytes) -> str:
    return hmac.new(secret.encode(), message, hashlib.sha256).hexdigest()


def payment_signature(razorpay_order_id: str, payment_id: str, key_secret: str) -> str:
    return _hex_hmac(key_secret, f"{razorpay_order_id}|{payment_id}".encode())


def payment_signature_valid(
    razorpay_order_id: str, payment_id: str, signature: str, key_secret: str
) -> bool:
    """The checkout's razorpay_signature, checked against the order id stored on the server."""
    if not razorpay_order_id or not payment_id or not signature:
        return False
    expected = payment_signature(razorpay_order_id, payment_id, key_secret)
    return hmac.compare_digest(expected, signature.strip().lower())


def webhook_signature_valid(body: bytes, signature: str | None, webhook_secret: str) -> bool:
    if not signature or not webhook_secret:
        return False
    return hmac.compare_digest(_hex_hmac(webhook_secret, body), signature.strip().lower())


def webhook_order_id(event: Mapping[str, Any]) -> str | None:
    """The Razorpay order a webhook is about: payment.*, refund.* (via their payment) or
    order.paid. None when the event names no order."""
    payload = event.get("payload")
    if not isinstance(payload, Mapping):
        return None
    for name in ("payment", "order"):
        part = payload.get(name)
        entity = part.get("entity") if isinstance(part, Mapping) else None
        if isinstance(entity, Mapping):
            value = entity.get("order_id") if name == "payment" else entity.get("id")
            if isinstance(value, str) and value.startswith("order_"):
                return value
    return None


@dataclass(frozen=True, slots=True)
class PaymentFound:
    payment_id: str
    method: str


def _int(value: object) -> int:
    if isinstance(value, bool):
        return 0
    if isinstance(value, int):
        return value
    return 0


def outcome(
    data: Mapping[str, Any], *, razorpay_order_id: str, amount_paise: int
) -> tuple[Outcome, PaymentFound | None]:
    """What Razorpay's list of payments for an order says.

    success: a captured payment of the whole amount in INR (a partial refund changes nothing).
    refunded: that payment was refunded in full. pending: authorized, not yet captured (Razorpay
    captures or returns it). failed: only failed attempts, or an authorization Razorpay returned
    without capturing. unpaid: no attempt yet. mismatch: a payment of another order, amount or
    currency: never applied.
    """
    items = data.get("items")
    payments: Sequence[Any] = items if isinstance(items, list) else []
    pending = failed = False
    for item in payments:
        if not isinstance(item, Mapping):
            continue
        if item.get("order_id") != razorpay_order_id:
            return "mismatch", None
        status = item.get("status")
        captured = item.get("captured") is True or status == "captured"
        if captured:
            if item.get("currency") != "INR" or _int(item.get("amount")) != amount_paise:
                return "mismatch", None
            found = PaymentFound(str(item.get("id") or ""), str(item.get("method") or ""))
            if _int(item.get("amount_refunded")) >= amount_paise:
                return "refunded", found
            return "success", found
        if status in ("authorized", "created", "pending"):
            pending = True
        elif status in ("failed", "refunded"):  # refunded uncaptured = returned authorization
            failed = True
    if pending:
        return "pending", None
    if failed:
        return "failed", None
    return "unpaid", None
