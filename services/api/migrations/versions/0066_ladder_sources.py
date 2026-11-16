"""ladder sources

A ladder can now start from more than a topic: from questions in one of the learner's papers or
all of the exam's papers (5 picked at random, reviewed ones first), or from a topic the learner
typed (web references only). `ladder_sessions.basis` says which; `document_id` is the paper,
`seed_question_ids` the questions picked at the start, `unreviewed_seeds` that some of them were
not reviewed yet. Existing ladders are topic ladders.

Revision ID: 0066
Revises: 0065
"""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects import postgresql

revision: str = "0066"
down_revision: str | None = "0065"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.add_column(
        "ladder_sessions",
        sa.Column("basis", sa.String(length=6), server_default="topic", nullable=False),
    )
    op.create_check_constraint(
        op.f("ck_ladder_sessions_basis_valid"),
        "ladder_sessions",
        "basis IN ('topic', 'paper', 'papers', 'typed')",
    )
    op.add_column("ladder_sessions", sa.Column("document_id", sa.Uuid(), nullable=True))
    op.create_foreign_key(
        op.f("fk_ladder_sessions_document_id_documents"),
        "ladder_sessions",
        "documents",
        ["document_id"],
        ["id"],
        ondelete="SET NULL",
    )
    op.add_column(
        "ladder_sessions",
        sa.Column("seed_question_ids", postgresql.ARRAY(sa.Uuid()), nullable=True),
    )
    op.add_column(
        "ladder_sessions",
        sa.Column(
            "unreviewed_seeds", sa.Boolean(), server_default=sa.text("false"), nullable=False
        ),
    )


def downgrade() -> None:
    op.drop_column("ladder_sessions", "unreviewed_seeds")
    op.drop_column("ladder_sessions", "seed_question_ids")
    op.drop_constraint(
        op.f("fk_ladder_sessions_document_id_documents"), "ladder_sessions", type_="foreignkey"
    )
    op.drop_column("ladder_sessions", "document_id")
    op.drop_constraint(op.f("ck_ladder_sessions_basis_valid"), "ladder_sessions", type_="check")
    op.drop_column("ladder_sessions", "basis")
