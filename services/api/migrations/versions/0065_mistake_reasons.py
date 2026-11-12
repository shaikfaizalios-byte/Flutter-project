"""mistake reasons

`session_answers.mistake_reason`: after a wrong answer the learner may tap why it went wrong
(didn't know, calculation slip, misread, ran out of time, guessed). Optional; counted by topic in
analytics. Existing answers have none.

Revision ID: 0065
Revises: 0064
"""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op

revision: str = "0065"
down_revision: str | None = "0064"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.add_column(
        "session_answers", sa.Column("mistake_reason", sa.String(length=16), nullable=True)
    )
    op.create_check_constraint(
        op.f("ck_session_answers_mistake_reason_valid"),
        "session_answers",
        "mistake_reason IS NULL OR mistake_reason IN "
        "('didnt_know', 'calculation', 'misread', 'time', 'guessed')",
    )


def downgrade() -> None:
    op.drop_constraint(
        op.f("ck_session_answers_mistake_reason_valid"), "session_answers", type_="check"
    )
    op.drop_column("session_answers", "mistake_reason")
