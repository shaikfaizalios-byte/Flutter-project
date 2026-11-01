"""device sessions

A signed-in device is a refresh-token family. Each token now records the kind of device the
app runs on (android, ios, web, windows, macos, linux; no device name or model), so the
learner can see their signed-in devices and sign any of them out.

Revision ID: 0029
Revises: 0028
Create Date: 2026-11-01 10:00:00

"""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op

# revision identifiers, used by Alembic.
revision: str = "0029"
down_revision: str | Sequence[str] | None = "0028"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    """Upgrade schema."""
    op.add_column("refresh_tokens", sa.Column("platform", sa.String(length=8), nullable=True))
    op.create_check_constraint(
        op.f("ck_refresh_tokens_platform_valid"),
        "refresh_tokens",
        "platform IS NULL OR platform IN ('android', 'ios', 'web', 'windows', 'macos', 'linux')",
    )


def downgrade() -> None:
    """Downgrade schema."""
    op.drop_constraint(op.f("ck_refresh_tokens_platform_valid"), "refresh_tokens", type_="check")
    op.drop_column("refresh_tokens", "platform")
