"""age confirmation

Sign-up now requires confirming the minimum age; `users.age_confirmed_at` records when.
Accounts created before the check keep NULL.

Revision ID: 0016
Revises: 0015
Create Date: 2026-10-19 21:00:00

"""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op

# revision identifiers, used by Alembic.
revision: str = "0016"
down_revision: str | Sequence[str] | None = "0015"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    """Upgrade schema."""
    op.add_column("users", sa.Column("age_confirmed_at", sa.DateTime(timezone=True), nullable=True))


def downgrade() -> None:
    """Downgrade schema."""
    op.drop_column("users", "age_confirmed_at")
