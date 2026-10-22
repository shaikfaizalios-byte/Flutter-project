"""PrepLoop Plus: one subscription row per account (the server is the only judge of it)."""

import uuid
from datetime import datetime

from sqlalchemy import CheckConstraint, DateTime, ForeignKey, String, func
from sqlalchemy.orm import Mapped, mapped_column

from app.database.base import Base


class Subscription(Base):
    __tablename__ = "subscriptions"
    __table_args__ = (
        CheckConstraint("plan IN ('plus')", name="plan_valid"),
        # test: self-started in a development server; operator: granted with the CLI;
        # play / web: verified store purchases (not built yet).
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
