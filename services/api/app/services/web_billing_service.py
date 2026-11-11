"""PrepLoop Plus bought on the website with Paytm (rules in app/domain/paytm.py; docs/plus.md).

- `create_order`: a signed-in learner asks to pay. The price and days come from the server's
  settings; Paytm is asked for a transaction, and the app gets a short-lived link to a page that
  sends the browser to Paytm's payment page.
- `refresh`: Paytm's callback (the browser coming back), its payment-status webhook, or the app
  asking. Whichever it is, the server asks Paytm's Transaction Status API about the order and acts
  only on that answer: a success for this merchant, order and amount adds the order's days of Plus,
  once; a full refund takes them back.
- `refund_notice`: Paytm's refund webhooks. The refund is checked with Paytm's Refund Status API;
  only a successful refund of the whole amount takes the order's days back.

Every step is recorded in `billing_events` (order id hash only, no payment details).
"""

import hashlib
import logging
import uuid
from collections.abc import Callable
from dataclasses import dataclass
from datetime import UTC, datetime, timedelta
from typing import Literal

from sqlalchemy import func, select
from sqlalchemy.orm import Session

from app.core.config import Settings
from app.domain import paytm
from app.domain.errors import (
    BillingUnavailableError,
    InvalidReferenceError,
    NotFoundError,
    RateLimitedError,
    StoreUnavailableError,
)
from app.integrations.paytm import PaytmClient, PaytmError
from app.models.plus import BillingEvent, Subscription, WebPayment

logger = logging.getLogger(__name__)

PAY_LINK_MINUTES = 15  # Paytm's transaction token lasts about as long
ORDERS_PER_HOUR = 10
FINAL = ("failed", "refunded")
Kind = Literal["callback", "webhook", "status"]


@dataclass(frozen=True, slots=True)
class NewOrder:
    order_id: str
    pay_path: str
    amount_paise: int
    days: int


@dataclass(frozen=True, slots=True)
class PayForm:
    action: str
    mid: str
    order_id: str
    txn_token: str


def order_hash(order_id: str) -> str:
    return hashlib.sha256(order_id.encode()).hexdigest()


