"""create exams and concepts

Revision ID: 0001
Revises:
Create Date: 2026-10-12 20:48:18.569047

"""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects import postgresql

revision: str = "0001"
down_revision: str | None = None
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None

# Reference data only: exam identity. Sections, tiers and marking schemes are separate,
# verified configuration added in later phases.
INITIAL_EXAMS = [
    {"code": "SSC_CGL", "name": "SSC Combined Graduate Level"},
    {"code": "SSC_CHSL", "name": "SSC Combined Higher Secondary Level"},
]


def upgrade() -> None:
    exams = op.create_table(
        "exams",
        sa.Column("code", sa.String(length=32), nullable=False),
        sa.Column("name", sa.String(length=100), nullable=False),
        sa.Column("is_active", sa.Boolean(), server_default="true", nullable=False),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.text("now()"),
            nullable=False,
        ),
        sa.PrimaryKeyConstraint("code", name=op.f("pk_exams")),
    )
    op.create_table(
        "concepts",
        sa.Column("id", sa.Uuid(), nullable=False),
        sa.Column("exam_code", sa.String(length=32), nullable=False),
        sa.Column("title", sa.String(length=200), nullable=False),
        sa.Column("notes", sa.Text(), server_default="", nullable=False),
        sa.Column("subject", sa.String(length=100), nullable=False),
        sa.Column("topic", sa.String(length=100), nullable=False),
        sa.Column("subtopic", sa.String(length=100), nullable=True),
        sa.Column("language", sa.String(length=8), nullable=False),
        sa.Column(
            "tags", postgresql.ARRAY(sa.String(length=50)), server_default="{}", nullable=False
        ),
        sa.Column("source_reference", sa.String(length=500), nullable=True),
        sa.Column("archived_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.text("now()"),
            nullable=False,
        ),
        sa.Column(
            "updated_at",
            sa.DateTime(timezone=True),
            server_default=sa.text("now()"),
            nullable=False,
        ),
        sa.CheckConstraint("language IN ('en', 'hi')", name=op.f("ck_concepts_language_supported")),
        sa.CheckConstraint(
            "char_length(btrim(title)) > 0", name=op.f("ck_concepts_title_not_blank")
        ),
        sa.ForeignKeyConstraint(
            ["exam_code"],
            ["exams.code"],
            name=op.f("fk_concepts_exam_code_exams"),
            ondelete="RESTRICT",
        ),
        sa.PrimaryKeyConstraint("id", name=op.f("pk_concepts")),
    )
    op.create_index("ix_concepts_exam_archived", "concepts", ["exam_code", "archived_at"])
    op.create_index("ix_concepts_tags", "concepts", ["tags"], postgresql_using="gin")
    op.bulk_insert(exams, INITIAL_EXAMS)


def downgrade() -> None:
    op.drop_index("ix_concepts_tags", table_name="concepts", postgresql_using="gin")
    op.drop_index("ix_concepts_exam_archived", table_name="concepts")
    op.drop_table("concepts")
    op.drop_table("exams")
