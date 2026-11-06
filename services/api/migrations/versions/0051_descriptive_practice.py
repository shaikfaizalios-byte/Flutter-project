"""descriptive practice: questions with rubrics and AI-estimated marks

Separate tables, never ``questions``, so nothing written here can reach a repeat count. New AI
tasks for the log. Nothing existing changes.

Revision ID: 0051
Revises: 0050
"""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects import postgresql

revision: str = "0051"
down_revision: str | None = "0050"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None

TASKS_BEFORE = (
    "task IN ('explanation', 'questions', 'topic', 'taxonomy', 'quick_answer', 'rag_answer', "
    "'paper_read', 'topic_lesson', 'topic_quiz', 'answer_check', 'study_topics', "
    "'paper_summary', 'ladder_search', 'ladder_question', 'ladder_solve')"
)
TASKS_AFTER = (
    "task IN ('explanation', 'questions', 'topic', 'taxonomy', 'quick_answer', 'rag_answer', "
    "'paper_read', 'topic_lesson', 'topic_quiz', 'answer_check', 'study_topics', "
    "'paper_summary', 'ladder_search', 'ladder_question', 'ladder_solve', "
    "'descriptive_question', 'descriptive_mark', 'descriptive_read')"
)


def upgrade() -> None:
    op.create_table(
        "descriptive_sessions",
        sa.Column("id", sa.Uuid(), nullable=False),
        sa.Column("owner_id", sa.Uuid(), nullable=False),
        sa.Column("exam_code", sa.String(length=32), nullable=False),
        sa.Column("topic_id", sa.Uuid(), nullable=True),
        sa.Column("topic_name", sa.String(length=100), nullable=False),
        sa.Column("subject", sa.String(length=100), nullable=False),
        sa.Column("language", sa.String(length=8), nullable=False),
        sa.Column(
            "created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False
        ),
        sa.ForeignKeyConstraint(
            ["exam_code"],
            ["exams.code"],
            name=op.f("fk_descriptive_sessions_exam_code_exams"),
            ondelete="CASCADE",
        ),
        sa.ForeignKeyConstraint(
            ["language"],
            ["languages.code"],
            name=op.f("fk_descriptive_sessions_language_languages"),
        ),
        sa.ForeignKeyConstraint(
            ["owner_id"],
            ["users.id"],
            name=op.f("fk_descriptive_sessions_owner_id_users"),
            ondelete="CASCADE",
        ),
        sa.ForeignKeyConstraint(
            ["topic_id"],
            ["topics.id"],
            name=op.f("fk_descriptive_sessions_topic_id_topics"),
            ondelete="SET NULL",
        ),
        sa.PrimaryKeyConstraint("id", name=op.f("pk_descriptive_sessions")),
    )
    op.create_index(op.f("ix_descriptive_sessions_owner_id"), "descriptive_sessions", ["owner_id"])
    op.create_table(
        "descriptive_steps",
        sa.Column("session_id", sa.Uuid(), nullable=False),
        sa.Column("step", sa.Integer(), nullable=False),
        sa.Column("level", sa.String(length=20), nullable=False),
        sa.Column("marks", sa.Float(), nullable=False),
        sa.Column("word_limit", sa.Integer(), nullable=False),
        sa.Column("stem", sa.Text(), nullable=True),
        sa.Column("rubric", postgresql.JSONB(astext_type=sa.Text()), nullable=True),
        sa.Column("model_answer", sa.Text(), nullable=True),
        sa.Column("answer_text", sa.Text(), nullable=True),
        sa.Column("answer_source", sa.String(length=5), nullable=True),
        sa.Column("word_count", sa.Integer(), nullable=True),
        sa.Column("marking", postgresql.JSONB(astext_type=sa.Text()), nullable=True),
        sa.Column("marks_awarded", sa.Float(), nullable=True),
        sa.Column("marks_low", sa.Float(), nullable=True),
        sa.Column("marks_high", sa.Float(), nullable=True),
        sa.Column("runs", sa.Integer(), nullable=True),
        sa.Column("answered_at", sa.DateTime(timezone=True), nullable=True),
        sa.CheckConstraint(
            "answer_source IS NULL OR answer_source IN ('typed', 'photo')",
            name=op.f("ck_descriptive_steps_answer_source_valid"),
        ),
        sa.ForeignKeyConstraint(
            ["session_id"],
            ["descriptive_sessions.id"],
            name=op.f("fk_descriptive_steps_session_id_descriptive_sessions"),
            ondelete="CASCADE",
        ),
        sa.PrimaryKeyConstraint("session_id", "step", name=op.f("pk_descriptive_steps")),
    )
    op.drop_constraint(op.f("ck_ai_generations_task_valid"), "ai_generations", type_="check")
    op.create_check_constraint(op.f("ck_ai_generations_task_valid"), "ai_generations", TASKS_AFTER)


def downgrade() -> None:
    op.execute(
        "DELETE FROM ai_generations "
        "WHERE task IN ('descriptive_question', 'descriptive_mark', 'descriptive_read')"
    )
    op.drop_constraint(op.f("ck_ai_generations_task_valid"), "ai_generations", type_="check")
    op.create_check_constraint(op.f("ck_ai_generations_task_valid"), "ai_generations", TASKS_BEFORE)
    op.drop_table("descriptive_steps")
    op.drop_index(op.f("ix_descriptive_sessions_owner_id"), table_name="descriptive_sessions")
    op.drop_table("descriptive_sessions")
