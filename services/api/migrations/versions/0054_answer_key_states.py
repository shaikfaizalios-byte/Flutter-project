"""answer-key states, and whole-number answers

A key can be provisional or final, can accept several answers, can drop a question, and remembers
when the final key changed the answer. Sessions snapshot how a question's key stands. A new format,
integer, is added. Existing rows have no key stage and one answer, so nothing is marked differently.

Revision ID: 0054
Revises: 0053
"""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects import postgresql

revision: str = "0054"
down_revision: str | None = "0053"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None

FORMATS_BEFORE = (
    "format IN ('single_correct', 'assertion_reason', 'statement', 'true_false', 'typed_in', "
    "'descriptive', 'multiple_correct', 'match', 'ordering', 'numeric', 'fill_blank')"
)
FORMATS_AFTER = FORMATS_BEFORE.replace("'numeric',", "'numeric', 'integer',")


def upgrade() -> None:
    op.drop_constraint("ck_questions_format_valid", "questions", type_="check")
    op.create_check_constraint("ck_questions_format_valid", "questions", FORMATS_AFTER)
    op.add_column("questions", sa.Column("key_stage", sa.String(length=11), nullable=True))
    op.add_column(
        "questions",
        sa.Column("key_outcome", sa.String(length=7), server_default="one", nullable=False),
    )
    op.add_column(
        "questions", sa.Column("accepted_positions", postgresql.ARRAY(sa.Integer()), nullable=True)
    )
    op.add_column(
        "questions",
        sa.Column("key_changed", sa.Boolean(), server_default="false", nullable=False),
    )
    op.create_check_constraint(
        op.f("ck_questions_key_stage_valid"),
        "questions",
        "key_stage IS NULL OR key_stage IN ('provisional', 'final')",
    )
    op.create_check_constraint(
        op.f("ck_questions_key_outcome_valid"),
        "questions",
        "key_outcome IN ('one', 'several', 'dropped')",
    )
    op.add_column(
        "session_items",
        sa.Column("key_outcome", sa.String(length=7), server_default="one", nullable=False),
    )
    op.add_column(
        "session_items",
        sa.Column("accepted_positions", postgresql.ARRAY(sa.Integer()), nullable=True),
    )
    op.add_column(
        "session_items",
        sa.Column("key_changed", sa.Boolean(), server_default="false", nullable=False),
    )


def downgrade() -> None:
    op.drop_column("session_items", "key_changed")
    op.drop_column("session_items", "accepted_positions")
    op.drop_column("session_items", "key_outcome")
    op.drop_constraint(op.f("ck_questions_key_outcome_valid"), "questions", type_="check")
    op.drop_constraint(op.f("ck_questions_key_stage_valid"), "questions", type_="check")
    op.drop_column("questions", "key_changed")
    op.drop_column("questions", "accepted_positions")
    op.drop_column("questions", "key_outcome")
    op.drop_column("questions", "key_stage")
    # The older schema has no whole-number format: a number with no tolerance marks the same.
    op.execute("UPDATE questions SET format = 'numeric' WHERE format = 'integer'")
    op.execute("UPDATE session_items SET format = 'numeric' WHERE format = 'integer'")
    op.drop_constraint("ck_questions_format_valid", "questions", type_="check")
    op.create_check_constraint("ck_questions_format_valid", "questions", FORMATS_BEFORE)
