"""written questions

Questions may now be "written" (Q&A notes, interview questions): no options, the answer as
written in the notes in model_answer. Only written questions have one (CHECK).

Revision ID: 0026
Revises: 0025
Create Date: 2026-10-25 20:00:00

"""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op

# revision identifiers, used by Alembic.
revision: str = "0026"
down_revision: str | Sequence[str] | None = "0025"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    """Upgrade schema."""
    op.add_column("questions", sa.Column("model_answer", sa.Text(), nullable=True))
    op.drop_constraint(op.f("ck_questions_answer_type_valid"), "questions", type_="check")
    op.create_check_constraint(
        op.f("ck_questions_answer_type_valid"),
        "questions",
        "answer_type IN ('choice', 'typed', 'written')",
    )
    op.create_check_constraint(
        op.f("ck_questions_model_answer_only_written"),
        "questions",
        "answer_type = 'written' OR model_answer IS NULL",
    )


def downgrade() -> None:
    """Downgrade schema."""
    op.execute("DELETE FROM questions WHERE answer_type = 'written'")
    op.drop_constraint(op.f("ck_questions_model_answer_only_written"), "questions", type_="check")
    op.drop_constraint(op.f("ck_questions_answer_type_valid"), "questions", type_="check")
    op.create_check_constraint(
        op.f("ck_questions_answer_type_valid"), "questions", "answer_type IN ('choice', 'typed')"
    )
    op.drop_column("questions", "model_answer")
