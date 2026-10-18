"""exam short names

Short display names for catalog exams (chips and lists); own exams show their name.

Revision ID: 0014
Revises: 0013
Create Date: 2026-10-19 14:00:00

"""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op

# revision identifiers, used by Alembic.
revision: str = "0014"
down_revision: str | Sequence[str] | None = "0013"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None

SHORT_NAMES = {
    "SSC_CGL": "SSC CGL",
    "SSC_CHSL": "SSC CHSL",
    "SSC_MTS": "SSC MTS",
    "SSC_GD": "SSC GD",
    "SSC_CPO": "SSC CPO",
    "IBPS_PO": "IBPS PO",
    "IBPS_CLERK": "IBPS Clerk",
    "SBI_PO": "SBI PO",
    "SBI_CLERK": "SBI Clerk",
    "RRB_NTPC": "RRB NTPC",
    "RRB_GROUP_D": "RRB Group D",
    "UPSC_CSE_PRE": "UPSC Prelims",
    "NEET_UG": "NEET UG",
    "CUET_UG": "CUET UG",
}


def upgrade() -> None:
    """Upgrade schema."""
    op.add_column("exams", sa.Column("short_name", sa.String(length=40), nullable=True))
    exams = sa.table("exams", sa.column("code", sa.String()), sa.column("short_name", sa.String()))
    connection = op.get_bind()
    for code, short in SHORT_NAMES.items():
        connection.execute(exams.update().where(exams.c.code == code).values(short_name=short))


def downgrade() -> None:
    """Downgrade schema."""
    op.drop_column("exams", "short_name")
