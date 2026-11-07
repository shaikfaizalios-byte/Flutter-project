"""official question and option IDs

Papers published with their own IDs let an answer key match by ID, and let two language versions
be recognised as one question. Null for every existing row.

Revision ID: 0055
Revises: 0054
"""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op

revision: str = "0055"
down_revision: str | None = "0054"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.add_column("questions", sa.Column("external_id", sa.String(length=24), nullable=True))
    op.create_index(op.f("ix_questions_external_id"), "questions", ["external_id"])
    op.add_column("question_options", sa.Column("external_id", sa.String(length=24), nullable=True))


def downgrade() -> None:
    op.drop_column("question_options", "external_id")
    op.drop_index(op.f("ix_questions_external_id"), table_name="questions")
    op.drop_column("questions", "external_id")
