import uuid
from datetime import date, datetime
from enum import StrEnum
from typing import Any

from sqlalchemy import (
    Boolean,
    CheckConstraint,
    Date,
    DateTime,
    Float,
    ForeignKey,
    Index,
    Integer,
    LargeBinary,
    String,
    Text,
    UniqueConstraint,
    func,
)
from sqlalchemy.dialects.postgresql import ARRAY, JSONB
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.database.base import Base


class VerificationStatus(StrEnum):
    UNVERIFIED = "unverified"
    VERIFIED = "verified"
    REJECTED = "rejected"


class QuestionOrigin(StrEnum):
    SOURCE = "source"  # extracted from an uploaded document
    AI = "ai"  # generated (Phase 9); never presented as an official question


class TopicStatus(StrEnum):
    UNASSIGNED = "unassigned"
    SUGGESTED = "suggested"  # keyword match; needs human confirmation
    CONFIRMED = "confirmed"


class ExamFormat(Base):
    """A verified exam paper layout. Only formats confirmed against an official source are
    stored; the source is recorded so it can be re-checked. Unknown formats simply have no
    row, and count-based checks are skipped for them."""

    __tablename__ = "exam_formats"

    id: Mapped[uuid.UUID] = mapped_column(primary_key=True, default=uuid.uuid4)
    code: Mapped[str] = mapped_column(String(64), unique=True)
    exam_code: Mapped[str] = mapped_column(
        String(32), ForeignKey("exams.code", ondelete="RESTRICT")
    )
    tier: Mapped[str] = mapped_column(String(32))
    name: Mapped[str] = mapped_column(String(200))
    # [{"part": "I", "subject": "...", "questions": 25, "max_marks": 50}, ...]
    sections: Mapped[list[dict[str, Any]]] = mapped_column(JSONB)
    sections_in_fixed_order: Mapped[bool] = mapped_column(Boolean)
    total_questions: Mapped[int] = mapped_column(Integer)
    duration_minutes: Mapped[int | None] = mapped_column(Integer)
    negative_marks_per_wrong: Mapped[float | None] = mapped_column(Float)
    source_title: Mapped[str] = mapped_column(String(300))
    source_url: Mapped[str] = mapped_column(String(500))
    source_reference: Mapped[str] = mapped_column(String(300))
    source_published_on: Mapped[date] = mapped_column(Date)
    verified_on: Mapped[date] = mapped_column(Date)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())


class Topic(Base):
    """Editable taxonomy (data, not code). ``keywords`` drive topic *suggestions* only."""

    __tablename__ = "topics"
    __table_args__ = (
        UniqueConstraint(
            "owner_id",
            "exam_codes",
            "subject",
            "name",
            name="uq_topics_scope_subject_name",
            postgresql_nulls_not_distinct=True,
        ),
    )

    id: Mapped[uuid.UUID] = mapped_column(primary_key=True, default=uuid.uuid4)
    subject: Mapped[str] = mapped_column(String(100))
    name: Mapped[str] = mapped_column(String(100))
    keywords: Mapped[list[str]] = mapped_column(
        ARRAY(String(60)), default=list, server_default="{}"
    )
    # NULL: shared taxonomy (visible to everyone); set: a learner's own topic.
    owner_id: Mapped[uuid.UUID | None] = mapped_column(
        ForeignKey("users.id", ondelete="CASCADE"), index=True
    )
    # Exams the topic applies to; NULL means every exam.
    exam_codes: Mapped[list[str] | None] = mapped_column(ARRAY(String(32)))
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())


class QuestionPattern(Base):
    """A named question type within a topic (e.g. Venn diagrams: "Relationship between
    classes"). Editable taxonomy data; ``keywords`` drive pattern *suggestions* only."""

    __tablename__ = "question_patterns"
    __table_args__ = (UniqueConstraint("topic_id", "name", name="uq_question_patterns_topic_name"),)

    id: Mapped[uuid.UUID] = mapped_column(primary_key=True, default=uuid.uuid4)
    topic_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("topics.id", ondelete="CASCADE"), index=True
    )
    name: Mapped[str] = mapped_column(String(120))
    keywords: Mapped[list[str]] = mapped_column(
        ARRAY(String(60)), default=list, server_default="{}"
    )
    sort_order: Mapped[int] = mapped_column(Integer, default=0, server_default="0")
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())


class Passage(Base):
    """Shared directions or a reading passage that governs several questions."""

    __tablename__ = "passages"

    id: Mapped[uuid.UUID] = mapped_column(primary_key=True, default=uuid.uuid4)
    document_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("documents.id", ondelete="CASCADE"), index=True
    )
    text: Mapped[str] = mapped_column(Text)
    first_question: Mapped[int | None] = mapped_column(Integer)
    last_question: Mapped[int | None] = mapped_column(Integer)
    source_pages: Mapped[list[int]] = mapped_column(ARRAY(Integer), default=list)


