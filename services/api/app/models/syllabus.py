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
from sqlalchemy.dialects.postgresql import ARRAY
from sqlalchemy.orm import Mapped, mapped_column

from app.database.base import Base


class SyllabusVersion(Base):
    """One version of an exam's syllabus. Shared (``owner_id`` NULL) or a learner's own. With no
    ``effective_year`` it applies from the start: nobody recorded when it began."""

    __tablename__ = "syllabus_versions"
    __table_args__ = (
        CheckConstraint("source_kind IN ('template', 'pdf', 'manual')", name="source_kind_valid"),
        UniqueConstraint(
            "exam_code",
            "owner_id",
            "effective_year",
            name="uq_syllabus_versions_exam_owner_year",
            postgresql_nulls_not_distinct=True,
        ),
    )

    id: Mapped[uuid.UUID] = mapped_column(primary_key=True, default=uuid.uuid4)
    exam_code: Mapped[str] = mapped_column(
        String(32), ForeignKey("exams.code", ondelete="CASCADE"), index=True
    )
    owner_id: Mapped[uuid.UUID | None] = mapped_column(
        ForeignKey("users.id", ondelete="CASCADE"), index=True
    )
    effective_year: Mapped[int | None] = mapped_column(Integer)
    name: Mapped[str] = mapped_column(String(200))
    source_kind: Mapped[str] = mapped_column(String(8))
    source_title: Mapped[str | None] = mapped_column(String(300))
    source_url: Mapped[str | None] = mapped_column(String(500))
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())


class SyllabusNode(Base):
    """A node of a syllabus tree, at any depth. A leaf points to the topic questions use; a
    linked node reads its keywords from that topic unless it states its own."""

    __tablename__ = "syllabus_nodes"

    id: Mapped[uuid.UUID] = mapped_column(primary_key=True, default=uuid.uuid4)
    version_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("syllabus_versions.id", ondelete="CASCADE"), index=True
    )
    parent_id: Mapped[uuid.UUID | None] = mapped_column(
        ForeignKey("syllabus_nodes.id", ondelete="CASCADE"), index=True
    )
    position: Mapped[int] = mapped_column(Integer)
    name: Mapped[str] = mapped_column(String(100))
    level_label: Mapped[str | None] = mapped_column(String(30))  # "Subject", "Unit", "Chapter"
    keywords: Mapped[list[str]] = mapped_column(
        ARRAY(String(60)), default=list, server_default="{}"
    )
    aliases: Mapped[list[str]] = mapped_column(
        ARRAY(String(100)), default=list, server_default="{}"
    )
    topic_id: Mapped[uuid.UUID | None] = mapped_column(
        ForeignKey("topics.id", ondelete="SET NULL"), index=True
    )
