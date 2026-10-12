import uuid
from datetime import datetime

from sqlalchemy import CheckConstraint, DateTime, ForeignKey, Index, String, Text, func
from sqlalchemy.dialects.postgresql import ARRAY
from sqlalchemy.orm import Mapped, mapped_column

from app.database.base import Base

SUPPORTED_LANGUAGES = ("en", "hi")


class Concept(Base):
    """A unit of study material the user organises (notes on a topic).

    Ownership: there are no accounts yet (Phase 10). An ``owner_id`` column and
    ownership checks in the repository are added together with authentication.
    """

    __tablename__ = "concepts"
    __table_args__ = (
        CheckConstraint("language IN ('en', 'hi')", name="language_supported"),
        CheckConstraint("char_length(btrim(title)) > 0", name="title_not_blank"),
        Index("ix_concepts_exam_archived", "exam_code", "archived_at"),
        Index("ix_concepts_tags", "tags", postgresql_using="gin"),
    )

    id: Mapped[uuid.UUID] = mapped_column(primary_key=True, default=uuid.uuid4)
    exam_code: Mapped[str] = mapped_column(
        String(32), ForeignKey("exams.code", ondelete="RESTRICT")
    )
    title: Mapped[str] = mapped_column(String(200))
    notes: Mapped[str] = mapped_column(Text, default="", server_default="")
    subject: Mapped[str] = mapped_column(String(100))
    topic: Mapped[str] = mapped_column(String(100))
    subtopic: Mapped[str | None] = mapped_column(String(100))
    language: Mapped[str] = mapped_column(String(8))
    tags: Mapped[list[str]] = mapped_column(ARRAY(String(50)), default=list, server_default="{}")
    source_reference: Mapped[str | None] = mapped_column(String(500))
    archived_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), onupdate=func.now()
    )
