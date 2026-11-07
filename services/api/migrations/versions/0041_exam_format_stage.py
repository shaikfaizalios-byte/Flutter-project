"""exam_formats.tier becomes stage: not every exam has tiers (structural, same values).

Revision ID: 0041
Revises: 0040
"""

from collections.abc import Sequence

from alembic import op

revision: str = "0041"
down_revision: str | None = "0040"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.alter_column("exam_formats", "tier", new_column_name="stage")


def downgrade() -> None:
    op.alter_column("exam_formats", "stage", new_column_name="tier")
