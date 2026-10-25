import uuid
from datetime import date, datetime
from enum import StrEnum

from sqlalchemy import (
    CheckConstraint,
    Date,
    DateTime,
    Float,
    ForeignKey,
    Index,
    Integer,
    String,
    Text,
    func,
    text,
)
from sqlalchemy.dialects.postgresql import ARRAY
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.database.base import Base


class DocumentStatus(StrEnum):
    QUEUED = "queued"
    PROCESSING = "processing"
    COMPLETED = "completed"
    FAILED = "failed"


class ExtractionMethod(StrEnum):
    TEXT = "text"  # embedded text layer
    OCR = "ocr"  # Tesseract on a rendered page image
    NONE = "none"  # nothing reliable could be extracted


class Document(Base):
    """An uploaded PDF (question paper or study material) and its processing state.

    The original file lives in DocumentStorage under ``storage_key``; ``original_filename``
    is display metadata only and is never used to build a path.
    """

    __tablename__ = "documents"
    __table_args__ = (
        CheckConstraint(
            "status IN ('queued', 'processing', 'completed', 'failed')", name="status_valid"
        ),
        CheckConstraint("language IN ('en', 'hi')", name="language_supported"),
        CheckConstraint(
            "ai_read_status IN ('none', 'queued', 'running', 'completed', 'failed')",
            name="ai_read_status_valid",
        ),
        CheckConstraint(
            "paper_date_status IN ('unknown', 'suggested', 'confirmed')",
            name="paper_date_status_valid",
        ),
        CheckConstraint(
            "exam_shift IS NULL OR exam_shift BETWEEN 1 AND 9", name="exam_shift_range"
        ),
        CheckConstraint(
            "exam_date IS NULL OR (exam_year IS NOT NULL"
            " AND exam_year = EXTRACT(YEAR FROM exam_date))",
            name="exam_date_matches_year",
        ),
        # A paper in the shared bank must say on what basis it may be shared (and where from).
        CheckConstraint(
            "shared_at IS NULL OR (length(trim(shared_rights_basis)) > 0"
            " AND length(trim(shared_source)) > 0)",
            name="shared_needs_rights",
        ),
        Index("ix_documents_status_created", "status", "created_at"),
        Index("ix_documents_shared", "id", postgresql_where=text("shared_at IS NOT NULL")),
    )

    id: Mapped[uuid.UUID] = mapped_column(primary_key=True, default=uuid.uuid4)
    # Owner (Phase 10). Null only for data created before accounts existed, until the first
    # account claims it; every query filters by the signed-in owner.
    owner_id: Mapped[uuid.UUID | None] = mapped_column(
        ForeignKey("users.id", ondelete="CASCADE"), index=True
    )
    exam_code: Mapped[str] = mapped_column(
        String(32), ForeignKey("exams.code", ondelete="RESTRICT")
    )
    language: Mapped[str] = mapped_column(String(8))
    original_filename: Mapped[str] = mapped_column(String(255))
    size_bytes: Mapped[int] = mapped_column(Integer)
    sha256: Mapped[str] = mapped_column(String(64), index=True)
    storage_key: Mapped[str] = mapped_column(String(255), unique=True)
    page_count: Mapped[int] = mapped_column(Integer)
    pages_processed: Mapped[int] = mapped_column(Integer, default=0, server_default="0")
    needs_review_count: Mapped[int] = mapped_column(Integer, default=0, server_default="0")
    status: Mapped[str] = mapped_column(String(16), default=DocumentStatus.QUEUED)
    # "text", "ocr", "mixed" or "none" once processing finishes.
    extraction_summary: Mapped[str | None] = mapped_column(String(16))
    error_code: Mapped[str | None] = mapped_column(String(64))
    # Optional verified paper format (enables question-count checks during segmentation).
    exam_format_id: Mapped[uuid.UUID | None] = mapped_column(
        ForeignKey("exam_formats.id", ondelete="SET NULL")
    )
    # Question segmentation (Phase 5): pending | completed | failed.
    segmentation_status: Mapped[str] = mapped_column(
        String(16), default="pending", server_default="pending"
    )
    questions_found: Mapped[int] = mapped_column(Integer, default=0, server_default="0")
    # Reading the questions with AI when the rules can't (asked by the learner; run by the
    # worker): none | queued | running | completed | failed.
    ai_read_status: Mapped[str] = mapped_column(String(10), default="none", server_default="none")
    ai_read_started_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    ai_read_pages_done: Mapped[int] = mapped_column(Integer, default=0, server_default="0")
    ai_read_error: Mapped[str | None] = mapped_column(String(40))
    # When the paper was held. Suggested from the file name / first page, confirmed by the
    # reviewer; year trends use confirmed values only.
    exam_year: Mapped[int | None] = mapped_column(Integer)
    exam_date: Mapped[date | None] = mapped_column(Date)
    exam_shift: Mapped[int | None] = mapped_column(Integer)
    paper_date_status: Mapped[str] = mapped_column(
        String(12), default="unknown", server_default="unknown"
    )
    paper_date_reason: Mapped[str | None] = mapped_column(String(200))
    segmented_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    # Shared bank: when set, this paper's VERIFIED source questions are visible read-only to
    # every learner (practice, mocks, repeats). Published by the operator with
    # `python -m app.cli.shared_bank`, only with a recorded rights basis and source.
    shared_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    shared_rights_basis: Mapped[str | None] = mapped_column(String(500))
    shared_source: Mapped[str | None] = mapped_column(String(500))
    attempts: Mapped[int] = mapped_column(Integer, default=0, server_default="0")
    lease_expires_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    processing_started_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    processing_finished_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), onupdate=func.now()
    )

    pages: Mapped[list["DocumentPage"]] = relationship(
        back_populates="document",
        cascade="all, delete-orphan",
        passive_deletes=True,
        order_by="DocumentPage.page_number",
    )


class DocumentPage(Base):
    """Extraction result for one page. ``page_number`` is 1-based, matching the source PDF."""

    __tablename__ = "document_pages"
    __table_args__ = (
        CheckConstraint("method IN ('text', 'ocr', 'none')", name="method_valid"),
        CheckConstraint("page_number >= 1", name="page_number_positive"),
    )

    document_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("documents.id", ondelete="CASCADE"), primary_key=True
    )
    page_number: Mapped[int] = mapped_column(Integer, primary_key=True)
    method: Mapped[str] = mapped_column(String(8))
    text: Mapped[str] = mapped_column(Text, default="", server_default="")
    char_count: Mapped[int] = mapped_column(Integer, default=0, server_default="0")
    # Mean Tesseract word confidence (0-100) for OCR pages; null for text-layer pages.
    ocr_confidence: Mapped[float | None] = mapped_column(Float)
    needs_review: Mapped[bool] = mapped_column(default=False, server_default="false")
    review_reasons: Mapped[list[str]] = mapped_column(
        ARRAY(String(40)), default=list, server_default="{}"
    )
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())

    document: Mapped[Document] = relationship(back_populates="pages")
