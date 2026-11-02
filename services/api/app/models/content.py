"""Content governance (global Phase 7): rights of shared content, reports, and an audit log of
operator decisions. See docs/shared-bank.md."""

import uuid
from datetime import date, datetime

from sqlalchemy import CheckConstraint, Date, DateTime, ForeignKey, Index, String, Text, func
from sqlalchemy.dialects.postgresql import ARRAY
from sqlalchemy.orm import Mapped, mapped_column

from app.database.base import Base


class ContentRights(Base):
    """Why PrepLoop may share a paper, and for what. Every shared paper has one; uploading a
    paper never creates one (private processing is not permission to share)."""

    __tablename__ = "content_rights"
    __table_args__ = (
        CheckConstraint(
            "permitted_uses <@ ARRAY['practice', 'diagnostic']::varchar[]"
            " AND cardinality(permitted_uses) > 0",
            name="permitted_uses_valid",
        ),
        CheckConstraint("length(trim(basis)) > 0", name="basis_present"),
        CheckConstraint("length(trim(decided_by)) > 0", name="decided_by_present"),
    )

    document_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("documents.id", ondelete="CASCADE"), primary_key=True
    )
    rights_holder: Mapped[str | None] = mapped_column(String(200))  # when known
    basis: Mapped[str] = mapped_column(String(500))
    # practice: shared-bank practice and mocks; diagnostic: the starter check for new learners.
    permitted_uses: Mapped[list[str]] = mapped_column(ARRAY(String(12)))
    territory: Mapped[str] = mapped_column(String(200))
    attribution: Mapped[str | None] = mapped_column(String(300))
    review_by: Mapped[date | None] = mapped_column(Date)
    decided_by: Mapped[str] = mapped_column(String(100))
    decided_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())


class ContentReport(Base):
    """A learner reports shared content: a rights problem, an error, or something else."""

    __tablename__ = "content_reports"
    __table_args__ = (
        CheckConstraint("kind IN ('rights', 'error', 'other')", name="kind_valid"),
        CheckConstraint("status IN ('open', 'upheld', 'dismissed')", name="status_valid"),
        CheckConstraint("length(trim(text)) > 0", name="text_present"),
        Index("ix_content_reports_status_created", "status", "created_at"),
    )

    id: Mapped[uuid.UUID] = mapped_column(primary_key=True, default=uuid.uuid4)
    owner_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("users.id", ondelete="CASCADE"), index=True
    )
    document_id: Mapped[uuid.UUID | None] = mapped_column(
        ForeignKey("documents.id", ondelete="SET NULL"), index=True
    )
    question_id: Mapped[uuid.UUID | None] = mapped_column(
        ForeignKey("questions.id", ondelete="SET NULL")
    )
    kind: Mapped[str] = mapped_column(String(8))
    text: Mapped[str] = mapped_column(Text)
    status: Mapped[str] = mapped_column(String(10), default="open", server_default="open")
    resolution: Mapped[str | None] = mapped_column(String(500))
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())
    resolved_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))


class AuditEvent(Base):
    """An operator decision about content or catalog data (publish, take down, resolve a
    report, publish or retire an exam format). Never holds content; kept after the target
    is deleted."""

    __tablename__ = "audit_events"
    __table_args__ = (Index("ix_audit_events_target", "target_type", "target_id"),)

    id: Mapped[uuid.UUID] = mapped_column(primary_key=True, default=uuid.uuid4)
    actor: Mapped[str] = mapped_column(String(100))
    action: Mapped[str] = mapped_column(String(40))
    target_type: Mapped[str] = mapped_column(String(20))
    target_id: Mapped[str] = mapped_column(String(64))
    detail: Mapped[str] = mapped_column(String(500), default="", server_default="")
    at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())
