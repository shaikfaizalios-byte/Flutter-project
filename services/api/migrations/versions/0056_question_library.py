"""the curated question library

A library entry sits on a question and records its source, rights, people, review state and
versions. A question written for the library has no paper, so it gets its own origin. Content staff
are accounts with a role. Nothing existing changes.

Revision ID: 0056
Revises: 0055
"""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects import postgresql

revision: str = "0056"
down_revision: str | None = "0055"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.add_column("users", sa.Column("content_role", sa.String(length=10), nullable=True))
    op.create_check_constraint(
        op.f("ck_users_content_role_valid"),
        "users",
        "content_role IS NULL OR content_role IN ('editor')",
    )
    op.drop_constraint(op.f("ck_questions_origin_valid"), "questions", type_="check")
    op.create_check_constraint(
        op.f("ck_questions_origin_valid"), "questions", "origin IN ('source', 'ai', 'library')"
    )
    op.execute("CREATE SEQUENCE library_seq")
    op.create_table(
        "library_entries",
        sa.Column("question_id", sa.Uuid(), nullable=False),
        sa.Column("source_type", sa.String(length=20), nullable=False),
        sa.Column("rights_status", sa.String(length=8), nullable=False),
        sa.Column("rights_note", sa.String(length=500), nullable=True),
        sa.Column("author_id", sa.Uuid(), nullable=True),
        sa.Column("author_name", sa.String(length=200), nullable=False),
        sa.Column("status", sa.String(length=9), nullable=False),
        sa.Column("solved_by_id", sa.Uuid(), nullable=True),
        sa.Column("solved_by_name", sa.String(length=200), nullable=True),
        sa.Column("approved_by_id", sa.Uuid(), nullable=True),
        sa.Column("approved_by_name", sa.String(length=200), nullable=True),
        sa.Column("version", sa.Integer(), server_default="1", nullable=False),
        sa.Column("exam_year", sa.Integer(), nullable=True),
        sa.Column("difficulty", sa.String(length=6), nullable=False),
        sa.Column("observed_difficulty", sa.String(length=6), nullable=True),
        sa.Column("attempts", sa.Integer(), server_default="0", nullable=False),
        sa.Column("correct_count", sa.Integer(), server_default="0", nullable=False),
        sa.Column("median_ms", sa.Integer(), nullable=True),
        sa.Column("calibrated_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column(
            "seq", sa.BigInteger(), server_default=sa.text("nextval('library_seq')"), nullable=False
        ),
        sa.Column(
            "created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False
        ),
        sa.CheckConstraint(
            "source_type IN ('official_pyq', 'original_expert', 'original_ai_verified')",
            name=op.f("ck_library_entries_source_type_valid"),
        ),
        sa.CheckConstraint(
            "rights_status IN ('licensed', 'owned', 'pending')",
            name=op.f("ck_library_entries_rights_status_valid"),
        ),
        sa.CheckConstraint(
            "status IN ('draft', 'solved', 'approved', 'withdrawn')",
            name=op.f("ck_library_entries_status_valid"),
        ),
        sa.CheckConstraint(
            "difficulty IN ('easy', 'medium', 'hard')",
            name=op.f("ck_library_entries_difficulty_valid"),
        ),
        sa.ForeignKeyConstraint(
            ["approved_by_id"],
            ["users.id"],
            name=op.f("fk_library_entries_approved_by_id_users"),
            ondelete="SET NULL",
        ),
        sa.ForeignKeyConstraint(
            ["author_id"],
            ["users.id"],
            name=op.f("fk_library_entries_author_id_users"),
            ondelete="SET NULL",
        ),
        sa.ForeignKeyConstraint(
            ["question_id"],
            ["questions.id"],
            name=op.f("fk_library_entries_question_id_questions"),
            ondelete="CASCADE",
        ),
        sa.ForeignKeyConstraint(
            ["solved_by_id"],
            ["users.id"],
            name=op.f("fk_library_entries_solved_by_id_users"),
            ondelete="SET NULL",
        ),
        sa.PrimaryKeyConstraint("question_id", name=op.f("pk_library_entries")),
    )
    op.create_index(op.f("ix_library_entries_seq"), "library_entries", ["seq"])
    op.create_table(
        "library_versions",
        sa.Column("question_id", sa.Uuid(), nullable=False),
        sa.Column("version", sa.Integer(), nullable=False),
        sa.Column("snapshot", postgresql.JSONB(astext_type=sa.Text()), nullable=False),
        sa.Column("changed_by", sa.String(length=200), nullable=False),
        sa.Column("reason", sa.String(length=500), nullable=False),
        sa.Column(
            "created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False
        ),
        sa.ForeignKeyConstraint(
            ["question_id"],
            ["library_entries.question_id"],
            name=op.f("fk_library_versions_question_id_library_entries"),
            ondelete="CASCADE",
        ),
        sa.PrimaryKeyConstraint("question_id", "version", name=op.f("pk_library_versions")),
    )


def downgrade() -> None:
    op.drop_table("library_versions")
    op.drop_index(op.f("ix_library_entries_seq"), table_name="library_entries")
    op.drop_table("library_entries")
    op.execute("DROP SEQUENCE library_seq")
    # Questions written for the library have no paper, so the older schema can't hold them.
    op.execute("DELETE FROM questions WHERE origin = 'library'")
    op.drop_constraint(op.f("ck_questions_origin_valid"), "questions", type_="check")
    op.create_check_constraint(
        op.f("ck_questions_origin_valid"), "questions", "origin IN ('source', 'ai')"
    )
    op.drop_constraint(op.f("ck_users_content_role_valid"), "users", type_="check")
    op.drop_column("users", "content_role")
