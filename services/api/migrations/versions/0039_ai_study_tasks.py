"""ai study tasks

AI calls may now list the most covered topics across a learner's papers ("study_topics") and
summarise a whole paper ("paper_summary"). Nothing is stored; as for every AI call, only the
task, model, outcome and token counts are recorded, never text.

Revision ID: 0039
Revises: 0038
Create Date: 2026-11-04 10:00:00

"""

from collections.abc import Sequence

from alembic import op

# revision identifiers, used by Alembic.
revision: str = "0039"
down_revision: str | Sequence[str] | None = "0038"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None

TASKS_BEFORE = (
    "task IN ('explanation', 'questions', 'topic', 'taxonomy', 'quick_answer', 'rag_answer', "
    "'paper_read', 'topic_lesson', 'topic_quiz', 'answer_check')"
)
TASKS_AFTER = (
    "task IN ('explanation', 'questions', 'topic', 'taxonomy', 'quick_answer', 'rag_answer', "
    "'paper_read', 'topic_lesson', 'topic_quiz', 'answer_check', 'study_topics', "
    "'paper_summary')"
)


def upgrade() -> None:
    """Upgrade schema."""
    op.drop_constraint(op.f("ck_ai_generations_task_valid"), "ai_generations", type_="check")
    op.create_check_constraint(op.f("ck_ai_generations_task_valid"), "ai_generations", TASKS_AFTER)


def downgrade() -> None:
    """Downgrade schema."""
    op.execute("DELETE FROM ai_generations WHERE task IN ('study_topics', 'paper_summary')")
    op.drop_constraint(op.f("ck_ai_generations_task_valid"), "ai_generations", type_="check")
    op.create_check_constraint(op.f("ck_ai_generations_task_valid"), "ai_generations", TASKS_BEFORE)
