"""Suggestions learners send from the app (features to add, remove or change)."""

import uuid
from datetime import datetime

from sqlalchemy import CheckConstraint, DateTime, ForeignKey, Index, String, Text, func
from sqlalchemy.orm import Mapped, mapped_column

from app.database.base import Base


class Suggestion(Base):
    __tablename__ = "suggestions"
    __table_args__ = (
        CheckConstraint("kind IN ('add', 'remove', 'change', 'other')", name="kind_valid"),
        CheckConstraint(
            "status IN ('new', 'read', 'planned', 'done', 'declined')", name="status_valid"
        ),
        CheckConstraint("length(trim(text)) > 0", name="text_present"),
        Index("ix_suggestions_owner_created", "owner_id", "created_at"),
    )

    id: Mapped[uuid.UUID] = mapped_column(primary_key=True, default=uuid.uuid4)
    owner_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"))
    kind: Mapped[str] = mapped_column(String(8))
    text: Mapped[str] = mapped_column(Text)
    # Set by the operator (CLI); shown to the learner who sent it.
    status: Mapped[str] = mapped_column(String(10), default="new", server_default="new")
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())
