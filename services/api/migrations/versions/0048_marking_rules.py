"""marking rules beyond one negative mark

A format can state its penalty as a share of the question's marks, and name the formats it uses.
Sections can state their own marks in their JSON, so that needs no column. Sessions snapshot marks
for a blank answer and any partial rule, so a later change of format never changes an attempt.
Empty for every existing row, so nothing is marked differently.

Revision ID: 0048
Revises: 0047
"""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects import postgresql

revision: str = "0048"
down_revision: str | None = "0047"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.add_column("exam_formats", sa.Column("penalty_fraction", sa.Float(), nullable=True))
    op.alter_column(
        "exam_formats",
        "question_types",
        type_=postgresql.ARRAY(sa.String(length=20)),
        existing_type=postgresql.ARRAY(sa.String(length=8)),
    )
    op.add_column(
        "session_items",
        sa.Column("marks_unanswered", sa.Float(), server_default="0", nullable=False),
    )
    op.add_column(
        "session_items",
        sa.Column("partial_rule", postgresql.JSONB(astext_type=sa.Text()), nullable=True),
    )


def downgrade() -> None:
    op.drop_column("session_items", "partial_rule")
    op.drop_column("session_items", "marks_unanswered")
    # Formats naming types the older schema can't hold go back to plain choice questions.
    op.execute(
        "UPDATE exam_formats SET question_types = '{choice}' "
        "WHERE NOT question_types <@ ARRAY['choice', 'typed']::varchar[]"
    )
    op.alter_column(
        "exam_formats",
        "question_types",
        type_=postgresql.ARRAY(sa.String(length=8)),
        existing_type=postgresql.ARRAY(sa.String(length=20)),
    )
    op.drop_column("exam_formats", "penalty_fraction")
