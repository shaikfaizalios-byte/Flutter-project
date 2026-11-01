"""Google Play subscriptions → PrepLoop Plus entitlement. Pure.

The server only trusts what the Play Developer API says about a purchase token
(purchases.subscriptionsv2), never what the app or a notification claims. Every rule here
works on that API response.
"""

import hashlib
import hmac
import uuid
from collections.abc import Mapping, Sequence
from dataclasses import dataclass
from datetime import UTC, datetime
from typing import Any

# subscriptionState values that keep access until the expiry time. A canceled subscription
# stays usable until the end of the period already paid; a grace period is Google's retry
# window for a failed renewal.
ENTITLED_STATES = frozenset(
    {
        "SUBSCRIPTION_STATE_ACTIVE",
        "SUBSCRIPTION_STATE_IN_GRACE_PERIOD",
        "SUBSCRIPTION_STATE_CANCELED",
    }
)
# Pending (not paid yet), on hold / paused (payment problem or paused by the learner),
# expired and abandoned pending purchases give no access.
KNOWN_STATES = ENTITLED_STATES | {
    "SUBSCRIPTION_STATE_PENDING",
    "SUBSCRIPTION_STATE_ON_HOLD",
    "SUBSCRIPTION_STATE_PAUSED",
    "SUBSCRIPTION_STATE_EXPIRED",
    "SUBSCRIPTION_STATE_PENDING_PURCHASE_CANCELED",
}
ACKNOWLEDGED = "ACKNOWLEDGEMENT_STATE_ACKNOWLEDGED"
PLAY_ACCOUNT_ID_LENGTH = 64  # Play allows up to 64 characters


def play_account_id(secret: str, user_id: uuid.UUID) -> str:
    """The obfuscated account id the app passes to Play at purchase time, so a purchase can
    only be attached to the account that made it. Not reversible without the server secret."""
    digest = hmac.new(secret.encode(), f"play:{user_id}".encode(), hashlib.sha256).hexdigest()
    return digest[:PLAY_ACCOUNT_ID_LENGTH]


def token_hash(purchase_token: str) -> str:
    """For logs and the audit table: purchase tokens are never written there in clear."""
    return hashlib.sha256(purchase_token.encode()).hexdigest()


@dataclass(frozen=True, slots=True)
class PlaySubscription:
    state: str
    product_id: str | None
    expires_at: datetime | None
    acknowledged: bool
    account_id: str | None  # obfuscatedExternalAccountId
    linked_purchase_token: str | None  # the purchase this one replaces (upgrade, resubscribe)
    test_purchase: bool


def _time(value: object) -> datetime | None:
    if not isinstance(value, str) or not value:
        return None
    try:
        parsed = datetime.fromisoformat(value.replace("Z", "+00:00"))
    except ValueError:
        return None
    return parsed if parsed.tzinfo else parsed.replace(tzinfo=UTC)


def parse_subscription(data: Mapping[str, Any], product_ids: Sequence[str]) -> PlaySubscription:
    """The parts of a SubscriptionPurchaseV2 we use. The line item of one of our products
    gives the product and expiry (the latest expiry if several)."""
    items = [
        item
        for item in data.get("lineItems") or []
        if isinstance(item, Mapping) and item.get("productId") in product_ids
    ]
    expiries = [e for e in (_time(i.get("expiryTime")) for i in items) if e is not None]
    accounts = data.get("externalAccountIdentifiers") or {}
    return PlaySubscription(
        state=str(data.get("subscriptionState") or ""),
        product_id=str(items[0]["productId"]) if items else None,
        expires_at=max(expiries) if expiries else None,
        acknowledged=data.get("acknowledgementState") == ACKNOWLEDGED,
        account_id=accounts.get("obfuscatedExternalAccountId")
        if isinstance(accounts, Mapping)
        else None,
        linked_purchase_token=data.get("linkedPurchaseToken") or None,
        test_purchase="testPurchase" in data,
    )


def problems(sub: PlaySubscription, *, expected_account_id: str) -> list[str]:
    """Why this purchase can't give this account Plus (empty: it can be recorded)."""
    found: list[str] = []
    if sub.product_id is None:
        found.append("not_our_product")
    if sub.state not in KNOWN_STATES:
        found.append("unknown_state")
    if sub.account_id != expected_account_id:
        found.append("other_account")  # bought from another account, or outside the app
    return found


def entitled_until(sub: PlaySubscription, now: datetime) -> datetime | None:
    """Until when Plus is on for this purchase; None when it gives no access now."""
    if sub.state not in ENTITLED_STATES or sub.expires_at is None:
        return None
    return sub.expires_at if sub.expires_at > now else None
