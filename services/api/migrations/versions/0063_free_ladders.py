"""free ladders

A learner without PrepLoop Plus may start a set number of Challenge Ladders a day (server setting,
default 1). `ladder_sessions.free` marks those: their first round needs no Plus. Existing
sessions are not free.

Revision ID: 0063
Revises: 0062
"""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op

revision: str = "0063"
down_revision: str | None = "0062"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.add_column(
        "ladder_sessions",
        sa.Column("free", sa.Boolean(), server_default="false", nullable=False),
    )


def downgrade() -> None:
    op.drop_column("ladder_sessions", "free")
