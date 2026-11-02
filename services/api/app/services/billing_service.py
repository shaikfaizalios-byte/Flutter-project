"""Google Play purchases → PrepLoop Plus (rules in app/domain/billing.py; docs/plus.md).

- `verify_play`: the app sends a purchase token after a purchase (or a restore). The server
  reads the purchase from the Play Developer API, checks it is ours and was made by this
  account, records it, acknowledges it and updates the account's subscription.
- `handle_notification`: Google's real-time developer notifications (Pub/Sub push). Each
  message is applied once; the purchase is always read again from Google, never taken from
  the notification itself.

Every check and notification is recorded in `billing_events` (token hash only).
"""

import base64
import binascii
import json
import logging
import uuid
from collections.abc import Callable
from datetime import UTC, datetime
from typing import Any

from sqlalchemy import select
from sqlalchemy.orm import Session

from app.core.config import Settings
from app.domain import billing
from app.domain.errors import (
    BillingUnavailableError,
    InvalidReferenceError,
    PurchaseRefusedError,
    StoreUnavailableError,
)
from app.integrations.play_billing import PlayBillingClient, PlayBillingError
from app.models.plus import BillingEvent, PlayPurchase, Subscription

logger = logging.getLogger(__name__)

VOIDED_STATE = "VOIDED"  # refunded or charged back (voidedPurchaseNotification)