class Question(Base):
    __tablename__ = "questions"
    __table_args__ = (
        CheckConstraint("origin IN ('source', 'ai')", name="origin_valid"),
        CheckConstraint(
            "verification_status IN ('unverified', 'verified', 'rejected')", name="status_valid"
        ),
        CheckConstraint(
            "topic_status IN ('unassigned', 'suggested', 'confirmed')", name="topic_status_valid"
        ),
        CheckConstraint("language IN ('en', 'hi')", name="language_supported"),
        # Source questions must carry provenance.
        CheckConstraint(
            "origin <> 'source' OR (document_id IS NOT NULL AND source_question_number IS NOT NULL)",  # noqa: E501
            name="source_has_provenance",
        ),
        # AI questions must record how they were made.
        CheckConstraint(
            "origin <> 'ai' OR (ai_provider IS NOT NULL AND ai_model IS NOT NULL"
            " AND ai_prompt_version IS NOT NULL)",
            name="ai_has_provenance",
        ),
        CheckConstraint(
            "topic_suggested_by IS NULL OR topic_suggested_by IN ('keywords', 'ai')",
            name="topic_suggested_by_valid",
        ),
        CheckConstraint(
            "pattern_status IN ('unassigned', 'suggested', 'confirmed')",
            name="pattern_status_valid",
        ),
        CheckConstraint("answer_type IN ('choice', 'typed')", name="answer_type_valid"),
        # A typed question has no option answer, and only typed questions have a typed answer.
        CheckConstraint(
            "answer_type = 'choice' OR correct_option_position IS NULL",
            name="typed_has_no_option_answer",
        ),
        CheckConstraint(
            "answer_type = 'typed' OR typed_answer IS NULL", name="typed_answer_only_typed"
        ),
        Index("ix_questions_exam_section", "exam_code", "section"),
        Index("ix_questions_document_number", "document_id", "source_question_number"),
    )

    id: Mapped[uuid.UUID] = mapped_column(primary_key=True, default=uuid.uuid4)
    # Owner (Phase 10). Null only for data created before accounts existed, until the first
    # account claims it; every query filters by the signed-in owner.
    owner_id: Mapped[uuid.UUID | None] = mapped_column(
        ForeignKey("users.id", ondelete="CASCADE"), index=True
    )
    origin: Mapped[str] = mapped_column(String(8), default=QuestionOrigin.SOURCE)
    exam_code: Mapped[str] = mapped_column(
        String(32), ForeignKey("exams.code", ondelete="RESTRICT")
    )
    exam_format_id: Mapped[uuid.UUID | None] = mapped_column(
        ForeignKey("exam_formats.id", ondelete="SET NULL")
    )
    section: Mapped[str | None] = mapped_column(String(120))
    subject: Mapped[str | None] = mapped_column(String(100))
    topic_id: Mapped[uuid.UUID | None] = mapped_column(
        ForeignKey("topics.id", ondelete="SET NULL"), index=True
    )
    topic_status: Mapped[str] = mapped_column(String(12), default=TopicStatus.UNASSIGNED)
    stem: Mapped[str] = mapped_column(Text)
    language: Mapped[str] = mapped_column(String(8))
    document_id: Mapped[uuid.UUID | None] = mapped_column(
        ForeignKey("documents.id", ondelete="CASCADE")
    )
    source_question_number: Mapped[int | None] = mapped_column(Integer)
    source_pages: Mapped[list[int]] = mapped_column(ARRAY(Integer), default=list)
    passage_id: Mapped[uuid.UUID | None] = mapped_column(
        ForeignKey("passages.id", ondelete="SET NULL")
    )
    correct_option_position: Mapped[int | None] = mapped_column(Integer)
    # "choice": pick an option; "typed": type the answer in (TITA), compared by typed_answers.
    answer_type: Mapped[str] = mapped_column(String(8), default="choice", server_default="choice")
    typed_answer: Mapped[str | None] = mapped_column(String(100))
    # "answer_key" | "inline" | "manual" — where the answer came from.
    answer_source: Mapped[str | None] = mapped_column(String(16))
    explanation: Mapped[str | None] = mapped_column(Text)
    image_dependent: Mapped[bool] = mapped_column(Boolean, default=False, server_default="false")
    verification_status: Mapped[str] = mapped_column(
        String(12), default=VerificationStatus.UNVERIFIED
    )
    verified_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    # Who suggested topic_id while topic_status is "suggested" (keywords or ai).
    topic_suggested_by: Mapped[str | None] = mapped_column(String(8))
    # Why the topic was suggested (matched words, or the AI model), shown to reviewers.
    topic_suggestion_reason: Mapped[str | None] = mapped_column(String(200))
    # Question type within the topic (suggested by keyword rules, confirmed by a reviewer).
    pattern_id: Mapped[uuid.UUID | None] = mapped_column(
        ForeignKey("question_patterns.id", ondelete="SET NULL"), index=True
    )
    pattern_status: Mapped[str] = mapped_column(
        String(12), default=TopicStatus.UNASSIGNED, server_default="unassigned"
    )
    pattern_suggestion_reason: Mapped[str | None] = mapped_column(String(200))
    # AI provenance (origin = ai): never presented as an official question.
    ai_provider: Mapped[str | None] = mapped_column(String(32))
    ai_model: Mapped[str | None] = mapped_column(String(64))
    ai_prompt_version: Mapped[str | None] = mapped_column(String(32))
    ai_source_question_id: Mapped[uuid.UUID | None] = mapped_column(
        ForeignKey("questions.id", ondelete="SET NULL")
    )
    # Learner-provided basis (e.g. "Concept: Percent change"); no notes text is stored.
    ai_source_note: Mapped[str | None] = mapped_column(String(300))
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), onupdate=func.now()
    )

    options: Mapped[list["QuestionOption"]] = relationship(
        cascade="all, delete-orphan",
        passive_deletes=True,
        order_by="QuestionOption.position",
    )
    issues: Mapped[list["QuestionIssue"]] = relationship(
        cascade="all, delete-orphan", passive_deletes=True
    )
    passage: Mapped[Passage | None] = relationship()
    topic: Mapped[Topic | None] = relationship()
    pattern: Mapped[QuestionPattern | None] = relationship()
    figures: Mapped[list["QuestionFigure"]] = relationship(
        cascade="all, delete-orphan",
        passive_deletes=True,
        order_by="QuestionFigure.sort_order",
    )


