"""Proposed models and AI concept hints. Both sit apart from the reviewed counts."""

import uuid
from datetime import datetime

from sqlalchemy import (
    CheckConstraint,
    DateTime,
    ForeignKey,
    Integer,
    String,
    UniqueConstraint,
    func,
)
from sqlalchemy.dialects.postgresql import JSONB
from sqlalchemy.orm import Mapped, mapped_column

from app.database.base import Base


class ModelProposal(Base):
    """A cluster of alike questions. It becomes a model only when a subject reviewer approves it."""

    __tablename__ = "model_proposals"
    __table_args__ = (
        CheckConstraint("status IN ('proposed', 'approved', 'rejected')", name="status_valid"),
        UniqueConstraint("topic_id", "signature"),
    )

    id: Mapped[uuid.UUID] = mapped_column(primary_key=True, default=uuid.uuid4)
    exam_code: Mapped[str] = mapped_column(ForeignKey("exams.code"), index=True)
    topic_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("topics.id", ondelete="CASCADE"))
    signature: Mapped[str] = mapped_column(String(64))  # the same cluster isn't proposed twice
    question_ids: Mapped[list[str]] = mapped_column(JSONB)
    shifts: Mapped[int] = mapped_column(Integer)
    status: Mapped[str] = mapped_column(String(8), default="proposed", server_default="proposed")
    reviewed_by: Mapped[str | None] = mapped_column(String(320))
    reviewed_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    review_note: Mapped[str | None] = mapped_column(String(500))
    pattern_id: Mapped[uuid.UUID | None] = mapped_column(
        ForeignKey("question_patterns.id", ondelete="SET NULL")
    )
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())


class ConceptHint(Base):
    """Questions an AI read as testing one concept. A hint: never counted, never a model."""

    __tablename__ = "concept_hints"

    id: Mapped[uuid.UUID] = mapped_column(primary_key=True, default=uuid.uuid4)
    exam_code: Mapped[str] = mapped_column(ForeignKey("exams.code"), index=True)
    topic_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("topics.id", ondelete="CASCADE"))
    label: Mapped[str] = mapped_column(String(200))
    question_ids: Mapped[list[str]] = mapped_column(JSONB)
    model: Mapped[str] = mapped_column(String(64))
    prompt_version: Mapped[str] = mapped_column(String(32))
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())
