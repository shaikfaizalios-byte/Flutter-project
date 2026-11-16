"""fixed paper percentile

A percentile is shown only for a paper every learner takes identically: the weekly fixed mock,
built from shared-bank questions with the same seed for everyone. `practice_sessions.fixed_key`
names that paper (week + the questions' fingerprint); `users.percentile_opt_in` is the learner's
choice to compare and be compared (off by default). Random mocks get no percentile any more.

Revision ID: 0067
Revises: 0066
"""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op

revision: str = "0067"
down_revision: str | None = "0066"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.add_column("practice_sessions", sa.Column("fixed_key", sa.String(length=120), nullable=True))
    op.create_index(
        op.f("ix_practice_sessions_fixed_key"), "practice_sessions", ["fixed_key"], unique=False
    )
    op.add_column(
        "users",
        sa.Column(
            "percentile_opt_in", sa.Boolean(), server_default=sa.text("false"), nullable=False
        ),
    )


def downgrade() -> None:
    op.drop_column("users", "percentile_opt_in")
    op.drop_index(op.f("ix_practice_sessions_fixed_key"), table_name="practice_sessions")
    op.drop_column("practice_sessions", "fixed_key")