class WebBillingService:
    def __init__(
        self,
        session: Session,
        settings: Settings,
        client: PaytmClient | None,
        *,
        link_key: bytes,
        now: Callable[[], datetime] | None = None,
    ) -> None:
        self._session = session
        self._settings = settings
        self._client = client
        self._link_key = link_key
        self._now = now or (lambda: datetime.now(UTC))

    @property
    def available(self) -> bool:
        return self._client is not None

    def offer(self) -> tuple[int, int] | None:
        """(price in paise, days) when Plus can be bought on the website."""
        if self._client is None or self._settings.paytm_plus_price is None:
            return None
        price = paytm.paise(self._settings.paytm_plus_price)
        days = self._settings.paytm_plus_days
        return (price, days) if price and days else None

    # --- the learner starts paying ----------------------------------------------------------

    def create_order(self, owner_id: uuid.UUID) -> NewOrder:
        client = self._require_client()
        offer = self.offer()
        callback = self._settings.paytm_callback_url
        if offer is None or not callback:
            raise BillingUnavailableError("Paying on the website is not available.")
        now = self._now()
        recent = self._session.scalar(
            select(func.count(WebPayment.id)).where(
                WebPayment.owner_id == owner_id, WebPayment.created_at > now - timedelta(hours=1)
            )
        )
        if (recent or 0) >= ORDERS_PER_HOUR:
            raise RateLimitedError("Too many payment attempts. Please try again later.", 3600)
        amount, days = offer
        payment = WebPayment(
            owner_id=owner_id,
            provider="paytm",
            environment=client.environment,
            order_id=paytm.new_order_id(),
            amount_paise=amount,
            currency="INR",
            days=days,
            status="created",
        )
        try:
            payment.txn_token = client.initiate(
                payment.order_id, paytm.rupees(amount), f"CUST_{owner_id.hex}", callback
            )
        except PaytmError as exc:
            logger.warning("Paytm refused a new order: %s", exc.reason)
            self._event("order", payment.order_id, owner_id, "error", exc.reason)
            self._session.commit()
            raise StoreUnavailableError("Paytm could not be reached. Try again.") from exc
        self._session.add(payment)
        self._event("order", payment.order_id, owner_id, "applied", paytm.rupees(amount))
        self._session.commit()
        expires = int((now + timedelta(minutes=PAY_LINK_MINUTES)).timestamp())
        signature = paytm.link_signature(payment.order_id, expires, self._link_key)
        return NewOrder(
            payment.order_id,
            f"/api/v1/billing/paytm/pay/{payment.order_id}?e={expires}&s={signature}",
            amount,
            days,
        )

    def pay_form(self, order_id: str, expires: int, signature: str) -> PayForm:
        """What the payment page posts to Paytm. The link expires with Paytm's token."""
        client = self._require_client()
        if not paytm.link_valid(order_id, expires, signature, self._link_key, self._now()):
            raise NotFoundError("This payment link has expired. Start again from PrepLoop.")
        payment = self._payment(order_id)
        if payment is None or payment.status != "created" or not payment.txn_token:
            raise NotFoundError("This payment link has expired. Start again from PrepLoop.")
        return PayForm(client.payment_page_url(order_id), client.mid, order_id, payment.txn_token)

    # --- Paytm says something happened, or the app asks ------------------------------------

    def refresh(
        self, order_id: str, kind: Kind, *, checksum_ok: bool | None = None
    ) -> WebPayment | None:
        """Asks Paytm about the order and records what it says. None for an unknown order."""
        client = self._require_client()
        if not paytm.order_id_valid(order_id):
            raise InvalidReferenceError("Not a PrepLoop order.")
        payment = self._session.scalar(
            select(WebPayment).where(WebPayment.order_id == order_id).with_for_update()
        )
        if payment is None:
            self._event(kind, order_id, None, "unknown_token", "")
            self._session.commit()
            return None
        if payment.status in FINAL:
            self._session.commit()
            return payment
        try:
            data = client.status(order_id)
        except PaytmError as exc:
            self._session.commit()  # nothing changed; releases the row
            raise StoreUnavailableError("Paytm could not be reached. Try again.") from exc
        now = self._now()
        status = paytm.read_status(data)
        result = paytm.outcome(
            status, mid=client.mid, order_id=order_id, amount_paise=payment.amount_paise
        )
        payment.result_code = status.result_code[:16] or None
        note = f"{result} {status.result_code}".strip()
        if checksum_ok is False:
            note += " checksum_failed"  # recorded; the status answer is what counts anyway
        if result == "mismatch":
            logger.warning("Paytm status does not match a PrepLoop order")
            self._event(kind, order_id, payment.owner_id, "refused", note)
        elif result == "success":
            if payment.status != "success":
                self._grant(payment, status, now)
            self._event(kind, order_id, payment.owner_id, "applied", note)
        elif result == "refunded":
            self._refund(payment, now)
            self._event(kind, order_id, payment.owner_id, "applied", note)
        else:
            if payment.status != "success":
                payment.status = {"failed": "failed", "pending": "pending"}.get(
                    result, payment.status
                )
            if payment.status == "failed":
                payment.txn_token = None
            self._event(kind, order_id, payment.owner_id, "ignored", note)
        self._session.commit()
        return payment

    def refund_notice(self, order_id: str, ref_id: str | None) -> WebPayment | None:
        """A refund webhook named this order. Without the refund's reference, the order status
        (which carries the refunded amount) is asked instead."""
        client = self._require_client()
        if not paytm.order_id_valid(order_id):
            raise InvalidReferenceError("Not a PrepLoop order.")
        if not ref_id:
            return self.refresh(order_id, "webhook")
        payment = self._session.scalar(
            select(WebPayment).where(WebPayment.order_id == order_id).with_for_update()
        )
        if payment is None:
            self._event("webhook", order_id, None, "unknown_token", "refund")
            self._session.commit()
            return None
        if payment.status == "refunded":
            self._session.commit()
            return payment
        try:
            data = client.refund_status(order_id, ref_id)
        except PaytmError as exc:
            self._session.commit()  # nothing changed; releases the row
            raise StoreUnavailableError("Paytm could not be reached. Try again.") from exc
        result = paytm.refund_outcome(
            data, mid=client.mid, order_id=order_id, amount_paise=payment.amount_paise
        )
        note = f"refund {result}"
        if result == "refunded":
            self._refund(payment, self._now())
            self._event("webhook", order_id, payment.owner_id, "applied", note)
        elif result == "mismatch":
            logger.warning("Paytm refund status does not match a PrepLoop order")
            self._event("webhook", order_id, payment.owner_id, "refused", note)
        else:
            self._event("webhook", order_id, payment.owner_id, "ignored", note)
        self._session.commit()
        return payment

    def order_for(self, owner_id: uuid.UUID, order_id: str) -> WebPayment:
        """The learner's own order, refreshed from Paytm while it is not settled."""
        payment = self._payment(order_id)
        if payment is None or payment.owner_id != owner_id:
            raise NotFoundError("Order not found.")
        if payment.status in ("created", "pending") and self._client is not None:
            refreshed = self.refresh(order_id, "status")
            return refreshed or payment
        return payment

    # --- shared -----------------------------------------------------------------------------

    def _grant(self, payment: WebPayment, status: paytm.PaytmStatus, now: datetime) -> None:
        sub = self._session.get(Subscription, payment.owner_id, with_for_update=True)
        current = (
            sub.active_until
            if sub is not None and sub.source != "test" and sub.active_until > now
            else None
        )
        start, until = paytm.granted_window(now, current, payment.days)
        if sub is None:
            sub = Subscription(owner_id=payment.owner_id, plan="plus", source="web")
            self._session.add(sub)
        sub.source = "web"
        sub.active_until = until
        sub.note = None
        payment.status = "success"
        payment.granted_from = start
        payment.granted_until = until
        payment.paid_at = now
        payment.txn_id = status.txn_id
        payment.payment_mode = (status.payment_mode or "")[:16] or None
        payment.txn_token = None

    def _refund(self, payment: WebPayment, now: datetime) -> None:
        if payment.status == "success":
            sub = self._session.get(Subscription, payment.owner_id, with_for_update=True)
            if sub is not None and sub.source == "web":
                sub.active_until = max(now, sub.active_until - timedelta(days=payment.days))
        else:  # refunded before we ever saw it paid: nothing was given
            payment.granted_from = payment.granted_from or now
            payment.granted_until = payment.granted_until or now
        payment.status = "refunded"
        payment.txn_token = None

    def _payment(self, order_id: str) -> WebPayment | None:
        return self._session.scalar(select(WebPayment).where(WebPayment.order_id == order_id))

    def _require_client(self) -> PaytmClient:
        if self._client is None:
            raise BillingUnavailableError("Paying on the website is not available.")
        return self._client

    def _event(
        self, kind: str, order_id: str, owner_id: uuid.UUID | None, outcome: str, detail: str
    ) -> None:
        self._session.add(
            BillingEvent(
                provider="paytm",
                event_key=f"paytm:{kind}:{uuid.uuid4().hex}",
                kind=kind,
                token_hash=order_hash(order_id),
                owner_id=owner_id,
                outcome=outcome,
                detail=detail[:200],
            )
        )
