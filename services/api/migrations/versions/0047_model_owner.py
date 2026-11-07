"""models have an owner

A learner can now name a model on a shared topic, so a model needs its own owner: NULL is the
shared list, otherwise it is private to that learner. Models under a learner's own topics take
that learner as owner. The same name may now exist once per owner within a topic.

Revision ID: 0047
Revises: 0046
"""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op

revision: str = "0047"
down_revision: str | None = "0046"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.add_column("question_patterns", sa.Column("owner_id", sa.Uuid(), nullable=True))
    op.create_foreign_key(
        op.f("fk_question_patterns_owner_id_users"),
        "question_patterns",
        "users",
        ["owner_id"],
        ["id"],
        ondelete="CASCADE",
    )
    op.create_index(
        op.f("ix_question_patterns_owner_id"), "question_patterns", ["owner_id"], unique=False
    )
    op.execute(
        "UPDATE question_patterns p SET owner_id = t.owner_id FROM topics t WHERE t.id = p.topic_id"
    )
    op.drop_constraint("uq_question_patterns_topic_name", "question_patterns", type_="unique")
    op.create_unique_constraint(
        "uq_question_patterns_topic_owner_name",
        "question_patterns",
        ["topic_id", "owner_id", "name"],
        postgresql_nulls_not_distinct=True,
    )


def downgrade() -> None:
    # Private models on shared topics have no place in the older schema: their questions go back
    # to having no model.
    op.execute(
        "UPDATE questions SET pattern_id = NULL, pattern_status = 'unassigned', "
        "pattern_suggestion_reason = NULL WHERE pattern_id IN ("
        "SELECT p.id FROM question_patterns p JOIN topics t ON t.id = p.topic_id "
        "WHERE p.owner_id IS NOT NULL AND t.owner_id IS NULL)"
    )
    op.execute(
        "DELETE FROM question_patterns p USING topics t "
        "WHERE t.id = p.topic_id AND p.owner_id IS NOT NULL AND t.owner_id IS NULL"
    )
    op.drop_constraint("uq_question_patterns_topic_owner_name", "question_patterns", type_="unique")
    op.create_unique_constraint(
        "uq_question_patterns_topic_name", "question_patterns", ["topic_id", "name"]
    )
    op.drop_index(op.f("ix_question_patterns_owner_id"), table_name="question_patterns")
    op.drop_constraint(
        op.f("fk_question_patterns_owner_id_users"), "question_patterns", type_="foreignkey"
    )
    op.drop_column("question_patterns", "owner_id")
