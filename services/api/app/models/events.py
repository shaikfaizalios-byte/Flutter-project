"""Attempt events: a record of each answer once it is final, and of each re-marking."""

import uuid
from datetime import datetime

from sqlalchemy import (
    BigInteger,
    Boolean,
    CheckConstraint,
    DateTime,
    ForeignKey,
    Identity,
    Integer,
    String,
    func,
)
from sqlalchemy.orm import Mapped, mapped_column

from app.database.base import Base


class AttemptEvent(Base):
    """``final``: an answer that can no longer change (a practice answer, or a test's answers once
    submitted). ``remarked``: a key change marked it again; ``was_correct`` is what it was."""

    __tablename__ = "attempt_events"
    __table_args__ = (CheckConstraint("kind IN ('final', 'remarked')", name="kind_valid"),)

    id: Mapped[int] = mapped_column(BigInteger, Identity(always=True), primary_key=True)
    owner_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("users.id", ondelete="CASCADE"), index=True
    )
    session_id: Mapped[uuid.UUID] = mapped_column()
    position: Mapped[int] = mapped_column(Integer)
    question_id: Mapped[uuid.UUID | None] = mapped_column(index=True)
    exam_code: Mapped[str | None] = mapped_column(String(32))
    topic_id: Mapped[uuid.UUID | None] = mapped_column()
    kind: Mapped[str] = mapped_column(String(8))
    correct: Mapped[bool | None] = mapped_column(Boolean)
    was_correct: Mapped[bool | None] = mapped_column(Boolean)
    time_ms: Mapped[int | None] = mapped_column(Integer)
    occurred_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now()
    )


class JobCursor(Base):
    """Where an incremental job stopped: the last event it read."""

    __tablename__ = "job_cursors"

    name: Mapped[str] = mapped_column(String(40), primary_key=True)
    last_id: Mapped[int] = mapped_column(BigInteger)
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), onupdate=func.now()
    )
