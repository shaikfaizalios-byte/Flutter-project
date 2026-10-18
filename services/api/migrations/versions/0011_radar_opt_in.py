"""radar opt in

Learners can share their confirmed topic / question-type counts of dated papers with the
Repeat Radar. Off by default; nothing is copied: the Radar reads the counts live, so turning
sharing off (or deleting the account) removes them at once.

Revision ID: 0011
Revises: 0010
Create Date: 2026-10-18 10:00:00

"""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op

# revision identifiers, used by Alembic.
revision: str = "0011"
down_revision: str | Sequence[str] | None = "0010"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    """Upgrade schema."""
    op.add_column(
        "users",
        sa.Column("radar_opt_in", sa.Boolean(), server_default="false", nullable=False),
    )
    op.add_column("users", sa.Column("radar_opt_in_at", sa.DateTime(timezone=True), nullable=True))


def downgrade() -> None:
    """Downgrade schema."""
    op.drop_column("users", "radar_opt_in_at")
    op.drop_column("users", "radar_opt_in")
