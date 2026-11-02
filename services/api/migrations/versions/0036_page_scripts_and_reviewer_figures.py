"""page scripts and reviewer figures

Each page records the script of its text (devanagari | latin | mixed | none), and pages get two
new review reasons (two_columns, devanagari_in_english_document; app/domain/page_analysis.py).
Question figures record where they came from: found in the PDF's objects ("pdf", every
existing figure) or a region a reviewer marked on the page ("reviewer"), which is how scanned
pages get their diagrams.

Revision ID: 0036
Revises: 0035
Create Date: 2026-11-01 23:00:00

"""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op

# revision identifiers, used by Alembic.
revision: str = "0036"
down_revision: str | Sequence[str] | None = "0035"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    """Upgrade schema."""
    op.add_column("document_pages", sa.Column("script", sa.String(length=10), nullable=True))
    op.add_column(
        "question_figures",
        sa.Column("source", sa.String(length=10), server_default="pdf", nullable=False),
    )
    op.create_check_constraint(
        op.f("ck_question_figures_source_valid"),
        "question_figures",
        "source IN ('pdf', 'reviewer')",
    )


def downgrade() -> None:
    """Downgrade schema."""
    op.drop_constraint(op.f("ck_question_figures_source_valid"), "question_figures", type_="check")
    op.drop_column("question_figures", "source")
    op.drop_column("document_pages", "script")
