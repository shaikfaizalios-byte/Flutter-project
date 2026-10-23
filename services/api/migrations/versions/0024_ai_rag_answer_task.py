"""ai rag answer task

AI calls may now answer a search from the learner's own material (task "rag_answer"); as for
every AI call, only the task, model, outcome and token counts are recorded, never text.

Revision ID: 0024
Revises: 0023
Create Date: 2026-10-23 10:00:00

"""

from collections.abc import Sequence

from alembic import op

# revision identifiers, used by Alembic.
revision: str = "0024"
down_revision: str | Sequence[str] | None = "0023"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None

BEFORE = "task IN ('explanation', 'questions', 'topic', 'taxonomy', 'quick_answer')"
AFTER = "task IN ('explanation', 'questions', 'topic', 'taxonomy', 'quick_answer', 'rag_answer')"


def upgrade() -> None:
    """Upgrade schema."""
    op.drop_constraint(op.f("ck_ai_generations_task_valid"), "ai_generations", type_="check")
    op.create_check_constraint(op.f("ck_ai_generations_task_valid"), "ai_generations", AFTER)


def downgrade() -> None:
    """Downgrade schema."""
    op.execute("DELETE FROM ai_generations WHERE task = 'rag_answer'")
    op.drop_constraint(op.f("ck_ai_generations_task_valid"), "ai_generations", type_="check")
    op.create_check_constraint(op.f("ck_ai_generations_task_valid"), "ai_generations", BEFORE)
