"""ai paper reading

Learners may ask AI to read a paper's questions when PrepLoop's rules can't: the document
tracks that job (ai_read_*), questions record who read them (extracted_by rules | ai), and
AI calls may have the task "paper_read" (only task, model, outcome and tokens are recorded).

Revision ID: 0025
Revises: 0024
Create Date: 2026-10-25 10:00:00

"""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op

# revision identifiers, used by Alembic.
revision: str = "0025"
down_revision: str | Sequence[str] | None = "0024"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None

TASKS_BEFORE = (
    "task IN ('explanation', 'questions', 'topic', 'taxonomy', 'quick_answer', 'rag_answer')"
)
TASKS_AFTER = (
    "task IN ('explanation', 'questions', 'topic', 'taxonomy', 'quick_answer', 'rag_answer', "
    "'paper_read')"
)


def upgrade() -> None:
    """Upgrade schema."""
    op.add_column(
        "documents",
        sa.Column("ai_read_status", sa.String(length=10), server_default="none", nullable=False),
    )
    op.add_column(
        "documents", sa.Column("ai_read_started_at", sa.DateTime(timezone=True), nullable=True)
    )
    op.add_column(
        "documents",
        sa.Column("ai_read_pages_done", sa.Integer(), server_default="0", nullable=False),
    )
    op.add_column("documents", sa.Column("ai_read_error", sa.String(length=40), nullable=True))
    op.create_check_constraint(
        op.f("ck_documents_ai_read_status_valid"),
        "documents",
        "ai_read_status IN ('none', 'queued', 'running', 'completed', 'failed')",
    )
    op.add_column(
        "questions",
        sa.Column("extracted_by", sa.String(length=8), server_default="rules", nullable=False),
    )
    op.create_check_constraint(
        op.f("ck_questions_extracted_by_valid"), "questions", "extracted_by IN ('rules', 'ai')"
    )
    op.drop_constraint(op.f("ck_ai_generations_task_valid"), "ai_generations", type_="check")
    op.create_check_constraint(op.f("ck_ai_generations_task_valid"), "ai_generations", TASKS_AFTER)


def downgrade() -> None:
    """Downgrade schema."""
    op.execute("DELETE FROM ai_generations WHERE task = 'paper_read'")
    op.drop_constraint(op.f("ck_ai_generations_task_valid"), "ai_generations", type_="check")
    op.create_check_constraint(op.f("ck_ai_generations_task_valid"), "ai_generations", TASKS_BEFORE)
    op.drop_constraint(op.f("ck_questions_extracted_by_valid"), "questions", type_="check")
    op.drop_column("questions", "extracted_by")
    op.drop_constraint(op.f("ck_documents_ai_read_status_valid"), "documents", type_="check")
    op.drop_column("documents", "ai_read_error")
    op.drop_column("documents", "ai_read_pages_done")
    op.drop_column("documents", "ai_read_started_at")
    op.drop_column("documents", "ai_read_status")
