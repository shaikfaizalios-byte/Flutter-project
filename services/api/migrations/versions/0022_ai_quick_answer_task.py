"""ai quick answer task

AI calls may now give a short answer to a search no imported question matched (task
"quick_answer"); the answer is not stored and, as for every AI call, only the task, model,
outcome and token counts are recorded, never text.

Revision ID: 0022
Revises: 0021
Create Date: 2026-10-22 09:30:00

"""

from collections.abc import Sequence

from alembic import op

# revision identifiers, used by Alembic.
revision: str = "0022"
down_revision: str | Sequence[str] | None = "0021"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    """Upgrade schema."""
    op.drop_constraint(op.f("ck_ai_generations_task_valid"), "ai_generations", type_="check")
    op.create_check_constraint(
        op.f("ck_ai_generations_task_valid"),
        "ai_generations",
        "task IN ('explanation', 'questions', 'topic', 'taxonomy', 'quick_answer')",
    )


def downgrade() -> None:
    """Downgrade schema."""
    op.execute("DELETE FROM ai_generations WHERE task = 'quick_answer'")
    op.drop_constraint(op.f("ck_ai_generations_task_valid"), "ai_generations", type_="check")
    op.create_check_constraint(
        op.f("ck_ai_generations_task_valid"),
        "ai_generations",
        "task IN ('explanation', 'questions', 'topic', 'taxonomy')",
    )
