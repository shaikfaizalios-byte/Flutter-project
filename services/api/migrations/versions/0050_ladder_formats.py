"""challenge ladder: question formats and marks

A step keeps its format, the answer of formats that need more than an option index, the learner's
response and the marks it was scored with. A session records whether its app can show the newer
formats. Every existing step is a single-correct question without marks, so nothing changes.

Revision ID: 0050
Revises: 0049
"""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects import postgresql

revision: str = "0050"
down_revision: str | None = "0049"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.add_column(
        "ladder_sessions",
        sa.Column("new_formats", sa.Boolean(), server_default="false", nullable=False),
    )
    op.add_column(
        "ladder_steps",
        sa.Column("format", sa.String(length=20), server_default="single_correct", nullable=False),
    )
    op.add_column("ladder_steps", sa.Column("answer_spec", postgresql.JSONB(astext_type=sa.Text())))
    op.add_column("ladder_steps", sa.Column("response", postgresql.JSONB(astext_type=sa.Text())))
    op.add_column("ladder_steps", sa.Column("marks_correct", sa.Float()))
    op.add_column("ladder_steps", sa.Column("marks_wrong", sa.Float()))
    op.add_column(
        "ladder_steps", sa.Column("partial_rule", postgresql.JSONB(astext_type=sa.Text()))
    )
    op.add_column("ladder_steps", sa.Column("marks_awarded", sa.Float()))


def downgrade() -> None:
    # The older schema can't hold these answers. They are AI practice questions, counted nowhere.
    op.execute("DELETE FROM ladder_steps WHERE answer_spec IS NOT NULL")
    for column in (
        "marks_awarded",
        "partial_rule",
        "marks_wrong",
        "marks_correct",
        "response",
        "answer_spec",
        "format",
    ):
        op.drop_column("ladder_steps", column)
    op.drop_column("ladder_sessions", "new_formats")
