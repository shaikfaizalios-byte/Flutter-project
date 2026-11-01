"""exam format versions

Exam formats become versions with a review workflow: status draft | verified | retired,
effective dates, the format they supersede, the answer types the paper uses, whether each
section is timed on its own, and who reviewed them. The two existing formats were verified
against their notices when recorded (0003, 0018): they become verified, and a format whose
sections all record a timer (CGL) becomes sectionally timed. Exams gain country, authority and
aliases (catalog data, set by the operator); the catalog exams seeded in 0012 are all Indian
exams, so their country is IN. Authorities are left for the operator to set.

Revision ID: 0032
Revises: 0031
Create Date: 2026-11-01 18:00:00

"""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects import postgresql

# revision identifiers, used by Alembic.
revision: str = "0032"
down_revision: str | Sequence[str] | None = "0031"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None

CATALOG_0012 = (
    "SSC_CGL",
    "SSC_CHSL",
    "SSC_MTS",
    "SSC_GD",
    "SSC_CPO",
    "IBPS_PO",
    "IBPS_CLERK",
    "SBI_PO",
    "SBI_CLERK",
    "RRB_NTPC",
    "RRB_GROUP_D",
    "UPSC_CSE_PRE",
    "NEET_UG",
    "CUET_UG",
)


def upgrade() -> None:
    """Upgrade schema."""
    op.add_column("exams", sa.Column("country_code", sa.String(length=2), nullable=True))
    op.add_column("exams", sa.Column("authority", sa.String(length=120), nullable=True))
    op.add_column(
        "exams",
        sa.Column(
            "aliases", postgresql.ARRAY(sa.String(length=60)), server_default="{}", nullable=False
        ),
    )
    op.create_check_constraint(
        op.f("ck_exams_country_code_iso"),
        "exams",
        "country_code IS NULL OR country_code ~ '^[A-Z]{2}$'",
    )
    exams = sa.table(
        "exams", sa.column("code", sa.String()), sa.column("owner_id"), sa.column("country_code")
    )
    op.execute(
        exams.update()
        .where(exams.c.owner_id.is_(None), exams.c.code.in_(CATALOG_0012))
        .values(country_code="IN")
    )

    op.alter_column("exam_formats", "verified_on", existing_type=sa.Date(), nullable=True)
    op.add_column(
        "exam_formats",
        sa.Column("status", sa.String(length=10), server_default="draft", nullable=False),
    )
    op.add_column("exam_formats", sa.Column("effective_from", sa.Date(), nullable=True))
    op.add_column("exam_formats", sa.Column("effective_to", sa.Date(), nullable=True))
    op.add_column("exam_formats", sa.Column("supersedes_id", sa.Uuid(), nullable=True))
    op.add_column(
        "exam_formats",
        sa.Column(
            "question_types",
            postgresql.ARRAY(sa.String(length=8)),
            server_default="{choice}",
            nullable=False,
        ),
    )
    op.add_column(
        "exam_formats",
        sa.Column("sectional_timing", sa.Boolean(), server_default="false", nullable=False),
    )
    op.add_column("exam_formats", sa.Column("reviewed_by", sa.String(length=100), nullable=True))
    op.add_column("exam_formats", sa.Column("review_notes", sa.String(length=500), nullable=True))
    op.create_foreign_key(
        op.f("fk_exam_formats_supersedes_id_exam_formats"),
        "exam_formats",
        "exam_formats",
        ["supersedes_id"],
        ["id"],
        ondelete="SET NULL",
    )
    # The formats recorded so far were checked against their official notices (0003, 0018).
    op.execute(
        "UPDATE exam_formats SET status = 'verified', "
        "reviewed_by = 'Recorded with its official source in a migration', "
        "sectional_timing = ("
        "  SELECT bool_and(s ? 'timer_minutes') FROM jsonb_array_elements(sections) s"
        ")"
    )
    op.create_check_constraint(
        op.f("ck_exam_formats_status_valid"),
        "exam_formats",
        "status IN ('draft', 'verified', 'retired')",
    )
    op.create_check_constraint(
        op.f("ck_exam_formats_published_is_reviewed"),
        "exam_formats",
        "status = 'draft' OR (verified_on IS NOT NULL AND reviewed_by IS NOT NULL)",
    )
    op.create_check_constraint(
        op.f("ck_exam_formats_effective_range"),
        "exam_formats",
        "effective_to IS NULL OR effective_from IS NULL OR effective_to >= effective_from",
    )


def downgrade() -> None:
    """Downgrade schema."""
    op.execute("DELETE FROM exam_formats WHERE status = 'draft'")
    for name in ("effective_range", "published_is_reviewed", "status_valid"):
        op.drop_constraint(op.f(f"ck_exam_formats_{name}"), "exam_formats", type_="check")
    op.drop_constraint(
        op.f("fk_exam_formats_supersedes_id_exam_formats"), "exam_formats", type_="foreignkey"
    )
    for column in (
        "review_notes",
        "reviewed_by",
        "sectional_timing",
        "question_types",
        "supersedes_id",
        "effective_to",
        "effective_from",
        "status",
    ):
        op.drop_column("exam_formats", column)
    op.alter_column("exam_formats", "verified_on", existing_type=sa.Date(), nullable=False)
    op.drop_constraint(op.f("ck_exams_country_code_iso"), "exams", type_="check")
    for column in ("aliases", "authority", "country_code"):
        op.drop_column("exams", column)
