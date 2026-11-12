"""sample papers

`documents.is_sample` marks PrepLoop's made-up sample papers (data/sample_papers) that a learner
added to try the app. They are the learner's own papers, labelled as samples, and never reach
Repeat Radar or the shared bank. Existing papers are not samples.

Revision ID: 0064
Revises: 0063
"""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op

revision: str = "0064"
down_revision: str | None = "0063"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.add_column(
        "documents",
        sa.Column("is_sample", sa.Boolean(), server_default="false", nullable=False),
    )


def downgrade() -> None:
    op.drop_column("documents", "is_sample")
