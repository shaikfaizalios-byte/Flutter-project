"""ai answer check task

AI calls may now check a learner's own answer to a question of their paper ("answer_check").
Nothing is stored; as for every AI call, only the task, model, outcome and token counts are
recorded, never text.

Revision ID: 0028
Revises: 0027
Create Date: 2026-10-30 21:00:00

"""

from collections.abc import Sequence

from alembic import op

# revision identifiers, used by Alembic.
revision: str = "0028"
down_revision: str | Sequence[str] | None = "0027"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None

TASKS_BEFORE = (
    "task IN ('explanation', 'questions', 'topic', 'taxonomy', 'quick_answer', 'rag_answer', "
    "'paper_read', 'topic_lesson', 'topic_quiz')"
)
TASKS_AFTER = (
    "task IN ('explanation', 'questions', 'topic', 'taxonomy', 'quick_answer', 'rag_answer', "
    "'paper_read', 'topic_lesson', 'topic_quiz', 'answer_check')"
)


def upgrade() -> None:
    """Upgrade schema."""
    op.drop_constraint(op.f("ck_ai_generations_task_valid"), "ai_generations", type_="check")
    op.create_check_constraint(op.f("ck_ai_generations_task_valid"), "ai_generations", TASKS_AFTER)


def downgrade() -> None:
    """Downgrade schema."""
    op.execute("DELETE FROM ai_generations WHERE task = 'answer_check'")
    op.drop_constraint(op.f("ck_ai_generations_task_valid"), "ai_generations", type_="check")
    op.create_check_constraint(op.f("ck_ai_generations_task_valid"), "ai_generations", TASKS_BEFORE)
