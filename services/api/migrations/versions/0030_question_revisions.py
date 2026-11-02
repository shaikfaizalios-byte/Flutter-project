"""question revisions

An append-only history of each question's wording and answer. The first "extracted"
revision keeps the question as read from its paper, so the paper's own answer stays known
after a reviewer changes it. Existing questions get one "baseline" revision: their state when
history began (earlier edits are unknown, so a baseline never counts as the paper's answer).

Revision ID: 0030
Revises: 0029
Create Date: 2026-11-01 12:00:00

"""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects import postgresql

# revision identifiers, used by Alembic.
revision: str = "0030"
down_revision: str | Sequence[str] | None = "0029"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    """Upgrade schema."""
    op.create_table(
        "question_revisions",
        sa.Column("id", sa.Uuid(), nullable=False),
        sa.Column("question_id", sa.Uuid(), nullable=False),
        sa.Column("action", sa.String(length=10), nullable=False),
        sa.Column("actor", sa.String(length=10), nullable=False),
        sa.Column("changed", postgresql.ARRAY(sa.String(length=32)), nullable=False),
        sa.Column("snapshot", postgresql.JSONB(astext_type=sa.Text()), nullable=False),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.text("clock_timestamp()"),
            nullable=False,
        ),
        sa.CheckConstraint(
            "action IN ('extracted', 'generated', 'baseline', 'edited')",
            name=op.f("ck_question_revisions_action_valid"),
        ),
        sa.CheckConstraint(
            "actor IN ('rules', 'ai', 'reviewer', 'migration')",
            name=op.f("ck_question_revisions_actor_valid"),
        ),
        sa.ForeignKeyConstraint(
            ["question_id"],
            ["questions.id"],
            name=op.f("fk_question_revisions_question_id_questions"),
            ondelete="CASCADE",
        ),
        sa.PrimaryKeyConstraint("id", name=op.f("pk_question_revisions")),
    )
    op.create_index(
        "ix_question_revisions_question_created",
        "question_revisions",
        ["question_id", "created_at"],
        unique=False,
    )
    # Where history begins for the questions that already exist.
    op.execute(
        """
        INSERT INTO question_revisions (id, question_id, action, actor, changed, snapshot)
        SELECT gen_random_uuid(), q.id, 'baseline', 'migration', '{}',
               jsonb_build_object(
                   'stem', q.stem,
                   'options', COALESCE(
                       (SELECT jsonb_agg(jsonb_build_object('label', o.label, 'text', o.text)
                                         ORDER BY o.position)
                          FROM question_options o WHERE o.question_id = q.id),
                       '[]'::jsonb),
                   'answer_type', q.answer_type,
                   'correct_option_position', q.correct_option_position,
                   'typed_answer', q.typed_answer,
                   'model_answer', q.model_answer,
                   'answer_source', q.answer_source,
                   'explanation', q.explanation)
          FROM questions q
        """
    )


def downgrade() -> None:
    """Downgrade schema."""
    op.drop_index("ix_question_revisions_question_created", table_name="question_revisions")
    op.drop_table("question_revisions")
