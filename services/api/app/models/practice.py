import uuid
from datetime import datetime
from enum import StrEnum
from typing import Any

from sqlalchemy import (
    BigInteger,
    Boolean,
    CheckConstraint,
    DateTime,
    Float,
    ForeignKey,
    Index,
    Integer,
    String,
    func,
)
from sqlalchemy.dialects.postgresql import ARRAY, JSONB
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.database.base import Base


class SessionMode(StrEnum):
    PRACTICE = "practice"  # untimed, immediate feedback, 1 point per correct answer
    MOCK = "mock"  # timed, marking from a verified exam format, feedback after submit
    # The starter check for a new learner: untimed, 1 point per correct answer, feedback after
    # submit; only shared-bank questions whose rights allow it (app/services/diagnostic.py).
    DIAGNOSTIC = "diagnostic"


class SessionStatus(StrEnum):
    ACTIVE = "active"
    SUBMITTED = "submitted"


class PracticeSession(Base):
    __tablename__ = "practice_sessions"
    __table_args__ = (
        # diagnostic: the starter check for a new learner (no timer, results after submitting).
        CheckConstraint("mode IN ('practice', 'mock', 'diagnostic')", name="mode_valid"),
        CheckConstraint("status IN ('active', 'submitted')", name="status_valid"),
        CheckConstraint(
            "mode <> 'mock' OR (exam_format_id IS NOT NULL AND deadline_at IS NOT NULL)",
            name="mock_has_format_and_deadline",
        ),
        Index("ix_practice_sessions_started", "started_at"),
    )

    id: Mapped[uuid.UUID] = mapped_column(primary_key=True, default=uuid.uuid4)
    # Owner (Phase 10). Null only for data created before accounts existed, until the first
    # account claims it; every query filters by the signed-in owner.
    owner_id: Mapped[uuid.UUID | None] = mapped_column(
        ForeignKey("users.id", ondelete="CASCADE"), index=True
    )
    mode: Mapped[str] = mapped_column(String(16))
    exam_code: Mapped[str | None] = mapped_column(
        String(32), ForeignKey("exams.code", ondelete="RESTRICT")
    )
    exam_format_id: Mapped[uuid.UUID | None] = mapped_column(
        ForeignKey("exam_formats.id", ondelete="RESTRICT")
    )
    # What the learner asked for (subject/topic/section filters, include_unverified, count).
    selection: Mapped[dict[str, Any]] = mapped_column(JSONB, default=dict)
    status: Mapped[str] = mapped_column(String(16), default=SessionStatus.ACTIVE)
    # All times are server times: the client cannot move the timer.
    started_at: Mapped[datetime] = mapped_column(DateTime(timezone=True))
    deadline_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    submitted_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    submit_reason: Mapped[str | None] = mapped_column(String(16))  # "user" | "time_up" | "offline"
    # Filled at submission (see app/domain/scoring.py).
    score: Mapped[float | None] = mapped_column(Float)
    max_score: Mapped[float | None] = mapped_column(Float)
    result: Mapped[dict[str, Any] | None] = mapped_column(JSONB)
    # Sectionally timed mocks (app/domain/sections.py): the plan is in selection["sections"];
    # these say which section is open (len(plan) = all closed) and since when.
    current_section: Mapped[int | None] = mapped_column(Integer)
    section_started_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())

    items: Mapped[list["SessionItem"]] = relationship(
        cascade="all, delete-orphan", passive_deletes=True, order_by="SessionItem.position"
    )
    answers: Mapped[list["SessionAnswer"]] = relationship(
        cascade="all, delete-orphan", passive_deletes=True
    )


class SessionItem(Base):
    """A question placed in a session, with a snapshot of what analytics and scoring need
    (so history stays meaningful even if the question is later edited or deleted)."""

    __tablename__ = "session_items"

    session_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("practice_sessions.id", ondelete="CASCADE"), primary_key=True
    )
    position: Mapped[int] = mapped_column(Integer, primary_key=True)  # 1-based
    question_id: Mapped[uuid.UUID | None] = mapped_column(
        ForeignKey("questions.id", ondelete="SET NULL"), index=True
    )
    section: Mapped[str | None] = mapped_column(String(120))
    subject: Mapped[str | None] = mapped_column(String(100))
    topic_id: Mapped[uuid.UUID | None] = mapped_column(ForeignKey("topics.id", ondelete="SET NULL"))
    correct_position: Mapped[int | None] = mapped_column(Integer)  # None for typed answers
    answer_type: Mapped[str] = mapped_column(String(8), default="choice", server_default="choice")
    typed_answer: Mapped[str | None] = mapped_column(String(100))  # expected, snapshotted
    format: Mapped[str] = mapped_column(
        String(20), default="single_correct", server_default="single_correct"
    )
    answer_spec: Mapped[dict[str, Any] | None] = mapped_column(JSONB(none_as_null=True))
    option_count: Mapped[int] = mapped_column(Integer)
    marks_correct: Mapped[float] = mapped_column(Float)
    marks_wrong: Mapped[float] = mapped_column(Float)  # deducted for a wrong answer (>= 0)
    marks_unanswered: Mapped[float] = mapped_column(Float, default=0, server_default="0")
    # Partial credit from the format, snapshotted so a later change never touches this attempt.
    partial_rule: Mapped[dict[str, Any] | None] = mapped_column(JSONB(none_as_null=True))
    question_verified: Mapped[bool] = mapped_column(Boolean)
    # How the key stood. A final key updates these and re-marks the session.
    key_outcome: Mapped[str] = mapped_column(String(7), default="one", server_default="one")
    accepted_positions: Mapped[list[int] | None] = mapped_column(ARRAY(Integer))
    key_changed: Mapped[bool] = mapped_column(Boolean, default=False, server_default="false")


class SessionAnswer(Base):
    """The learner's current answer for one item. ``client_seq`` makes replays idempotent
    and order-safe: an update is applied only if its sequence number is newer."""

    __tablename__ = "session_answers"

    session_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("practice_sessions.id", ondelete="CASCADE"), primary_key=True
    )
    position: Mapped[int] = mapped_column(Integer, primary_key=True)
    question_id: Mapped[uuid.UUID | None] = mapped_column(
        ForeignKey("questions.id", ondelete="SET NULL"), index=True
    )
    selected_position: Mapped[int | None] = mapped_column(Integer)  # null = cleared
    typed_answer: Mapped[str | None] = mapped_column(String(100))  # what the learner typed
    # The answer of a format that takes neither one option nor a typed text.
    response: Mapped[dict[str, Any] | None] = mapped_column(JSONB(none_as_null=True))
    is_correct: Mapped[bool | None] = mapped_column(Boolean)
    client_seq: Mapped[int] = mapped_column(BigInteger)
    time_spent_ms: Mapped[int | None] = mapped_column(Integer)
    answered_at: Mapped[datetime] = mapped_column(DateTime(timezone=True))


class Bookmark(Base):
    __tablename__ = "bookmarks"

    question_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("questions.id", ondelete="CASCADE"), primary_key=True
    )
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())
