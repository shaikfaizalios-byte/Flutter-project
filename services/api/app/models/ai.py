"""AI-generated drafts and the audit log of AI calls (Phase 9)."""

import uuid
from datetime import datetime
from enum import StrEnum

from sqlalchemy import CheckConstraint, DateTime, ForeignKey, Index, Integer, String, Text, func
from sqlalchemy.orm import Mapped, mapped_column

from app.database.base import Base


class DraftStatus(StrEnum):
    DRAFT = "draft"  # waiting for review; shown only in review screens, labelled
    APPROVED = "approved"  # shown to learners, still labelled "AI-generated"
    REJECTED = "rejected"


class AIExplanation(Base):
    """An AI explanation for a verified source question that has none. Kept apart from
    ``questions.explanation`` so source content and AI content never mix."""

    __tablename__ = "ai_explanations"
    __table_args__ = (
        CheckConstraint("status IN ('draft', 'approved', 'rejected')", name="status_valid"),
        CheckConstraint("language IN ('en', 'hi')", name="language_supported"),
        Index("ix_ai_explanations_question", "question_id", "created_at"),
    )

    id: Mapped[uuid.UUID] = mapped_column(primary_key=True, default=uuid.uuid4)
    question_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("questions.id", ondelete="CASCADE"))
    text: Mapped[str] = mapped_column(Text)
    language: Mapped[str] = mapped_column(String(8))
    # The model's own doubt about the given answer; reviewers see it.
    model_confident: Mapped[bool] = mapped_column(default=True)
    provider: Mapped[str] = mapped_column(String(32))
    model: Mapped[str] = mapped_column(String(64))
    prompt_version: Mapped[str] = mapped_column(String(32))
    status: Mapped[str] = mapped_column(String(12), default=DraftStatus.DRAFT)
    edited: Mapped[bool] = mapped_column(default=False)
    reviewed_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())


class AIGeneration(Base):
    """One AI call: task, model, prompt version, outcome and token usage (cost auditing).
    Never stores prompt or output text."""

    __tablename__ = "ai_generations"
    __table_args__ = (
        CheckConstraint(
            "task IN ('explanation', 'questions', 'topic', 'taxonomy', 'quick_answer', "
            "'rag_answer', 'paper_read', 'topic_lesson', 'topic_quiz', 'answer_check')",
            name="task_valid",
        ),
        CheckConstraint("outcome IN ('ok', 'partial', 'invalid', 'error')", name="outcome_valid"),
        Index("ix_ai_generations_created", "created_at"),
    )

    id: Mapped[uuid.UUID] = mapped_column(primary_key=True, default=uuid.uuid4)
    # Owner (Phase 10). Null only for data created before accounts existed, until the first
    # account claims it; every query filters by the signed-in owner.
    owner_id: Mapped[uuid.UUID | None] = mapped_column(
        ForeignKey("users.id", ondelete="CASCADE"), index=True
    )
    task: Mapped[str] = mapped_column(String(16))
    provider: Mapped[str] = mapped_column(String(32))
    model: Mapped[str] = mapped_column(String(64))
    prompt_version: Mapped[str] = mapped_column(String(32))
    outcome: Mapped[str] = mapped_column(String(12))
    # Short reason codes only (e.g. "timeout", "bad_answer x2").
    detail: Mapped[str] = mapped_column(String(300), default="", server_default="")
    input_tokens: Mapped[int] = mapped_column(Integer, default=0)
    output_tokens: Mapped[int] = mapped_column(Integer, default=0)
    items_created: Mapped[int] = mapped_column(Integer, default=0)
    items_rejected: Mapped[int] = mapped_column(Integer, default=0)
    question_id: Mapped[uuid.UUID | None] = mapped_column(
        ForeignKey("questions.id", ondelete="SET NULL")
    )
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())
