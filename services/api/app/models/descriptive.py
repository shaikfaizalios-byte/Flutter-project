"""Descriptive practice: written answers marked against a rubric by AI.

Questions stay here, never in ``questions``, so they can't reach any repeat count.
"""

import uuid
from datetime import datetime
from typing import Any

from sqlalchemy import (
    Boolean,
    CheckConstraint,
    DateTime,
    Float,
    ForeignKey,
    Integer,
    String,
    Text,
    func,
)
from sqlalchemy.dialects.postgresql import JSONB
from sqlalchemy.orm import Mapped, mapped_column

from app.database.base import Base


class DescriptiveSession(Base):
    __tablename__ = "descriptive_sessions"
    __table_args__ = (CheckConstraint("source IN ('ai', 'papers')", name="source_valid"),)

    id: Mapped[uuid.UUID] = mapped_column(primary_key=True, default=uuid.uuid4)
    owner_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("users.id", ondelete="CASCADE"), index=True
    )
    exam_code: Mapped[str] = mapped_column(ForeignKey("exams.code", ondelete="CASCADE"))
    topic_id: Mapped[uuid.UUID | None] = mapped_column(ForeignKey("topics.id", ondelete="SET NULL"))
    # Kept so history reads the same if the topic is later removed.
    topic_name: Mapped[str] = mapped_column(String(100))
    subject: Mapped[str] = mapped_column(String(100))
    language: Mapped[str] = mapped_column(String(8), ForeignKey("languages.code"))
    # ai: written for this session; papers: the learner's own reviewed written questions.
    source: Mapped[str] = mapped_column(String(6), default="ai", server_default="ai")
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())


class DescriptiveStep(Base):
    """One level: planned first, then written with its rubric, then answered and marked."""

    __tablename__ = "descriptive_steps"
    __table_args__ = (
        CheckConstraint(
            "answer_source IS NULL OR answer_source IN ('typed', 'photo')",
            name="answer_source_valid",
        ),
    )

    session_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("descriptive_sessions.id", ondelete="CASCADE"), primary_key=True
    )
    step: Mapped[int] = mapped_column(Integer, primary_key=True)
    level: Mapped[str] = mapped_column(String(20))
    marks: Mapped[float] = mapped_column(Float)
    # PrepLoop's suggested length, not an exam rule.
    word_limit: Mapped[int] = mapped_column(Integer)
    # Set for a real question from the learner's papers; its text is kept in ``stem`` so history
    # reads the same if the paper is later removed.
    question_id: Mapped[uuid.UUID | None] = mapped_column(
        ForeignKey("questions.id", ondelete="SET NULL")
    )
    paper_label: Mapped[str | None] = mapped_column(String(300))
    # The model answer is the one printed in the paper, not written by AI.
    answer_from_paper: Mapped[bool] = mapped_column(Boolean, default=False, server_default="false")
    # The question: null until written. A paper question has it from the start.
    stem: Mapped[str | None] = mapped_column(Text)
    rubric: Mapped[list[dict[str, Any]] | None] = mapped_column(JSONB)
    model_answer: Mapped[str | None] = mapped_column(Text)
    # The attempt.
    answer_text: Mapped[str | None] = mapped_column(Text)
    answer_source: Mapped[str | None] = mapped_column(String(5))
    word_count: Mapped[int | None] = mapped_column(Integer)
    marking: Mapped[dict[str, Any] | None] = mapped_column(JSONB)
    marks_awarded: Mapped[float | None] = mapped_column(Float)
    # Set only when the markings disagreed: the lowest and highest of them.
    marks_low: Mapped[float | None] = mapped_column(Float)
    marks_high: Mapped[float | None] = mapped_column(Float)
    runs: Mapped[int | None] = mapped_column(Integer)
    answered_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
