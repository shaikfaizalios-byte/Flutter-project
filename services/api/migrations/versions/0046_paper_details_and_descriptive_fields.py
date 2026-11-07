"""paper details, confirmed duplicates and translations, descriptive fields

Papers record their stage, session, set code and any languages beyond the main one, and can be
marked as another set of the same paper. Questions can be linked as a translation of another, and
carry marks, a word limit, sub-parts and an internal-choice group. A passage says what it is
(text, chart, table or case). All of it is empty for existing rows, so nothing changes.

Revision ID: 0046
Revises: 0045
"""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects import postgresql

revision: str = "0046"
down_revision: str | None = "0045"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.add_column("documents", sa.Column("stage", sa.String(length=60), nullable=True))
    op.add_column("documents", sa.Column("session_label", sa.String(length=40), nullable=True))
    op.add_column("documents", sa.Column("set_code", sa.String(length=20), nullable=True))
    op.add_column(
        "documents",
        sa.Column(
            "extra_languages",
            postgresql.ARRAY(sa.String(length=8)),
            server_default="{}",
            nullable=False,
        ),
    )
    op.add_column("documents", sa.Column("duplicate_of_id", sa.Uuid(), nullable=True))
    op.create_foreign_key(
        op.f("fk_documents_duplicate_of_id_documents"),
        "documents",
        "documents",
        ["duplicate_of_id"],
        ["id"],
        ondelete="SET NULL",
    )
    op.create_index(
        op.f("ix_documents_duplicate_of_id"), "documents", ["duplicate_of_id"], unique=False
    )
    op.add_column("questions", sa.Column("translation_of_id", sa.Uuid(), nullable=True))
    op.create_foreign_key(
        op.f("fk_questions_translation_of_id_questions"),
        "questions",
        "questions",
        ["translation_of_id"],
        ["id"],
        ondelete="SET NULL",
    )
    op.create_index(
        op.f("ix_questions_translation_of_id"), "questions", ["translation_of_id"], unique=False
    )
    op.add_column("questions", sa.Column("marks", sa.Float(), nullable=True))
    op.add_column("questions", sa.Column("word_limit", sa.Integer(), nullable=True))
    op.add_column(
        "questions", sa.Column("sub_parts", postgresql.JSONB(astext_type=sa.Text()), nullable=True)
    )
    op.add_column("questions", sa.Column("choice_group", sa.String(length=20), nullable=True))
    op.add_column(
        "passages",
        sa.Column("kind", sa.String(length=8), server_default="passage", nullable=False),
    )
    op.create_check_constraint(
        "ck_passages_kind_valid", "passages", "kind IN ('passage', 'chart', 'table', 'case')"
    )


def downgrade() -> None:
    op.drop_constraint("ck_passages_kind_valid", "passages", type_="check")
    op.drop_column("passages", "kind")
    for column in ("choice_group", "sub_parts", "word_limit", "marks"):
        op.drop_column("questions", column)
    op.drop_index(op.f("ix_questions_translation_of_id"), table_name="questions")
    op.drop_constraint(
        op.f("fk_questions_translation_of_id_questions"), "questions", type_="foreignkey"
    )
    op.drop_column("questions", "translation_of_id")
    op.drop_index(op.f("ix_documents_duplicate_of_id"), table_name="documents")
    op.drop_constraint(
        op.f("fk_documents_duplicate_of_id_documents"), "documents", type_="foreignkey"
    )
    for column in ("duplicate_of_id", "extra_languages", "set_code", "session_label", "stage"):
        op.drop_column("documents", column)
