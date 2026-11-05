"""challenge ladder

Sessions and steps of the Challenge Ladder (app/domain/challenge_ladder.py), and its AI tasks.
Written questions live only here, never in ``questions``, so they can't reach the repeat counts.

Revision ID: 0040
Revises: 0039
Create Date: 2026-11-05 10:00:00

"""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects import postgresql

# revision identifiers, used by Alembic.
revision: str = "0040"
down_revision: str | Sequence[str] | None = "0039"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None

TASKS_BEFORE = (
    "task IN ('explanation', 'questions', 'topic', 'taxonomy', 'quick_answer', 'rag_answer', "
    "'paper_read', 'topic_lesson', 'topic_quiz', 'answer_check', 'study_topics', "
    "'paper_summary')"
)
TASKS_AFTER = (
    "task IN ('explanation', 'questions', 'topic', 'taxonomy', 'quick_answer', 'rag_answer', "
    "'paper_read', 'topic_lesson', 'topic_quiz', 'answer_check', 'study_topics', "
    "'paper_summary', 'ladder_search', 'ladder_question', 'ladder_solve')"
)


def upgrade() -> None:
    """Upgrade schema."""
    op.create_table(
        "ladder_sessions",
        sa.Column("id", sa.Uuid(), nullable=False),
        sa.Column("owner_id", sa.Uuid(), nullable=False),
        sa.Column("exam_code", sa.String(length=32), nullable=False),
        sa.Column("topic_id", sa.Uuid(), nullable=True),
        sa.Column("topic_name", sa.String(length=100), nullable=False),
        sa.Column("subject", sa.String(length=100), nullable=False),
        sa.Column("language", sa.String(length=8), nullable=False),
        sa.Column("source_mix", sa.String(length=10), nullable=False),
        sa.Column("web_references", postgresql.JSONB(astext_type=sa.Text()), nullable=True),
        sa.Column(
            "created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False
        ),
        sa.CheckConstraint(
            "source_mix IN ('papers', 'web_main', 'web_only')",
            name=op.f("ck_ladder_sessions_source_mix_valid"),
        ),
        sa.ForeignKeyConstraint(
            ["exam_code"],
            ["exams.code"],
            name=op.f("fk_ladder_sessions_exam_code_exams"),
            ondelete="CASCADE",
        ),
        sa.ForeignKeyConstraint(
            ["language"], ["languages.code"], name=op.f("fk_ladder_sessions_language_languages")
        ),
        sa.ForeignKeyConstraint(
            ["owner_id"],
            ["users.id"],
            name=op.f("fk_ladder_sessions_owner_id_users"),
            ondelete="CASCADE",
        ),
        sa.ForeignKeyConstraint(
            ["topic_id"],
            ["topics.id"],
            name=op.f("fk_ladder_sessions_topic_id_topics"),
            ondelete="SET NULL",
        ),
        sa.PrimaryKeyConstraint("id", name=op.f("pk_ladder_sessions")),
    )
    op.create_index(
        op.f("ix_ladder_sessions_owner_id"), "ladder_sessions", ["owner_id"], unique=False
    )
    op.create_table(
        "ladder_steps",
        sa.Column("session_id", sa.Uuid(), nullable=False),
        sa.Column("round_number", sa.Integer(), nullable=False),
        sa.Column("step", sa.Integer(), nullable=False),
        sa.Column("difficulty", sa.String(length=12), nullable=False),
        sa.Column("pattern_id", sa.Uuid(), nullable=True),
        sa.Column("model_name", sa.String(length=120), nullable=True),
        sa.Column("second_pattern_id", sa.Uuid(), nullable=True),
        sa.Column("second_model_name", sa.String(length=120), nullable=True),
        sa.Column("source", sa.String(length=5), nullable=True),
        sa.Column("basis_papers", sa.Integer(), server_default="0", nullable=False),
        sa.Column("basis_web", sa.Boolean(), server_default="false", nullable=False),
        sa.Column("paper_label", sa.String(length=300), nullable=True),
        sa.Column("question_id", sa.Uuid(), nullable=True),
        sa.Column("stem", sa.Text(), nullable=True),
        sa.Column("options", postgresql.JSONB(astext_type=sa.Text()), nullable=True),
        sa.Column("answer_index", sa.Integer(), nullable=True),
        sa.Column("solution", postgresql.JSONB(astext_type=sa.Text()), nullable=True),
        sa.Column("shortcut", sa.Text(), nullable=True),
        sa.Column("time_target_seconds", sa.Integer(), nullable=True),
        sa.Column("selected_index", sa.Integer(), nullable=True),
        sa.Column("correct", sa.Boolean(), nullable=True),
        sa.Column("time_spent_ms", sa.Integer(), nullable=True),
        sa.Column("answered_at", sa.DateTime(timezone=True), nullable=True),
        sa.CheckConstraint(
            "difficulty IN ('easy', 'medium', 'medium_hard', 'hard', 'extreme_hard')",
            name=op.f("ck_ladder_steps_difficulty_valid"),
        ),
        sa.CheckConstraint(
            "source IS NULL OR source IN ('ai', 'paper')", name=op.f("ck_ladder_steps_source_valid")
        ),
        sa.CheckConstraint("step BETWEEN 1 AND 5", name=op.f("ck_ladder_steps_step_valid")),
        sa.ForeignKeyConstraint(
            ["pattern_id"],
            ["question_patterns.id"],
            name=op.f("fk_ladder_steps_pattern_id_question_patterns"),
            ondelete="SET NULL",
        ),
        sa.ForeignKeyConstraint(
            ["question_id"],
            ["questions.id"],
            name=op.f("fk_ladder_steps_question_id_questions"),
            ondelete="SET NULL",
        ),
        sa.ForeignKeyConstraint(
            ["second_pattern_id"],
            ["question_patterns.id"],
            name=op.f("fk_ladder_steps_second_pattern_id_question_patterns"),
            ondelete="SET NULL",
        ),
        sa.ForeignKeyConstraint(
            ["session_id"],
            ["ladder_sessions.id"],
            name=op.f("fk_ladder_steps_session_id_ladder_sessions"),
            ondelete="CASCADE",
        ),
        sa.PrimaryKeyConstraint("session_id", "round_number", "step", name=op.f("pk_ladder_steps")),
    )
    op.drop_constraint(op.f("ck_ai_generations_task_valid"), "ai_generations", type_="check")
    op.create_check_constraint(op.f("ck_ai_generations_task_valid"), "ai_generations", TASKS_AFTER)


def downgrade() -> None:
    """Downgrade schema."""
    op.execute(
        "DELETE FROM ai_generations "
        "WHERE task IN ('ladder_search', 'ladder_question', 'ladder_solve')"
    )
    op.drop_constraint(op.f("ck_ai_generations_task_valid"), "ai_generations", type_="check")
    op.create_check_constraint(op.f("ck_ai_generations_task_valid"), "ai_generations", TASKS_BEFORE)
    op.drop_table("ladder_steps")
    op.drop_index(op.f("ix_ladder_sessions_owner_id"), table_name="ladder_sessions")
    op.drop_table("ladder_sessions")
