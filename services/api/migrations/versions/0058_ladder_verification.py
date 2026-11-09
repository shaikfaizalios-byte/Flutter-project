"""stricter ladder checks: review queue, subject gates and benchmark results

A step records how it was checked, and can hold a library question. Generated questions waiting for
a person sit in their own table, gates say which subjects may use generated hard questions, and
benchmark runs keep totals only, never a question. Nothing existing changes.

Revision ID: 0058
Revises: 0057
"""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects import postgresql

revision: str = "0058"
down_revision: str | None = "0057"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.alter_column(
        "ladder_steps", "source", type_=sa.String(length=7), existing_type=sa.String(length=5)
    )
    op.drop_constraint(op.f("ck_ladder_steps_source_valid"), "ladder_steps", type_="check")
    op.create_check_constraint(
        op.f("ck_ladder_steps_source_valid"),
        "ladder_steps",
        "source IS NULL OR source IN ('ai', 'paper', 'library')",
    )
    op.add_column(
        "ladder_steps", sa.Column("checks", postgresql.JSONB(astext_type=sa.Text()), nullable=True)
    )
    op.create_table(
        "generated_reviews",
        sa.Column("id", sa.Uuid(), nullable=False),
        sa.Column("exam_code", sa.String(length=32), nullable=False),
        sa.Column("subject", sa.String(length=100), nullable=False),
        sa.Column("topic_id", sa.Uuid(), nullable=True),
        sa.Column("topic_name", sa.String(length=100), nullable=False),
        sa.Column("difficulty", sa.String(length=12), nullable=False),
        sa.Column("format", sa.String(length=20), nullable=False),
        sa.Column("stem", sa.Text(), nullable=False),
        sa.Column("options", postgresql.JSONB(astext_type=sa.Text()), nullable=False),
        sa.Column("answer_index", sa.Integer(), nullable=True),
        sa.Column("answer_spec", postgresql.JSONB(astext_type=sa.Text()), nullable=True),
        sa.Column("solution", postgresql.JSONB(astext_type=sa.Text()), nullable=False),
        sa.Column("status", sa.String(length=8), server_default="pending", nullable=False),
        sa.Column("reviewed_by", sa.String(length=320), nullable=True),
        sa.Column("reviewed_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("review_note", sa.String(length=500), nullable=True),
        sa.Column("question_id", sa.Uuid(), nullable=True),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.text("now()"),
            nullable=False,
        ),
        sa.CheckConstraint(
            "status IN ('pending', 'accepted', 'rejected')",
            name=op.f("ck_generated_reviews_status_valid"),
        ),
        sa.ForeignKeyConstraint(
            ["exam_code"], ["exams.code"], name=op.f("fk_generated_reviews_exam_code_exams")
        ),
        sa.ForeignKeyConstraint(
            ["topic_id"],
            ["topics.id"],
            name=op.f("fk_generated_reviews_topic_id_topics"),
            ondelete="SET NULL",
        ),
        sa.ForeignKeyConstraint(
            ["question_id"],
            ["questions.id"],
            name=op.f("fk_generated_reviews_question_id_questions"),
            ondelete="SET NULL",
        ),
        sa.PrimaryKeyConstraint("id", name=op.f("pk_generated_reviews")),
    )
    op.create_index(
        op.f("ix_generated_reviews_status"), "generated_reviews", ["status"], unique=False
    )
    op.create_table(
        "ladder_gates",
        sa.Column("exam_code", sa.String(length=32), nullable=False),
        sa.Column("subject", sa.String(length=100), nullable=False),
        sa.Column("threshold", sa.Float(), nullable=False),
        sa.Column("set_by", sa.String(length=320), nullable=False),
        sa.Column(
            "set_at", sa.DateTime(timezone=True), server_default=sa.text("now()"), nullable=False
        ),
        sa.ForeignKeyConstraint(
            ["exam_code"], ["exams.code"], name=op.f("fk_ladder_gates_exam_code_exams")
        ),
        sa.PrimaryKeyConstraint("exam_code", "subject", name=op.f("pk_ladder_gates")),
    )
    op.create_table(
        "ladder_benchmark_runs",
        sa.Column("id", sa.Uuid(), nullable=False),
        sa.Column("run_id", sa.Uuid(), nullable=False),
        sa.Column("exam_code", sa.String(length=32), nullable=False),
        sa.Column("subject", sa.String(length=100), nullable=False),
        sa.Column("format", sa.String(length=20), nullable=False),
        sa.Column("items", sa.Integer(), nullable=False),
        sa.Column("accepted", sa.Integer(), nullable=False),
        sa.Column("correct", sa.Integer(), nullable=False),
        sa.Column("model", sa.String(length=64), nullable=False),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.text("now()"),
            nullable=False,
        ),
        sa.ForeignKeyConstraint(
            ["exam_code"], ["exams.code"], name=op.f("fk_ladder_benchmark_runs_exam_code_exams")
        ),
        sa.PrimaryKeyConstraint("id", name=op.f("pk_ladder_benchmark_runs")),
    )
    op.create_index(
        op.f("ix_ladder_benchmark_runs_exam_code"),
        "ladder_benchmark_runs",
        ["exam_code"],
        unique=False,
    )


def downgrade() -> None:
    op.drop_index(op.f("ix_ladder_benchmark_runs_exam_code"), table_name="ladder_benchmark_runs")
    op.drop_table("ladder_benchmark_runs")
    op.drop_table("ladder_gates")
    op.drop_index(op.f("ix_generated_reviews_status"), table_name="generated_reviews")
    op.drop_table("generated_reviews")
    op.drop_column("ladder_steps", "checks")
    # The older schema can't name a library question as a step's source.
    op.execute("UPDATE ladder_steps SET source = 'paper' WHERE source = 'library'")
    op.drop_constraint(op.f("ck_ladder_steps_source_valid"), "ladder_steps", type_="check")
    op.create_check_constraint(
        op.f("ck_ladder_steps_source_valid"),
        "ladder_steps",
        "source IS NULL OR source IN ('ai', 'paper')",
    )
    op.alter_column(
        "ladder_steps", "source", type_=sa.String(length=5), existing_type=sa.String(length=7)
    )
