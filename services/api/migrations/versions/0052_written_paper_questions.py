"""written practice on real paper questions

A session can use the learner's own reviewed written questions instead of AI-written ones. A step
records the question it came from and whether its model answer is the paper's. Every existing row
is AI-written, so nothing changes.

Revision ID: 0052
Revises: 0051
"""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op

revision: str = "0052"
down_revision: str | None = "0051"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.add_column(
        "descriptive_sessions",
        sa.Column("source", sa.String(length=6), server_default="ai", nullable=False),
    )
    op.create_check_constraint(
        op.f("ck_descriptive_sessions_source_valid"),
        "descriptive_sessions",
        "source IN ('ai', 'papers')",
    )
    op.add_column("descriptive_steps", sa.Column("question_id", sa.Uuid(), nullable=True))
    op.create_foreign_key(
        op.f("fk_descriptive_steps_question_id_questions"),
        "descriptive_steps",
        "questions",
        ["question_id"],
        ["id"],
        ondelete="SET NULL",
    )
    op.add_column("descriptive_steps", sa.Column("paper_label", sa.String(length=300)))
    op.add_column(
        "descriptive_steps",
        sa.Column("answer_from_paper", sa.Boolean(), server_default="false", nullable=False),
    )


def downgrade() -> None:
    # The older schema would show these real questions as AI-written ones.
    op.execute("DELETE FROM descriptive_sessions WHERE source = 'papers'")
    op.drop_column("descriptive_steps", "answer_from_paper")
    op.drop_column("descriptive_steps", "paper_label")
    op.drop_constraint(
        op.f("fk_descriptive_steps_question_id_questions"), "descriptive_steps", type_="foreignkey"
    )
    op.drop_column("descriptive_steps", "question_id")
    op.drop_constraint(
        op.f("ck_descriptive_sessions_source_valid"), "descriptive_sessions", type_="check"
    )
    op.drop_column("descriptive_sessions", "source")