class BillingService:
    def __init__(
        self,
        session: Session,
        settings: Settings,
        client: PlayBillingClient | None,
        *,
        account_secret: str,
        now: Callable[[], datetime] | None = None,
    ) -> None:
        self._session = session
        self._settings = settings
        self._client = client
        self._secret = account_secret
        self._now = now or (lambda: datetime.now(UTC))

    def play_account_id(self, owner_id: uuid.UUID) -> str:
        return billing.play_account_id(self._secret, owner_id)

    # --- the app reports a purchase ---------------------------------------------------------

    def verify_play(self, owner_id: uuid.UUID, product_id: str, purchase_token: str) -> None:
        client = self._require_client()
        if product_id not in self._settings.play_subscription_ids:
            raise InvalidReferenceError("Unknown PrepLoop Plus product.")
        token_hash = billing.token_hash(purchase_token)
        now = self._now()
        try:
            data = client.get_subscription(purchase_token)
        except PlayBillingError as exc:
            if exc.not_found:
                self._event("verify", token_hash, owner_id, "refused", "not_found", now)
                self._session.commit()
                raise PurchaseRefusedError("Google Play does not know this purchase.") from exc
            raise StoreUnavailableError("Google Play could not be reached. Try again.") from exc
        sub = billing.parse_subscription(data, self._settings.play_subscription_ids)
        problems = billing.problems(sub, expected_account_id=self.play_account_id(owner_id))
        existing = self._purchase(purchase_token)
        if existing is not None and existing.owner_id != owner_id:
            problems.append("token_of_another_account")
        if problems:
            self._event("verify", token_hash, owner_id, "refused", ",".join(problems), now)
            self._session.commit()
            raise PurchaseRefusedError("This purchase can't be added to this account.")
        self._record(owner_id, purchase_token, sub, existing)
        self._refresh_entitlement(owner_id, now)
        self._event("verify", token_hash, owner_id, "applied", sub.state, now)
        self._session.commit()

    # --- Google tells us something changed --------------------------------------------------

    def handle_notification(self, body: dict[str, Any]) -> None:
        message = body.get("message")
        if not isinstance(message, dict) or not message.get("messageId"):
            raise InvalidReferenceError("Not a Pub/Sub push message.")
        key = f"rtdn:{message['messageId']}"[:160]
        if self._session.scalar(select(BillingEvent.id).where(BillingEvent.event_key == key)):
            return  # delivered again: already handled
        try:
            payload = json.loads(base64.b64decode(str(message.get("data") or "")))
        except (binascii.Error, ValueError) as exc:
            raise InvalidReferenceError("The notification data is not readable.") from exc
        now = self._now()
        if not isinstance(payload, dict) or payload.get("packageName") != (
            self._settings.play_package_name
        ):
            self._event("test", None, None, "ignored", "other_package", now, key=key)
            self._session.commit()
            return
        if "testNotification" in payload:
            self._event("test", None, None, "applied", "test", now, key=key)
        elif isinstance(payload.get("voidedPurchaseNotification"), dict):
            self._voided(payload["voidedPurchaseNotification"], key, now)
        elif isinstance(payload.get("subscriptionNotification"), dict):
            self._subscription_changed(payload["subscriptionNotification"], key, now)
        else:
            self._event("test", None, None, "ignored", "other_notification", now, key=key)
        self._session.commit()

    def _subscription_changed(self, note: dict[str, Any], key: str, now: datetime) -> None:
        token = str(note.get("purchaseToken") or "")
        kind_type = note.get("notificationType")
        n_type = kind_type if isinstance(kind_type, int) else None
        purchase = self._purchase(token) if token else None
        token_hash = billing.token_hash(token) if token else None
        if purchase is None:
            # Not reported by the app yet (it verifies after the purchase); nothing to update.
            self._event("subscription", token_hash, None, "unknown_token", "", now, key, n_type)
            return
        client = self._require_client()
        try:
            data = client.get_subscription(token)
        except PlayBillingError as exc:
            # Not recorded: Pub/Sub delivers the message again later.
            raise StoreUnavailableError("Google Play could not be reached.") from exc
        sub = billing.parse_subscription(data, self._settings.play_subscription_ids)
        self._record(purchase.owner_id, token, sub, purchase)
        self._refresh_entitlement(purchase.owner_id, now)
        self._event(
            "subscription", token_hash, purchase.owner_id, "applied", sub.state, now, key, n_type
        )

    def _voided(self, note: dict[str, Any], key: str, now: datetime) -> None:
        token = str(note.get("purchaseToken") or "")
        purchase = self._purchase(token) if token else None
        token_hash = billing.token_hash(token) if token else None
        if purchase is None:
            self._event("voided", token_hash, None, "unknown_token", "", now, key)
            return
        purchase.state = VOIDED_STATE
        purchase.expires_at = now
        self._refresh_entitlement(purchase.owner_id, now)
        self._event("voided", token_hash, purchase.owner_id, "applied", "", now, key)

    # --- shared -----------------------------------------------------------------------------

    def _record(
        self,
        owner_id: uuid.UUID,
        token: str,
        sub: billing.PlaySubscription,
        purchase: PlayPurchase | None,
    ) -> None:
        if purchase is None:
            purchase = PlayPurchase(owner_id=owner_id, purchase_token=token)
            self._session.add(purchase)
        purchase.product_id = sub.product_id or purchase.product_id
        if purchase.state != VOIDED_STATE:  # a refund is final
            purchase.state = sub.state
            purchase.expires_at = sub.expires_at
        purchase.test_purchase = sub.test_purchase
        purchase.acknowledged = sub.acknowledged
        self._session.flush()
        if sub.linked_purchase_token:
            old = self._purchase(sub.linked_purchase_token)
            if old is not None and old.owner_id == owner_id and old.id != purchase.id:
                old.replaced_by_id = purchase.id
        if not purchase.acknowledged and sub.state in billing.ENTITLED_STATES:
            try:
                self._require_client().acknowledge(purchase.product_id, token)
                purchase.acknowledged = True
            except PlayBillingError:
                # Retried on the next check or notification; Play allows three days.
                logger.warning("Acknowledging a Play purchase failed")

    def _refresh_entitlement(self, owner_id: uuid.UUID, now: datetime) -> None:
        """The account's subscription follows its current Play purchases. Operator grants and
        test subscriptions that last longer are left alone."""
        purchases = self._session.scalars(
            select(PlayPurchase).where(
                PlayPurchase.owner_id == owner_id, PlayPurchase.replaced_by_id.is_(None)
            )
        ).all()
        until: datetime | None = None
        for p in purchases:
            if p.state == VOIDED_STATE:
                continue
            state = billing.PlaySubscription(
                p.state, p.product_id, p.expires_at, p.acknowledged, None, None, p.test_purchase
            )
            ends = billing.entitled_until(state, now)
            if ends is not None and (until is None or ends > until):
                until = ends
        sub = self._session.get(Subscription, owner_id)
        if until is not None:
            if sub is None:
                sub = Subscription(owner_id=owner_id, plan="plus", source="play")
                self._session.add(sub)
            elif sub.source != "play" and sub.active_until >= until:
                return
            sub.source = "play"
            sub.active_until = until
            sub.note = None
        elif sub is not None and sub.source == "play" and sub.active_until > now:
            sub.active_until = now  # expired, on hold, paused or refunded

    def _purchase(self, token: str) -> PlayPurchase | None:
        return self._session.scalar(
            select(PlayPurchase).where(PlayPurchase.purchase_token == token)
        )

    def _require_client(self) -> PlayBillingClient:
        if self._client is None:
            raise BillingUnavailableError("Purchases are not available on this server.")
        return self._client

    def _event(
        self,
        kind: str,
        token_hash: str | None,
        owner_id: uuid.UUID | None,
        outcome: str,
        detail: str,
        now: datetime,
        key: str | None = None,
        notification_type: int | None = None,
    ) -> None:
        self._session.add(
            BillingEvent(
                provider="play",
                event_key=key or f"{kind}:{token_hash or '-'}:{now.isoformat()}:{uuid.uuid4().hex}",
                kind=kind,
                notification_type=notification_type,
                token_hash=token_hash,
                owner_id=owner_id,
                outcome=outcome,
                detail=detail[:200],
            )
        )
