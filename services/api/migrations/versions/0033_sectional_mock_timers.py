"""sectional mock timers

Mocks of a sectionally timed format take their sections in order, each with its own timer
(app/domain/sections.py). The section plan is copied into the session's selection when the
mock starts; these columns hold which section is open and when it opened. Existing sessions
are unaffected (both stay NULL: one overall timer, as before).

Revision ID: 0033
Revises: 0032
Create Date: 2026-11-01 19:00:00

"""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op

# revision identifiers, used by Alembic.
revision: str = "0033"
down_revision: str | Sequence[str] | None = "0032"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    """Upgrade schema."""
    op.add_column("practice_sessions", sa.Column("current_section", sa.Integer(), nullable=True))
    op.add_column(
        "practice_sessions",
        sa.Column("section_started_at", sa.DateTime(timezone=True), nullable=True),
    )


def downgrade() -> None:
    """Downgrade schema."""
    op.drop_column("practice_sessions", "section_started_at")
    op.drop_column("practice_sessions", "current_section")
