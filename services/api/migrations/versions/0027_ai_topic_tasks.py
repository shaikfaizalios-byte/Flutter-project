"""ai topic tasks

AI calls may now teach a topic ("topic_lesson") or check it with questions ("topic_quiz").
Neither result is stored; as for every AI call, only the task, model, outcome and token
counts are recorded, never text.

Revision ID: 0027
Revises: 0026
Create Date: 2026-10-29 10:00:00

"""

from collections.abc import Sequence

from alembic import op

# revision identifiers, used by Alembic.
revision: str = "0027"
down_revision: str | Sequence[str] | None = "0026"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None

TASKS_BEFORE = (
    "task IN ('explanation', 'questions', 'topic', 'taxonomy', 'quick_answer', 'rag_answer', "
    "'paper_read')"
)
TASKS_AFTER = (
    "task IN ('explanation', 'questions', 'topic', 'taxonomy', 'quick_answer', 'rag_answer', "
    "'paper_read', 'topic_lesson', 'topic_quiz')"
)


def upgrade() -> None:
    """Upgrade schema."""
    op.drop_constraint(op.f("ck_ai_generations_task_valid"), "ai_generations", type_="check")
    op.create_check_constraint(op.f("ck_ai_generations_task_valid"), "ai_generations", TASKS_AFTER)


def downgrade() -> None:
    """Downgrade schema."""
    op.execute("DELETE FROM ai_generations WHERE task IN ('topic_lesson', 'topic_quiz')")
    op.drop_constraint(op.f("ck_ai_generations_task_valid"), "ai_generations", type_="check")
    op.create_check_constraint(op.f("ck_ai_generations_task_valid"), "ai_generations", TASKS_BEFORE)
