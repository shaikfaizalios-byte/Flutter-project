"""current affairs task

AI calls that draft current affairs cards from the learner's own sources are logged (without
their text) as task 'current_affairs'. The cards themselves are stored only on the device, as
concepts, once the learner approves each one.

Revision ID: 0068
Revises: 0067
"""

from collections.abc import Sequence

from alembic import op

revision: str = "0068"
down_revision: str | None = "0067"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None

TASKS = (
    "'explanation', 'questions', 'topic', 'taxonomy', 'quick_answer', "
    "'rag_answer', 'paper_read', 'topic_lesson', 'topic_quiz', 'answer_check', "
    "'study_topics', 'paper_summary', 'ladder_search', 'ladder_question', "
    "'ladder_solve', 'written_question', 'written_mark', 'written_read', 'concept_hint'"
)


def upgrade() -> None:
    op.drop_constraint(op.f("ck_ai_generations_task_valid"), "ai_generations", type_="check")
    op.create_check_constraint(
        op.f("ck_ai_generations_task_valid"),
        "ai_generations",
        f"task IN ({TASKS}, 'current_affairs')",
    )


def downgrade() -> None:
    op.execute("DELETE FROM ai_generations WHERE task = 'current_affairs'")
    op.drop_constraint(op.f("ck_ai_generations_task_valid"), "ai_generations", type_="check")
    op.create_check_constraint(
        op.f("ck_ai_generations_task_valid"), "ai_generations", f"task IN ({TASKS})"
    )
