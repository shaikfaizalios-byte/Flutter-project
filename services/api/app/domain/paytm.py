"""Paytm Payment Gateway rules for buying PrepLoop Plus on the website. Pure.

Checksums follow Paytm's published algorithm (github.com/paytm/Paytm_Python_Checksum, MIT):
SHA-256 of "<params>|<salt>", the hex digest plus the 4-character salt encrypted with AES-128-CBC
under the merchant key and a fixed IV, then Base64. Form parameters are joined with "|" in key
order (a missing or "null" value counts as empty); a JSON request body is signed as its exact text.

The server never trusts a callback or webhook on its own: their only use is to say which order to
ask Paytm about. What counts is Paytm's Transaction Status API answer (`read_status`, `outcome`).
"""

import base64
import hashlib
import hmac
import secrets
import string
from collections.abc import Mapping
from dataclasses import dataclass
from datetime import datetime, timedelta
from decimal import Decimal, InvalidOperation
from typing import Any, Literal

from cryptography.hazmat.primitives import padding
from cryptography.hazmat.primitives.ciphers import Cipher, algorithms, modes

IV = b"@@@@&&&&####$$$$"
SALT_ALPHABET = string.ascii_letters + string.digits
KEY_LENGTHS = (16, 24, 32)
ORDER_PREFIX = "PLUS-"

Environment = Literal["staging", "production"]
# Paytm's published hosts: transactions and the payment page, and the order status API.
HOSTS: dict[Environment, tuple[str, str]] = {
    "staging": ("https://securestage.paytmpayments.com", "https://securegw-stage.paytmpayments.in"),
    "production": ("https://secure.paytmpayments.com", "https://securegw.paytmpayments.in"),
}
DEFAULT_WEBSITE: dict[Environment, str] = {"staging": "WEBSTAGING", "production": "DEFAULT"}


class ChecksumError(ValueError):
    """A checksum that can't be read (not Base64, wrong length, bad padding)."""


def _hash(params: str, salt: str) -> str:
    return hashlib.sha256(f"{params}|{salt}".encode()).hexdigest() + salt


def _cipher(key: str) -> Cipher[modes.CBC]:
    raw = key.encode()
    if len(raw) not in KEY_LENGTHS:
        raise ChecksumError("The merchant key must be 16, 24 or 32 bytes.")
    return Cipher(algorithms.AES(raw), modes.CBC(IV))


def joined(params: Mapping[str, str | None]) -> str:
    """Form parameters as Paytm signs them (CHECKSUMHASH itself left out)."""
    values = []
    for key in sorted(params):
        if key == "CHECKSUMHASH":
            continue
        value = params[key]
        values.append("" if value is None or value.lower() == "null" else str(value))
    return "|".join(values)


def checksum(params: str, key: str, salt: str | None = None) -> str:
    salt = salt or "".join(secrets.choice(SALT_ALPHABET) for _ in range(4))
    padder = padding.PKCS7(128).padder()
    data = padder.update(_hash(params, salt).encode()) + padder.finalize()
    encryptor = _cipher(key).encryptor()
    return base64.b64encode(encryptor.update(data) + encryptor.finalize()).decode()


def checksum_valid(params: str, key: str, value: str) -> bool:
    try:
        raw = base64.b64decode(value, validate=True)
        decryptor = _cipher(key).decryptor()
        unpadder = padding.PKCS7(128).unpadder()
        plain = unpadder.update(decryptor.update(raw) + decryptor.finalize()) + unpadder.finalize()
        text = plain.decode()
    except (ValueError, ChecksumError):
        return False
    if len(text) < 5:
        return False
    return hmac.compare_digest(text, _hash(params, text[-4:]))


def form_valid(form: Mapping[str, str | None], key: str) -> bool:
    value = form.get("CHECKSUMHASH")
    return bool(value) and checksum_valid(joined(form), key, str(value))


def new_order_id() -> str:
    """Letters, digits and "-" only (Paytm allows up to 50 characters)."""
    return ORDER_PREFIX + secrets.token_hex(16)


def order_id_valid(value: str) -> bool:
    rest = value[len(ORDER_PREFIX) :]
    return (
        value.startswith(ORDER_PREFIX)
        and len(rest) == 32
        and all(c in "0123456789abcdef" for c in rest)
    )


def rupees(paise: int) -> str:
    """Paytm amounts: rupees with two decimals."""
    return f"{Decimal(paise) / 100:.2f}"


def paise(value: object) -> int | None:
    try:
        amount = Decimal(str(value))
    except (InvalidOperation, ValueError):
        return None
    if not amount.is_finite() or amount < 0:
        return None
    return int((amount * 100).to_integral_value())


@dataclass(frozen=True, slots=True)
class PaytmStatus:
    """The parts of a Transaction Status API answer we use."""

    result_status: str  # TXN_SUCCESS, TXN_FAILURE, PENDING, NO_RECORD_FOUND
    result_code: str
    mid: str | None
    order_id: str | None
    amount_paise: int | None
    refund_paise: int
    txn_id: str | None
    payment_mode: str | None


def read_status(data: Mapping[str, Any]) -> PaytmStatus:
    body = data.get("body")
    body = body if isinstance(body, Mapping) else {}
    info = body.get("resultInfo")
    info = info if isinstance(info, Mapping) else {}

    def text(value: object) -> str | None:
        return str(value) if value not in (None, "") else None

    return PaytmStatus(
        result_status=str(info.get("resultStatus") or ""),
        result_code=str(info.get("resultCode") or ""),
        mid=text(body.get("mid")),
        order_id=text(body.get("orderId")),
        amount_paise=paise(body.get("txnAmount")) if body.get("txnAmount") else None,
        refund_paise=paise(body.get("refundAmt") or 0) or 0,
        txn_id=text(body.get("txnId")),
        payment_mode=text(body.get("paymentMode")),
    )


Outcome = Literal["success", "failed", "pending", "unpaid", "refunded", "mismatch"]


def outcome(status: PaytmStatus, *, mid: str, order_id: str, amount_paise: int) -> Outcome:
    """What Paytm's answer means for this order.

    unpaid: Paytm has no payment for it (the learner never paid, or left the page).
    mismatch: Paytm says it was paid, but not this merchant, order or amount: never applied.
    refunded: paid, then refunded in full.
    """
    if status.result_status == "NO_RECORD_FOUND":
        return "unpaid"
    if status.result_status == "PENDING":
        return "pending"
    if status.result_status == "TXN_FAILURE":
        return "failed"
    if status.result_status != "TXN_SUCCESS":
        return "pending"  # unknown wording: ask again later, never grant
    if status.mid != mid or status.order_id != order_id or status.amount_paise != amount_paise:
        return "mismatch"
    if status.refund_paise >= amount_paise:
        return "refunded"
    return "success"


def granted_window(
    now: datetime, current_until: datetime | None, days: int
) -> tuple[datetime, datetime]:
    """A payment adds `days` after the Plus the account already has, or from now."""
    start = current_until if current_until is not None and current_until > now else now
    return start, start + timedelta(days=days)


def link_signature(order_id: str, expires: int, key: bytes) -> str:
    """For the payment page link (opened by the browser, so without the access token)."""
    message = f"paytm-pay:{order_id}:{expires}".encode()
    return hmac.new(key, message, hashlib.sha256).hexdigest()[:32]


def link_valid(order_id: str, expires: int, signature: str, key: bytes, now: datetime) -> bool:
    if expires < int(now.timestamp()):
        return False
    return hmac.compare_digest(signature, link_signature(order_id, expires, key))
