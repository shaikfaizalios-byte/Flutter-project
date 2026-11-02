"""PrepLoop Plus: one subscription row per account (the server is the only judge of it)."""

import uuid
from datetime import datetime

from sqlalchemy import Boolean, CheckConstraint, DateTime, ForeignKey, Index, Integer, String, func
from sqlalchemy.orm import Mapped, mapped_column

from app.database.base import Base


class Subscription(Base):
    __tablename__ = "subscriptions"
    __table_args__ = (
        CheckConstraint("plan IN ('plus')", name="plan_valid"),
        # test: self-started in a development server; operator: granted with the CLI;
        # play: a Google Play purchase verified with the Play Developer API (see
        # play_purchases); web: not built yet.
        CheckConstraint("source IN ('test', 'operator', 'play', 'web')", name="source_valid"),
    )

    owner_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("users.id", ondelete="CASCADE"), primary_key=True
    )
    plan: Mapped[str] = mapped_column(String(16), default="plus")
    source: Mapped[str] = mapped_column(String(16))
    active_until: Mapped[datetime] = mapped_column(DateTime(timezone=True))
    note: Mapped[str | None] = mapped_column(String(200))
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), onupdate=func.now()
    )


class PlayPurchase(Base):
    """A Google Play subscription purchase, as last read from the Play Developer API.

    The purchase token is the identifier Google gives the app; one token belongs to exactly
    one account (the one whose obfuscated id was passed to Play at purchase time).
    """

    __tablename__ = "play_purchases"

    id: Mapped[uuid.UUID] = mapped_column(primary_key=True, default=uuid.uuid4)
    owner_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("users.id", ondelete="CASCADE"), index=True
    )
    purchase_token: Mapped[str] = mapped_column(String(512), unique=True)
    product_id: Mapped[str] = mapped_column(String(100))
    state: Mapped[str] = mapped_column(String(48))  # subscriptionState from Google
    expires_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    acknowledged: Mapped[bool] = mapped_column(Boolean, default=False)
    test_purchase: Mapped[bool] = mapped_column(Boolean, default=False)
    # Set when a newer purchase (upgrade, resubscribe) replaced this one.
    replaced_by_id: Mapped[uuid.UUID | None] = mapped_column(
        ForeignKey("play_purchases.id", ondelete="SET NULL")
    )
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), onupdate=func.now()
    )


class BillingEvent(Base):
    """Audit of every purchase check and store notification, without tokens or content.

    `event_key` makes handling idempotent (a Pub/Sub message delivered twice is applied once).
    Kept after account deletion with the account link cleared.
    """

    __tablename__ = "billing_events"
    __table_args__ = (
        CheckConstraint("provider IN ('play')", name="provider_valid"),
        CheckConstraint("kind IN ('verify', 'subscription', 'voided', 'test')", name="kind_valid"),
        CheckConstraint(
            "outcome IN ('applied', 'ignored', 'refused', 'unknown_token', 'error')",
            name="outcome_valid",
        ),
        Index("ix_billing_events_received", "received_at"),
    )

    id: Mapped[uuid.UUID] = mapped_column(primary_key=True, default=uuid.uuid4)
    provider: Mapped[str] = mapped_column(String(8), default="play")
    event_key: Mapped[str] = mapped_column(String(160), unique=True)
    kind: Mapped[str] = mapped_column(String(16))
    notification_type: Mapped[int | None] = mapped_column(Integer)
    token_hash: Mapped[str | None] = mapped_column(String(64), index=True)
    owner_id: Mapped[uuid.UUID | None] = mapped_column(
        ForeignKey("users.id", ondelete="SET NULL"), index=True
    )
    outcome: Mapped[str] = mapped_column(String(16))
    detail: Mapped[str] = mapped_column(String(200), default="", server_default="")
    received_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now()
    )
