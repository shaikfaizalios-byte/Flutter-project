"""stages a learner enters for their own exam

Catalog exams keep their stages in exam_formats (sourced, reviewed). A learner's own exam has
no official source, so what they enter is kept apart here and is never shown as verified.

Revision ID: 0043
Revises: 0042
"""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects import postgresql

revision: str = "0043"
down_revision: str | None = "0042"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.add_column(
        "exams", sa.Column("custom_stages", postgresql.JSONB(astext_type=sa.Text()), nullable=True)
    )


def downgrade() -> None:
    op.drop_column("exams", "custom_stages")
