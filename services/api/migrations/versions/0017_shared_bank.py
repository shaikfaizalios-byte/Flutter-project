"""shared bank

Papers the operator publishes for every learner: `documents.shared_at` with the recorded
rights basis and source (both required while shared). Only verified source questions of a
shared paper are visible to other accounts, read-only.

Revision ID: 0017
Revises: 0016
Create Date: 2026-10-19 22:00:00

"""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op

# revision identifiers, used by Alembic.
revision: str = "0017"
down_revision: str | Sequence[str] | None = "0016"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    """Upgrade schema."""
    op.add_column("documents", sa.Column("shared_at", sa.DateTime(timezone=True), nullable=True))
    op.add_column("documents", sa.Column("shared_rights_basis", sa.String(500), nullable=True))
    op.add_column("documents", sa.Column("shared_source", sa.String(500), nullable=True))
    op.create_check_constraint(
        "shared_needs_rights",
        "documents",
        "shared_at IS NULL OR (length(trim(shared_rights_basis)) > 0"
        " AND length(trim(shared_source)) > 0)",
    )
    op.create_index(
        "ix_documents_shared",
        "documents",
        ["id"],
        postgresql_where=sa.text("shared_at IS NOT NULL"),
    )


def downgrade() -> None:
    """Downgrade schema."""
    op.drop_index("ix_documents_shared", table_name="documents")
    op.drop_constraint("shared_needs_rights", "documents", type_="check")
    op.drop_column("documents", "shared_source")
    op.drop_column("documents", "shared_rights_basis")
    op.drop_column("documents", "shared_at")
