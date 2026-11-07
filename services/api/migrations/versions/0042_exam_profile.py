"""exam profile fields on exams

What sets one exam apart: its kind, options per question, repeat thresholds and counting unit.
NULL means the defaults (data/exam_templates/defaults.json). SSC CGL and CHSL get today's values
written out, so a later change of the defaults can't change them. options_per_question 0 means
it varies from paper to paper.

Revision ID: 0042
Revises: 0041
"""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects import postgresql

revision: str = "0042"
down_revision: str | None = "0041"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.add_column("exams", sa.Column("kind", sa.String(length=12), nullable=True))
    op.add_column("exams", sa.Column("options_per_question", sa.SmallInteger(), nullable=True))
    op.add_column("exams", sa.Column("repeat_share", sa.Float(), nullable=True))
    op.add_column("exams", sa.Column("min_papers", sa.SmallInteger(), nullable=True))
    op.add_column("exams", sa.Column("reliable_papers", sa.SmallInteger(), nullable=True))
    op.add_column("exams", sa.Column("counting_unit", sa.String(length=8), nullable=True))
    op.add_column(
        "exams",
        sa.Column("exam_dates", postgresql.ARRAY(sa.Date()), server_default="{}", nullable=False),
    )
    op.create_check_constraint(
        "ck_exams_kind_valid", "exams", "kind IS NULL OR kind IN ('mcq', 'descriptive', 'mixed')"
    )
    op.create_check_constraint(
        "ck_exams_options_valid",
        "exams",
        "options_per_question IS NULL OR options_per_question = 0 "
        "OR options_per_question BETWEEN 2 AND 6",
    )
    op.create_check_constraint(
        "ck_exams_repeat_share_valid",
        "exams",
        "repeat_share IS NULL OR (repeat_share > 0 AND repeat_share <= 1)",
    )
    op.create_check_constraint(
        "ck_exams_counting_unit_valid",
        "exams",
        "counting_unit IS NULL OR counting_unit IN ('paper', 'session')",
    )
    op.execute(
        "UPDATE exams SET kind = 'mcq', options_per_question = 4, repeat_share = 0.5, "
        "min_papers = 3, reliable_papers = 5, counting_unit = 'paper' "
        "WHERE code IN ('SSC_CGL', 'SSC_CHSL')"
    )


def downgrade() -> None:
    for name in ("counting_unit_valid", "repeat_share_valid", "options_valid", "kind_valid"):
        op.drop_constraint(f"ck_exams_{name}", "exams", type_="check")
    for column in (
        "exam_dates",
        "counting_unit",
        "reliable_papers",
        "min_papers",
        "repeat_share",
        "options_per_question",
        "kind",
    ):
        op.drop_column("exams", column)
