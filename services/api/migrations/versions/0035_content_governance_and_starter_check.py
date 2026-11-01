"""content governance and starter check

Content governance: `content_rights` (why a shared paper may be shared and for which uses:
practice, diagnostic), `content_reports` (learners report shared content) and `audit_events`
(operator decisions: publish, take down, resolve, exam formats). Papers already in the shared
bank get a rights record from their recorded basis, for practice only (a starter-check use
must be decided explicitly). Practice sessions gain the "diagnostic" mode (the starter check).

Revision ID: 0035
Revises: 0034
Create Date: 2026-11-01 21:30:00

"""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects import postgresql

# revision identifiers, used by Alembic.
revision: str = "0035"
down_revision: str | Sequence[str] | None = "0034"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    """Upgrade schema."""
    op.create_table(
        "audit_events",
        sa.Column("id", sa.Uuid(), nullable=False),
        sa.Column("actor", sa.String(length=100), nullable=False),
        sa.Column("action", sa.String(length=40), nullable=False),
        sa.Column("target_type", sa.String(length=20), nullable=False),
        sa.Column("target_id", sa.String(length=64), nullable=False),
        sa.Column("detail", sa.String(length=500), server_default="", nullable=False),
        sa.Column(
            "at", sa.DateTime(timezone=True), server_default=sa.text("now()"), nullable=False
        ),
        sa.PrimaryKeyConstraint("id", name=op.f("pk_audit_events")),
    )
    op.create_index(
        "ix_audit_events_target", "audit_events", ["target_type", "target_id"], unique=False
    )
    op.create_table(
        "content_rights",
        sa.Column("document_id", sa.Uuid(), nullable=False),
        sa.Column("rights_holder", sa.String(length=200), nullable=True),
        sa.Column("basis", sa.String(length=500), nullable=False),
        sa.Column("permitted_uses", postgresql.ARRAY(sa.String(length=12)), nullable=False),
        sa.Column("territory", sa.String(length=200), nullable=False),
        sa.Column("attribution", sa.String(length=300), nullable=True),
        sa.Column("review_by", sa.Date(), nullable=True),
        sa.Column("decided_by", sa.String(length=100), nullable=False),
        sa.Column(
            "decided_at",
            sa.DateTime(timezone=True),
            server_default=sa.text("now()"),
            nullable=False,
        ),
        sa.CheckConstraint(
            "permitted_uses <@ ARRAY['practice', 'diagnostic']::varchar[]"
            " AND cardinality(permitted_uses) > 0",
            name=op.f("ck_content_rights_permitted_uses_valid"),
        ),
        sa.CheckConstraint("length(trim(basis)) > 0", name=op.f("ck_content_rights_basis_present")),
        sa.CheckConstraint(
            "length(trim(decided_by)) > 0", name=op.f("ck_content_rights_decided_by_present")
        ),
        sa.ForeignKeyConstraint(
            ["document_id"],
            ["documents.id"],
            name=op.f("fk_content_rights_document_id_documents"),
            ondelete="CASCADE",
        ),
        sa.PrimaryKeyConstraint("document_id", name=op.f("pk_content_rights")),
    )
    op.create_table(
        "content_reports",
        sa.Column("id", sa.Uuid(), nullable=False),
        sa.Column("owner_id", sa.Uuid(), nullable=False),
        sa.Column("document_id", sa.Uuid(), nullable=True),
        sa.Column("question_id", sa.Uuid(), nullable=True),
        sa.Column("kind", sa.String(length=8), nullable=False),
        sa.Column("text", sa.Text(), nullable=False),
        sa.Column("status", sa.String(length=10), server_default="open", nullable=False),
        sa.Column("resolution", sa.String(length=500), nullable=True),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.text("now()"),
            nullable=False,
        ),
        sa.Column("resolved_at", sa.DateTime(timezone=True), nullable=True),
        sa.CheckConstraint(
            "kind IN ('rights', 'error', 'other')", name=op.f("ck_content_reports_kind_valid")
        ),
        sa.CheckConstraint(
            "status IN ('open', 'upheld', 'dismissed')",
            name=op.f("ck_content_reports_status_valid"),
        ),
        sa.CheckConstraint("length(trim(text)) > 0", name=op.f("ck_content_reports_text_present")),
        sa.ForeignKeyConstraint(
            ["document_id"],
            ["documents.id"],
            name=op.f("fk_content_reports_document_id_documents"),
            ondelete="SET NULL",
        ),
        sa.ForeignKeyConstraint(
            ["owner_id"],
            ["users.id"],
            name=op.f("fk_content_reports_owner_id_users"),
            ondelete="CASCADE",
        ),
        sa.ForeignKeyConstraint(
            ["question_id"],
            ["questions.id"],
            name=op.f("fk_content_reports_question_id_questions"),
            ondelete="SET NULL",
        ),
        sa.PrimaryKeyConstraint("id", name=op.f("pk_content_reports")),
    )
    op.create_index(
        op.f("ix_content_reports_document_id"), "content_reports", ["document_id"], unique=False
    )
    op.create_index(
        op.f("ix_content_reports_owner_id"), "content_reports", ["owner_id"], unique=False
    )
    op.create_index(
        "ix_content_reports_status_created",
        "content_reports",
        ["status", "created_at"],
        unique=False,
    )
    op.execute(
        "INSERT INTO content_rights (document_id, basis, permitted_uses, territory, decided_by,"
        " decided_at) SELECT id, shared_rights_basis, ARRAY['practice']::varchar[],"
        " 'not recorded', 'recorded before content rights (migration 0035)', shared_at"
        " FROM documents WHERE shared_at IS NOT NULL"
    )
    op.drop_constraint(op.f("ck_practice_sessions_mode_valid"), "practice_sessions", type_="check")
    op.create_check_constraint(
        op.f("ck_practice_sessions_mode_valid"),
        "practice_sessions",
        "mode IN ('practice', 'mock', 'diagnostic')",
    )


def downgrade() -> None:
    """Downgrade schema."""
    op.execute("DELETE FROM practice_sessions WHERE mode = 'diagnostic'")
    op.drop_constraint(op.f("ck_practice_sessions_mode_valid"), "practice_sessions", type_="check")
    op.create_check_constraint(
        op.f("ck_practice_sessions_mode_valid"), "practice_sessions", "mode IN ('practice', 'mock')"
    )
    op.drop_index("ix_content_reports_status_created", table_name="content_reports")
    op.drop_index(op.f("ix_content_reports_owner_id"), table_name="content_reports")
    op.drop_index(op.f("ix_content_reports_document_id"), table_name="content_reports")
    op.drop_table("content_reports")
    op.drop_table("content_rights")
    op.drop_index("ix_audit_events_target", table_name="audit_events")
    op.drop_table("audit_events")