class QuestionOption(Base):
    __tablename__ = "question_options"
    __table_args__ = (CheckConstraint("position >= 1", name="position_positive"),)

    question_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("questions.id", ondelete="CASCADE"), primary_key=True
    )
    position: Mapped[int] = mapped_column(Integer, primary_key=True)  # 1-based display order
    label: Mapped[str] = mapped_column(String(8))  # as printed: "1", "a", "A"
    text: Mapped[str] = mapped_column(Text)


class QuestionIssue(Base):
    """A problem found by the segmenter or validators. ``question_id`` is null for
    document-level issues (e.g. question count differs from the verified format)."""

    __tablename__ = "question_issues"

    id: Mapped[uuid.UUID] = mapped_column(primary_key=True, default=uuid.uuid4)
    document_id: Mapped[uuid.UUID | None] = mapped_column(
        ForeignKey("documents.id", ondelete="CASCADE"), index=True
    )
    question_id: Mapped[uuid.UUID | None] = mapped_column(
        ForeignKey("questions.id", ondelete="CASCADE"), index=True
    )
    code: Mapped[str] = mapped_column(String(48))
    detail: Mapped[str] = mapped_column(String(500), default="", server_default="")
    resolved: Mapped[bool] = mapped_column(Boolean, default=False, server_default="false")
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())


class FigureKind(StrEnum):
    STEM = "stem"  # a figure in the question itself
    OPTION = "option"  # an option that is a figure
    ORIGINAL = "original"  # the whole question as printed (its text could not be read in full)


class QuestionFigure(Base):
    """An image cropped from the source PDF page (never generated). ``data`` is PNG bytes,
    loaded only when the image itself is requested."""

    __tablename__ = "question_figures"
    __table_args__ = (
        CheckConstraint("kind IN ('stem', 'option', 'original')", name="kind_valid"),
        CheckConstraint(
            "(kind = 'option') = (option_position IS NOT NULL)", name="option_position_iff_option"
        ),
        CheckConstraint("page_number >= 1", name="page_positive"),
    )

    id: Mapped[uuid.UUID] = mapped_column(primary_key=True, default=uuid.uuid4)
    question_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("questions.id", ondelete="CASCADE"), index=True
    )
    kind: Mapped[str] = mapped_column(String(8))
    option_position: Mapped[int | None] = mapped_column(Integer)  # 1-based, for kind = option
    sort_order: Mapped[int] = mapped_column(Integer)
    page_number: Mapped[int] = mapped_column(Integer)
    # (left, bottom, right, top) in PDF points on that page.
    box: Mapped[list[float]] = mapped_column(ARRAY(Float))
    width: Mapped[int] = mapped_column(Integer)  # pixels
    height: Mapped[int] = mapped_column(Integer)
    content_type: Mapped[str] = mapped_column(String(32), default="image/png")
    data: Mapped[bytes] = mapped_column(LargeBinary, deferred=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())
