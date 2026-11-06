"""question formats

Every question gets a format. Existing ones keep behaving as they do: choice questions become
single_correct, typed-in ones typed_in and written ones descriptive. New formats keep their
answer in answer_spec; sessions snapshot both, and answers that aren't one option or a typed text
go in session_answers.response.

Revision ID: 0045
Revises: 0044
"""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects import postgresql

revision: str = "0045"
down_revision: str | None = "0044"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None

FORMATS = (
    "'single_correct', 'assertion_reason', 'statement', 'true_false', 'typed_in', 'descriptive', "
    "'multiple_correct', 'match', 'ordering', 'numeric', 'fill_blank'"
)


def upgrade() -> None:
    for table in ("questions", "session_items"):
        op.add_column(
            table,
            sa.Column(
                "format", sa.String(length=20), server_default="single_correct", nullable=False
            ),
        )
        op.add_column(
            table, sa.Column("answer_spec", postgresql.JSONB(astext_type=sa.Text()), nullable=True)
        )
        op.execute(f"UPDATE {table} SET format = 'typed_in' WHERE answer_type = 'typed'")
    op.execute("UPDATE questions SET format = 'descriptive' WHERE answer_type = 'written'")
    op.create_check_constraint("ck_questions_format_valid", "questions", f"format IN ({FORMATS})")
    op.add_column(
        "session_answers",
        sa.Column("response", postgresql.JSONB(astext_type=sa.Text()), nullable=True),
    )


def downgrade() -> None:
    # Questions only a format can mark have no place in the older schema.
    op.execute(
        "DELETE FROM session_answers WHERE session_id IN "
        "(SELECT session_id FROM session_items WHERE answer_spec IS NOT NULL)"
    )
    op.execute("DELETE FROM session_items WHERE answer_spec IS NOT NULL")
    op.execute("DELETE FROM questions WHERE answer_spec IS NOT NULL")
    op.drop_column("session_answers", "response")
    op.drop_constraint("ck_questions_format_valid", "questions", type_="check")
    for table in ("session_items", "questions"):
        op.drop_column(table, "answer_spec")
        op.drop_column(table, "format")
