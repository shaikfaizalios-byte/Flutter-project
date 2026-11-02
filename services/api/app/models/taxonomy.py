"""Canonical topics (global Phase 6; rules in app/domain/taxonomy.py)."""

import uuid
from datetime import datetime

from sqlalchemy import (
    Boolean,
    CheckConstraint,
    DateTime,
    ForeignKey,
    Index,
    String,
    UniqueConstraint,
    func,
    text,
)
from sqlalchemy.orm import Mapped, mapped_column

from app.database.base import Base


class TaxonomyNode(Base):
    """A canonical subject or topic, independent of any exam's or language's wording."""

    __tablename__ = "taxonomy_nodes"
    __table_args__ = (
        CheckConstraint("kind IN ('subject', 'topic')", name="kind_valid"),
        CheckConstraint("(kind = 'subject') = (parent_id IS NULL)", name="topics_have_a_subject"),
    )

    id: Mapped[uuid.UUID] = mapped_column(primary_key=True, default=uuid.uuid4)
    # Stable, readable id ("quantitative-aptitude/percentage"); never reused for another meaning.
    key: Mapped[str] = mapped_column(String(160), unique=True)
    kind: Mapped[str] = mapped_column(String(8))
    parent_id: Mapped[uuid.UUID | None] = mapped_column(
        ForeignKey("taxonomy_nodes.id", ondelete="RESTRICT"), index=True
    )
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())


class TaxonomyLabel(Base):
    """A name of a canonical node in one language (an alias when ``is_alias``)."""

    __tablename__ = "taxonomy_labels"
    __table_args__ = (
        UniqueConstraint("node_id", "language", "label", name="uq_taxonomy_labels_node_label"),
        CheckConstraint("language ~ '^[a-z]{2}$'", name="language_iso"),
    )

    id: Mapped[uuid.UUID] = mapped_column(primary_key=True, default=uuid.uuid4)
    node_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("taxonomy_nodes.id", ondelete="CASCADE"), index=True
    )
    language: Mapped[str] = mapped_column(String(2))
    label: Mapped[str] = mapped_column(String(120))
    is_alias: Mapped[bool] = mapped_column(Boolean, default=False, server_default="false")


class TopicTaxonomyLink(Base):
    """Which canonical topic an exam-specific topic means. Suggested by rules, confirmed or
    rejected by the topic's owner (or recorded by a migration for shared topics). Only
    confirmed links count; a topic has at most one."""

    __tablename__ = "topic_taxonomy_links"
    __table_args__ = (
        CheckConstraint("status IN ('suggested', 'confirmed', 'rejected')", name="status_valid"),
        CheckConstraint(
            "source IN ('migration', 'rules', 'learner', 'operator')", name="source_valid"
        ),
        Index(
            "uq_topic_taxonomy_links_one_confirmed",
            "topic_id",
            unique=True,
            postgresql_where=text("status = 'confirmed'"),
        ),
    )

    topic_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("topics.id", ondelete="CASCADE"), primary_key=True
    )
    node_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("taxonomy_nodes.id", ondelete="CASCADE"), primary_key=True, index=True
    )
    status: Mapped[str] = mapped_column(String(10))
    source: Mapped[str] = mapped_column(String(10))
    reason: Mapped[str | None] = mapped_column(String(200))
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())
    decided_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
