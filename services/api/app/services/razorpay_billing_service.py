"""PrepLoop Plus bought on the website with Razorpay (app/domain/razorpay.py, docs/plus.md).

- `create_order`: a signed-in learner asks to pay. The price and days come from the server's
  settings; Razorpay is asked for an order, and the app gets a short-lived link to a page that
  opens Razorpay's checkout for it.
- `refresh`: the checkout's callback (the browser coming back), a webhook, or the app asking.
  Whichever it is, the server asks Razorpay for the order's payments and acts only on that answer:
  a captured payment of the whole amount adds the order's days of Plus, once; a full refund takes
  them back. Refund webhooks arrive here too (they name the payment's order).

Every step is recorded in `billing_events` (order id hash only, no payment details).
"""

import logging
import uuid
from collections.abc import Callable
from dataclasses import dataclass
from datetime import UTC, datetime, timedelta

from sqlalchemy import func, select
from sqlalchemy.orm import Session

from app.core.config import Settings
from app.domain import paytm, razorpay
from app.domain.errors import (
    BillingUnavailableError,
    InvalidReferenceError,
    NotFoundError,
    RateLimitedError,
    StoreUnavailableError,
)
from app.integrations.razorpay import RazorpayClient, RazorpayError
from app.models.plus import BillingEvent, WebPayment
from app.services.web_billing_service import (
    ORDERS_PER_HOUR,
    Kind,
    NewOrder,
    grant_days,
    order_hash,
    take_back,
)

logger = logging.getLogger(__name__)

PAY_LINK_MINUTES = 30
PAYABLE = ("created", "pending", "failed")  # a failed attempt can be tried again on the order


@dataclass(frozen=True, slots=True)
class Checkout:
    """What the payment page gives Razorpay's checkout script."""

    key_id: str
    razorpay_order_id: str
    order_id: str
    amount_paise: int
    callback_url: str
    return_url: str


