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


class LadderSession(Base):
    """One Challenge Ladder on a topic, with all its rounds (app/domain/challenge_ladder.py)."""

    __tablename__ = "ladder_sessions"
    __table_args__ = (
        CheckConstraint(
            "source_mix IN ('papers', 'web_main', 'web_only')", name="source_mix_valid"
        ),
    )

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
    # What the questions are based on: the learner's papers, mainly the web, or only the web.
    source_mix: Mapped[str] = mapped_column(String(10))
    # Fetched once per session; [] when the search failed or found nothing, null before.
    web_references: Mapped[list[dict[str, Any]] | None] = mapped_column(JSONB)
    # The app can show formats beyond one correct option.
    new_formats: Mapped[bool] = mapped_column(Boolean, default=False, server_default="false")
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())


class LadderStep(Base):
    """One step of a round: planned first, then filled with a checked question, then answered.
    Questions stay here, never in ``questions``, so they can't reach any repeat count."""

    __tablename__ = "ladder_steps"
    __table_args__ = (
        CheckConstraint(
            "difficulty IN ('easy', 'medium', 'medium_hard', 'hard', 'extreme_hard')",
            name="difficulty_valid",
        ),
        CheckConstraint(
            "source IS NULL OR source IN ('ai', 'paper', 'library')", name="source_valid"
        ),
        CheckConstraint("step BETWEEN 1 AND 5", name="step_valid"),
    )

    session_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("ladder_sessions.id", ondelete="CASCADE"), primary_key=True
    )
    round_number: Mapped[int] = mapped_column(Integer, primary_key=True)
    step: Mapped[int] = mapped_column(Integer, primary_key=True)
    difficulty: Mapped[str] = mapped_column(String(12))
    pattern_id: Mapped[uuid.UUID | None] = mapped_column(
        ForeignKey("question_patterns.id", ondelete="SET NULL")
    )
    model_name: Mapped[str | None] = mapped_column(String(120))
    second_pattern_id: Mapped[uuid.UUID | None] = mapped_column(
        ForeignKey("question_patterns.id", ondelete="SET NULL")
    )
    second_model_name: Mapped[str | None] = mapped_column(String(120))
    # The question: null until generated. ai = written and checked; paper = a real question.
    source: Mapped[str | None] = mapped_column(String(7))
    # How it was checked: solves that agreed, and whether the answer was recalculated.
    checks: Mapped[dict[str, Any] | None] = mapped_column(JSONB)
    basis_papers: Mapped[int] = mapped_column(Integer, default=0, server_default="0")
    basis_web: Mapped[bool] = mapped_column(Boolean, default=False, server_default="false")
    paper_label: Mapped[str | None] = mapped_column(String(300))
    question_id: Mapped[uuid.UUID | None] = mapped_column(
        ForeignKey("questions.id", ondelete="SET NULL")
    )
    stem: Mapped[str | None] = mapped_column(Text)
    options: Mapped[list[str] | None] = mapped_column(JSONB)
    answer_index: Mapped[int | None] = mapped_column(Integer)
    solution: Mapped[list[str] | None] = mapped_column(JSONB)
    shortcut: Mapped[str | None] = mapped_column(Text)
    time_target_seconds: Mapped[int | None] = mapped_column(Integer)
    # How it is answered (app/domain/question_formats.py). A format with an answer_spec has no
    # answer_index.
    format: Mapped[str] = mapped_column(
        String(20), default="single_correct", server_default="single_correct"
    )
    answer_spec: Mapped[dict[str, Any] | None] = mapped_column(JSONB)
    # The exam's marks for this step, kept so a later format never changes an attempt. Null: the
    # exam states none for this subject.
    marks_correct: Mapped[float | None] = mapped_column(Float)
    marks_wrong: Mapped[float | None] = mapped_column(Float)
    partial_rule: Mapped[dict[str, Any] | None] = mapped_column(JSONB)
    # The attempt.
    selected_index: Mapped[int | None] = mapped_column(Integer)
    response: Mapped[dict[str, Any] | None] = mapped_column(JSONB)
    correct: Mapped[bool | None] = mapped_column(Boolean)
    marks_awarded: Mapped[float | None] = mapped_column(Float)
    time_spent_ms: Mapped[int | None] = mapped_column(Integer)
    answered_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))


class GeneratedReview(Base):
    """A generated question waiting for a person before it can enter the library. It holds the
    question only: nothing says which learner's ladder produced it."""

    __tablename__ = "generated_reviews"
    __table_args__ = (
        CheckConstraint("status IN ('pending', 'accepted', 'rejected')", name="status_valid"),
    )

    id: Mapped[uuid.UUID] = mapped_column(primary_key=True, default=uuid.uuid4)
    exam_code: Mapped[str] = mapped_column(ForeignKey("exams.code"))
    subject: Mapped[str] = mapped_column(String(100))
    topic_id: Mapped[uuid.UUID | None] = mapped_column(ForeignKey("topics.id", ondelete="SET NULL"))
    topic_name: Mapped[str] = mapped_column(String(100))
    difficulty: Mapped[str] = mapped_column(String(12))
    format: Mapped[str] = mapped_column(String(20))
    stem: Mapped[str] = mapped_column(Text)
    options: Mapped[list[str]] = mapped_column(JSONB)
    answer_index: Mapped[int | None] = mapped_column(Integer)
    answer_spec: Mapped[dict[str, Any] | None] = mapped_column(JSONB)
    solution: Mapped[list[str]] = mapped_column(JSONB)
    status: Mapped[str] = mapped_column(
        String(8), default="pending", server_default="pending", index=True
    )
    reviewed_by: Mapped[str | None] = mapped_column(String(320))
    reviewed_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    review_note: Mapped[str | None] = mapped_column(String(500))
    question_id: Mapped[uuid.UUID | None] = mapped_column(
        ForeignKey("questions.id", ondelete="SET NULL")
    )
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())


class LadderGate(Base):
    """The accuracy a subject must reach on the benchmark, set by the owner. Without a row, the
    subject stays off."""

    __tablename__ = "ladder_gates"

    exam_code: Mapped[str] = mapped_column(ForeignKey("exams.code"), primary_key=True)
    subject: Mapped[str] = mapped_column(String(100), primary_key=True)
    threshold: Mapped[float] = mapped_column(Float)
    set_by: Mapped[str] = mapped_column(String(320))
    set_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())


class LadderBenchmarkRun(Base):
    """Totals of one benchmark run for a subject and format. Never a question."""

    __tablename__ = "ladder_benchmark_runs"

    id: Mapped[uuid.UUID] = mapped_column(primary_key=True, default=uuid.uuid4)
    run_id: Mapped[uuid.UUID] = mapped_column()
    exam_code: Mapped[str] = mapped_column(ForeignKey("exams.code"), index=True)
    subject: Mapped[str] = mapped_column(String(100))
    format: Mapped[str] = mapped_column(String(20))
    items: Mapped[int] = mapped_column(Integer)
    accepted: Mapped[int] = mapped_column(Integer)  # passed every check
    correct: Mapped[int] = mapped_column(Integer)  # of those, matched the known answer
    model: Mapped[str] = mapped_column(String(64))
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())
