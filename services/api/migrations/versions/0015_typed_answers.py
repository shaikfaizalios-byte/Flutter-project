"""typed answers

Questions answered by typing (TITA, e.g. CAT): `answer_type` ('choice' | 'typed') and the
expected `typed_answer` as text; practice snapshots and answers carry them too.

Revision ID: 0015
Revises: 0014
Create Date: 2026-10-19 18:00:00

"""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op

# revision identifiers, used by Alembic.
revision: str = "0015"
down_revision: str | Sequence[str] | None = "0014"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    """Upgrade schema."""
    op.add_column(
        "questions",
        sa.Column("answer_type", sa.String(length=8), server_default="choice", nullable=False),
    )
    op.add_column("questions", sa.Column("typed_answer", sa.String(length=100), nullable=True))
    op.create_check_constraint(
        op.f("ck_questions_answer_type_valid"), "questions", "answer_type IN ('choice', 'typed')"
    )
    op.create_check_constraint(
        op.f("ck_questions_typed_has_no_option_answer"),
        "questions",
        "answer_type = 'choice' OR correct_option_position IS NULL",
    )
    op.create_check_constraint(
        op.f("ck_questions_typed_answer_only_typed"),
        "questions",
        "answer_type = 'typed' OR typed_answer IS NULL",
    )
    op.add_column(
        "session_items",
        sa.Column("answer_type", sa.String(length=8), server_default="choice", nullable=False),
    )
    op.add_column("session_items", sa.Column("typed_answer", sa.String(length=100), nullable=True))
    op.alter_column("session_items", "correct_position", existing_type=sa.Integer(), nullable=True)
    op.add_column(
        "session_answers", sa.Column("typed_answer", sa.String(length=100), nullable=True)
    )


def downgrade() -> None:
    """Downgrade schema."""
    # Typed questions and their practice items have no place in the old model.
    op.execute("DELETE FROM session_answers WHERE typed_answer IS NOT NULL")
    op.execute("DELETE FROM session_items WHERE answer_type = 'typed'")
    op.drop_column("session_answers", "typed_answer")
    op.alter_column("session_items", "correct_position", existing_type=sa.Integer(), nullable=False)
    op.drop_column("session_items", "typed_answer")
    op.drop_column("session_items", "answer_type")
    op.drop_constraint(op.f("ck_questions_typed_answer_only_typed"), "questions", type_="check")
    op.drop_constraint(op.f("ck_questions_typed_has_no_option_answer"), "questions", type_="check")
    op.drop_constraint(op.f("ck_questions_answer_type_valid"), "questions", type_="check")
    op.drop_column("questions", "typed_answer")
    op.drop_column("questions", "answer_type")
