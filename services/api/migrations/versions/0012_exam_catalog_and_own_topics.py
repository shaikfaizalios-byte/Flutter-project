"""exam catalog and own topics

Exams become a catalog (names and grouping only, added by data migrations) plus private exams
a learner creates. Topics gain an owner (NULL = shared taxonomy) and the exams they apply to.

The catalog stores *names only*: no patterns, question counts or marking schemes (those come
only from verified `exam_formats`). The existing shared taxonomy (reasoning, quantitative
aptitude, English, general awareness) is linked to the catalog exams whose papers use those
subjects; other exams start with no shared topics and learners add their own.

Revision ID: 0012
Revises: 0011
Create Date: 2026-10-19 10:00:00

"""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects import postgresql

# revision identifiers, used by Alembic.
revision: str = "0012"
down_revision: str | Sequence[str] | None = "0011"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None

# (code, name, category, featured, sort_order)
CATALOG = [
    ("SSC_CGL", "SSC Combined Graduate Level", "Staff Selection", True, 10),
    ("SSC_CHSL", "SSC Combined Higher Secondary Level", "Staff Selection", True, 20),
    ("SSC_MTS", "SSC Multi-Tasking Staff", "Staff Selection", False, 30),
    ("SSC_GD", "SSC GD Constable", "Staff Selection", False, 40),
    ("SSC_CPO", "SSC CPO (Sub-Inspector)", "Staff Selection", False, 50),
    ("IBPS_PO", "IBPS PO", "Banking", False, 110),
    ("IBPS_CLERK", "IBPS Clerk", "Banking", False, 120),
    ("SBI_PO", "SBI PO", "Banking", False, 130),
    ("SBI_CLERK", "SBI Clerk", "Banking", False, 140),
    ("RRB_NTPC", "RRB NTPC", "Railways", False, 210),
    ("RRB_GROUP_D", "RRB Group D", "Railways", False, 220),
    ("UPSC_CSE_PRE", "UPSC Civil Services (Prelims)", "Civil Services", False, 310),
    ("NEET_UG", "NEET UG", "Entrance", False, 410),
    ("CUET_UG", "CUET UG", "Entrance", False, 420),
]
NEW_CODES = [c for c, *_ in CATALOG if c not in ("SSC_CGL", "SSC_CHSL")]
# Catalog exams whose papers use the shared aptitude-style taxonomy.
SHARED_TAXONOMY_EXAMS = [
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
]

_exams = sa.table(
    "exams",
    sa.column("code", sa.String()),
    sa.column("name", sa.String()),
    sa.column("category", sa.String()),
    sa.column("featured", sa.Boolean()),
    sa.column("sort_order", sa.Integer()),
)


def upgrade() -> None:
    """Upgrade schema."""
    op.add_column("exams", sa.Column("owner_id", sa.Uuid(), nullable=True))
    op.add_column("exams", sa.Column("category", sa.String(length=40), nullable=True))
    op.add_column(
        "exams", sa.Column("featured", sa.Boolean(), server_default="false", nullable=False)
    )
    op.add_column(
        "exams", sa.Column("sort_order", sa.Integer(), server_default="100", nullable=False)
    )
    op.create_index(op.f("ix_exams_owner_id"), "exams", ["owner_id"], unique=False)
    op.create_foreign_key(
        op.f("fk_exams_owner_id_users"), "exams", "users", ["owner_id"], ["id"], ondelete="CASCADE"
    )

    op.add_column("topics", sa.Column("owner_id", sa.Uuid(), nullable=True))
    op.add_column(
        "topics", sa.Column("exam_codes", postgresql.ARRAY(sa.String(length=32)), nullable=True)
    )
    op.create_index(op.f("ix_topics_owner_id"), "topics", ["owner_id"], unique=False)
    op.create_foreign_key(
        op.f("fk_topics_owner_id_users"),
        "topics",
        "users",
        ["owner_id"],
        ["id"],
        ondelete="CASCADE",
    )
    op.drop_constraint("uq_topics_subject_name", "topics", type_="unique")
    op.create_unique_constraint(
        "uq_topics_scope_subject_name",
        "topics",
        ["owner_id", "exam_codes", "subject", "name"],
        postgresql_nulls_not_distinct=True,
    )

    connection = op.get_bind()
    existing = {row.code for row in connection.execute(sa.select(_exams.c.code))}
    for code, name, category, featured, order in CATALOG:
        if code in existing:
            connection.execute(
                _exams.update()
                .where(_exams.c.code == code)
                .values(category=category, featured=featured, sort_order=order)
            )
        else:
            connection.execute(
                _exams.insert().values(
                    code=code, name=name, category=category, featured=featured, sort_order=order
                )
            )
    connection.execute(
        sa.text("UPDATE topics SET exam_codes = :codes WHERE owner_id IS NULL").bindparams(
            sa.bindparam("codes", SHARED_TAXONOMY_EXAMS, type_=postgresql.ARRAY(sa.String()))
        )
    )


def downgrade() -> None:
    """Downgrade schema."""
    connection = op.get_bind()
    # Learners' own exams and topics have no place in the old model.
    connection.execute(sa.text("DELETE FROM topics WHERE owner_id IS NOT NULL"))
    connection.execute(
        sa.text(
            "UPDATE questions SET topic_status = 'unassigned', topic_suggested_by = NULL"
            " WHERE topic_id IS NULL AND topic_status <> 'unassigned'"
        )
    )
    op.drop_constraint("uq_topics_scope_subject_name", "topics", type_="unique")
    op.create_unique_constraint("uq_topics_subject_name", "topics", ["subject", "name"])
    op.drop_constraint(op.f("fk_topics_owner_id_users"), "topics", type_="foreignkey")
    op.drop_index(op.f("ix_topics_owner_id"), table_name="topics")
    op.drop_column("topics", "exam_codes")
    op.drop_column("topics", "owner_id")

    # Remove catalog exams added here only if nothing refers to them.
    for code in NEW_CODES:
        connection.execute(
            sa.text(
                "DELETE FROM exams WHERE code = :code"
                " AND NOT EXISTS (SELECT 1 FROM documents WHERE exam_code = :code)"
                " AND NOT EXISTS (SELECT 1 FROM questions WHERE exam_code = :code)"
                " AND NOT EXISTS (SELECT 1 FROM concepts WHERE exam_code = :code)"
                " AND NOT EXISTS (SELECT 1 FROM exam_formats WHERE exam_code = :code)"
            ).bindparams(code=code)
        )
    connection.execute(sa.text("DELETE FROM exams WHERE owner_id IS NOT NULL"))
    op.drop_constraint(op.f("fk_exams_owner_id_users"), "exams", type_="foreignkey")
    op.drop_index(op.f("ix_exams_owner_id"), table_name="exams")
    op.drop_column("exams", "sort_order")
    op.drop_column("exams", "featured")
    op.drop_column("exams", "category")
    op.drop_column("exams", "owner_id")
