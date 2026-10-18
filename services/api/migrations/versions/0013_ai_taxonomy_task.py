"""ai taxonomy task

AI calls may now also draft a topic list for an exam (task "taxonomy"); as for every AI call,
only the task, model, outcome and token counts are recorded, never text.

Revision ID: 0013
Revises: 0012
Create Date: 2026-10-19 12:00:00

"""

from collections.abc import Sequence

from alembic import op

# revision identifiers, used by Alembic.
revision: str = "0013"
down_revision: str | Sequence[str] | None = "0012"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    """Upgrade schema."""
    op.drop_constraint(op.f("ck_ai_generations_task_valid"), "ai_generations", type_="check")
    op.create_check_constraint(
        op.f("ck_ai_generations_task_valid"),
        "ai_generations",
        "task IN ('explanation', 'questions', 'topic', 'taxonomy')",
    )


def downgrade() -> None:
    """Downgrade schema."""
    op.execute("DELETE FROM ai_generations WHERE task = 'taxonomy'")
    op.drop_constraint(op.f("ck_ai_generations_task_valid"), "ai_generations", type_="check")
    op.create_check_constraint(
        op.f("ck_ai_generations_task_valid"),
        "ai_generations",
        "task IN ('explanation', 'questions', 'topic')",
    )