class RazorpayBillingService:
    provider = "razorpay"

    def __init__(
        self,
        session: Session,
        settings: Settings,
        client: RazorpayClient | None,
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

    @property
    def test_payments(self) -> bool:
        return self._client is None or self._client.environment != "production"

    def offer(self) -> tuple[int, int] | None:
        """(price in paise, days) when Plus can be bought on the website."""
        if self._client is None or self._settings.razorpay_plus_price is None:
            return None
        price = paytm.paise(self._settings.razorpay_plus_price)
        days = self._settings.razorpay_plus_days
        return (price, days) if price and days else None

    # --- the learner starts paying ----------------------------------------------------------

    def create_order(self, owner_id: uuid.UUID) -> NewOrder:
        client = self._require_client()
        offer = self.offer()
        if offer is None or not self._settings.razorpay_callback_url:
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
            provider="razorpay",
            environment=client.environment,
            order_id=paytm.new_order_id(),
            amount_paise=amount,
            currency="INR",
            days=days,
            status="created",
        )
        try:
            payment.provider_order_id = client.create_order(amount, payment.order_id)
        except RazorpayError as exc:
            logger.warning("Razorpay refused a new order: %s", exc.reason)
            self._event("order", payment.order_id, owner_id, "error", exc.reason)
            self._session.commit()
            raise StoreUnavailableError("Razorpay could not be reached. Try again.") from exc
        self._session.add(payment)
        self._event("order", payment.order_id, owner_id, "applied", paytm.rupees(amount))
        self._session.commit()
        expires = int((now + timedelta(minutes=PAY_LINK_MINUTES)).timestamp())
        signature = paytm.link_signature(payment.order_id, expires, self._link_key)
        return NewOrder(
            payment.order_id,
            f"/api/v1/billing/razorpay/pay/{payment.order_id}?e={expires}&s={signature}",
            amount,
            days,
        )

    def checkout(self, order_id: str, expires: int, signature: str) -> Checkout:
        client = self._require_client()
        expired = NotFoundError("This payment link has expired. Start again from PrepLoop.")
        if not paytm.link_valid(order_id, expires, signature, self._link_key, self._now()):
            raise expired
        payment = self._payment(order_id)
        if payment is None or payment.status not in PAYABLE or not payment.provider_order_id:
            raise expired
        return Checkout(
            client.key_id,
            payment.provider_order_id,
            payment.order_id,
            payment.amount_paise,
            self._settings.razorpay_callback_url or "",
            self.return_url(order_id),
        )

    def return_url(self, order_id: str) -> str:
        return (self._settings.razorpay_return_url or "/").replace("{order}", order_id)

    # --- Razorpay says something happened, or the app asks ---------------------------------

    def order_id_for(self, razorpay_order_id: str) -> str | None:
        """Our order id for Razorpay's (callbacks and webhooks name Razorpay's)."""
        if not razorpay_order_id.startswith("order_"):
            return None
        return self._session.scalar(
            select(WebPayment.order_id).where(
                WebPayment.provider == "razorpay",
                WebPayment.provider_order_id == razorpay_order_id,
            )
        )

    def signature_valid(self, razorpay_order_id: str, payment_id: str, signature: str) -> bool:
        client = self._require_client()
        return client.signature_valid(razorpay_order_id, payment_id, signature)

    def refresh(
        self, order_id: str, kind: Kind, *, signature_ok: bool | None = None
    ) -> WebPayment | None:
        """Asks Razorpay for the order's payments and records what it says. None for an
        unknown order."""
        client = self._require_client()
        if not paytm.order_id_valid(order_id):
            raise InvalidReferenceError("Not a PrepLoop order.")
        payment = self._session.scalar(
            select(WebPayment)
            .where(WebPayment.order_id == order_id, WebPayment.provider == "razorpay")
            .with_for_update()
        )
        if payment is None or not payment.provider_order_id:
            self._event(kind, order_id, None, "unknown_token", "")
            self._session.commit()
            return None
        if payment.status == "refunded":
            self._session.commit()
            return payment
        try:
            data = client.order_payments(payment.provider_order_id)
        except RazorpayError as exc:
            self._session.commit()  # nothing changed; releases the row
            raise StoreUnavailableError("Razorpay could not be reached. Try again.") from exc
        now = self._now()
        result, found = razorpay.outcome(
            data, razorpay_order_id=payment.provider_order_id, amount_paise=payment.amount_paise
        )
        note: str = result
        if signature_ok is False:
            note += " signature_failed"  # recorded; Razorpay's answer is what counts anyway
        if result == "mismatch":
            logger.warning("Razorpay payments do not match a PrepLoop order")
            self._event(kind, order_id, payment.owner_id, "refused", note)
        elif result in ("success", "refunded"):
            if result == "success" and payment.status != "success":
                grant_days(self._session, payment, now)
            elif result == "refunded":
                take_back(self._session, payment, now)  # nothing given if never seen paid
            if found is not None:
                payment.txn_id = found.payment_id[:64] or None
                payment.payment_mode = found.method[:16] or None
            self._event(kind, order_id, payment.owner_id, "applied", note)
        else:
            if payment.status != "success" and result in ("pending", "failed"):
                payment.status = result
            self._event(kind, order_id, payment.owner_id, "ignored", note)
        self._session.commit()
        return payment

    def order_for(self, owner_id: uuid.UUID, order_id: str) -> WebPayment:
        """The learner's own order, refreshed from Razorpay while it is not settled."""
        payment = self._payment(order_id)
        if payment is None or payment.owner_id != owner_id:
            raise NotFoundError("Order not found.")
        if payment.status in PAYABLE and self._client is not None:
            refreshed = self.refresh(order_id, "status")
            return refreshed or payment
        return payment

    # --- shared -----------------------------------------------------------------------------

    def _payment(self, order_id: str) -> WebPayment | None:
        return self._session.scalar(
            select(WebPayment).where(
                WebPayment.order_id == order_id, WebPayment.provider == "razorpay"
            )
        )

    def _require_client(self) -> RazorpayClient:
        if self._client is None:
            raise BillingUnavailableError("Paying on the website is not available.")
        return self._client

    def _event(
        self, kind: str, order_id: str, owner_id: uuid.UUID | None, outcome: str, detail: str
    ) -> None:
        self._session.add(
            BillingEvent(
                provider="razorpay",
                event_key=f"razorpay:{kind}:{uuid.uuid4().hex}",
                kind=kind,
                token_hash=order_hash(order_id),
                owner_id=owner_id,
                outcome=outcome,
                detail=detail[:200],
            )
        )
