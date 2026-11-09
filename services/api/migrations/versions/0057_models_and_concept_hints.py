"""starter model proposals and concept hints

A proposal is a cluster of alike questions waiting for a subject reviewer; nothing becomes a model
until one approves it. A concept hint is an AI grouping by meaning, kept in its own table so it can
never reach the reviewed counts. Nothing existing changes.

Revision ID: 0057
Revises: 0056
"""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects import postgresql

revision: str = "0057"
down_revision: str | None = "0056"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None

TASKS = (
    "'explanation', 'questions', 'topic', 'taxonomy', 'quick_answer', "
    "'rag_answer', 'paper_read', 'topic_lesson', 'topic_quiz', 'answer_check', "
    "'study_topics', 'paper_summary', 'ladder_search', 'ladder_question', "
    "'ladder_solve', 'written_question', 'written_mark', 'written_read'"
)


def upgrade() -> None:
    op.create_table(
        "model_proposals",
        sa.Column("id", sa.Uuid(), nullable=False),
        sa.Column("exam_code", sa.String(length=32), nullable=False),
        sa.Column("topic_id", sa.Uuid(), nullable=False),
        sa.Column("signature", sa.String(length=64), nullable=False),
        sa.Column("question_ids", postgresql.JSONB(astext_type=sa.Text()), nullable=False),
        sa.Column("shifts", sa.Integer(), nullable=False),
        sa.Column("status", sa.String(length=8), server_default="proposed", nullable=False),
        sa.Column("reviewed_by", sa.String(length=320), nullable=True),
        sa.Column("reviewed_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("review_note", sa.String(length=500), nullable=True),
        sa.Column("pattern_id", sa.Uuid(), nullable=True),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.text("now()"),
            nullable=False,
        ),
        sa.CheckConstraint(
            "status IN ('proposed', 'approved', 'rejected')",
            name=op.f("ck_model_proposals_status_valid"),
        ),
        sa.ForeignKeyConstraint(
            ["exam_code"], ["exams.code"], name=op.f("fk_model_proposals_exam_code_exams")
        ),
        sa.ForeignKeyConstraint(
            ["topic_id"],
            ["topics.id"],
            name=op.f("fk_model_proposals_topic_id_topics"),
            ondelete="CASCADE",
        ),
        sa.ForeignKeyConstraint(
            ["pattern_id"],
            ["question_patterns.id"],
            name=op.f("fk_model_proposals_pattern_id_question_patterns"),
            ondelete="SET NULL",
        ),
        sa.PrimaryKeyConstraint("id", name=op.f("pk_model_proposals")),
        sa.UniqueConstraint("topic_id", "signature", name=op.f("uq_model_proposals_topic_id")),
    )
    op.create_index(
        op.f("ix_model_proposals_exam_code"), "model_proposals", ["exam_code"], unique=False
    )
    op.create_table(
        "concept_hints",
        sa.Column("id", sa.Uuid(), nullable=False),
        sa.Column("exam_code", sa.String(length=32), nullable=False),
        sa.Column("topic_id", sa.Uuid(), nullable=False),
        sa.Column("label", sa.String(length=200), nullable=False),
        sa.Column("question_ids", postgresql.JSONB(astext_type=sa.Text()), nullable=False),
        sa.Column("model", sa.String(length=64), nullable=False),
        sa.Column("prompt_version", sa.String(length=32), nullable=False),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.text("now()"),
            nullable=False,
        ),
        sa.ForeignKeyConstraint(
            ["exam_code"], ["exams.code"], name=op.f("fk_concept_hints_exam_code_exams")
        ),
        sa.ForeignKeyConstraint(
            ["topic_id"],
            ["topics.id"],
            name=op.f("fk_concept_hints_topic_id_topics"),
            ondelete="CASCADE",
        ),
        sa.PrimaryKeyConstraint("id", name=op.f("pk_concept_hints")),
    )
    op.create_index(
        op.f("ix_concept_hints_exam_code"), "concept_hints", ["exam_code"], unique=False
    )
    op.drop_constraint(op.f("ck_ai_generations_task_valid"), "ai_generations", type_="check")
    op.create_check_constraint(
        op.f("ck_ai_generations_task_valid"),
        "ai_generations",
        f"task IN ({TASKS}, 'concept_hint')",
    )


def downgrade() -> None:
    op.execute("DELETE FROM ai_generations WHERE task = 'concept_hint'")
    op.drop_constraint(op.f("ck_ai_generations_task_valid"), "ai_generations", type_="check")
    op.create_check_constraint(
        op.f("ck_ai_generations_task_valid"), "ai_generations", f"task IN ({TASKS})"
    )
    op.drop_index(op.f("ix_concept_hints_exam_code"), table_name="concept_hints")
    op.drop_table("concept_hints")
    op.drop_index(op.f("ix_model_proposals_exam_code"), table_name="model_proposals")
    op.drop_table("model_proposals")
