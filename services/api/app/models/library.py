"""The curated question library: PrepLoop's own content, kept apart from learners' imports.

An entry sits on a question and says where it came from, who may show it, who wrote and checked it,
and how it has changed. See app/services/library_service.py.
"""

import uuid
from datetime import datetime
from typing import Any

from sqlalchemy import (
    BigInteger,
    CheckConstraint,
    DateTime,
    ForeignKey,
    Integer,
    Sequence,
    String,
    func,
)
from sqlalchemy.dialects.postgresql import JSONB
from sqlalchemy.orm import Mapped, mapped_column

from app.database.base import Base

LIBRARY_SEQ = Sequence("library_seq")


class LibraryEntry(Base):
    __tablename__ = "library_entries"
    __table_args__ = (
        CheckConstraint(
            "source_type IN ('official_pyq', 'original_expert', 'original_ai_verified')",
            name="source_type_valid",
        ),
        CheckConstraint(
            "rights_status IN ('licensed', 'owned', 'pending')", name="rights_status_valid"
        ),
        CheckConstraint(
            "status IN ('draft', 'solved', 'approved', 'withdrawn')", name="status_valid"
        ),
        CheckConstraint("difficulty IN ('easy', 'medium', 'hard')", name="difficulty_valid"),
    )

    question_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("questions.id", ondelete="CASCADE"), primary_key=True
    )
    source_type: Mapped[str] = mapped_column(String(20))
    rights_status: Mapped[str] = mapped_column(String(8))
    rights_note: Mapped[str | None] = mapped_column(String(500))
    # Names stay after an account is gone; the links are what stop someone checking their own work.
    author_id: Mapped[uuid.UUID | None] = mapped_column(ForeignKey("users.id", ondelete="SET NULL"))
    author_name: Mapped[str] = mapped_column(String(200))
    status: Mapped[str] = mapped_column(String(9))
    solved_by_id: Mapped[uuid.UUID | None] = mapped_column(
        ForeignKey("users.id", ondelete="SET NULL")
    )
    solved_by_name: Mapped[str | None] = mapped_column(String(200))
    approved_by_id: Mapped[uuid.UUID | None] = mapped_column(
        ForeignKey("users.id", ondelete="SET NULL")
    )
    approved_by_name: Mapped[str | None] = mapped_column(String(200))
    version: Mapped[int] = mapped_column(Integer, default=1, server_default="1")
    exam_year: Mapped[int | None] = mapped_column(Integer)
    # The level it was given, and the level its real attempts show once there are enough.
    difficulty: Mapped[str] = mapped_column(String(6))
    observed_difficulty: Mapped[str | None] = mapped_column(String(6))
    attempts: Mapped[int] = mapped_column(Integer, default=0, server_default="0")
    correct_count: Mapped[int] = mapped_column(Integer, default=0, server_default="0")
    median_ms: Mapped[int | None] = mapped_column(Integer)
    calibrated_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    # Rises with every change a device must pick up: what a pack's delta is measured by.
    seq: Mapped[int] = mapped_column(
        BigInteger, LIBRARY_SEQ, server_default=LIBRARY_SEQ.next_value(), index=True
    )
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())


class LibraryVersion(Base):
    """A question as it stood at one version (append-only)."""

    __tablename__ = "library_versions"

    question_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("library_entries.question_id", ondelete="CASCADE"), primary_key=True
    )
    version: Mapped[int] = mapped_column(Integer, primary_key=True)
    snapshot: Mapped[dict[str, Any]] = mapped_column(JSONB)
    changed_by: Mapped[str] = mapped_column(String(200))
    reason: Mapped[str] = mapped_column(String(500))
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())
