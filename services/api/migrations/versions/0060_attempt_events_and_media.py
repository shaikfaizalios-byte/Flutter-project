"""attempt events, figure hashes and job cursors

An attempt event is written when an answer becomes final, and again when a key change re-marks it,
so calibration can read what changed instead of every session. Figures get the hash of their bytes,
so a cache can name them by content. A job cursor remembers where a job stopped. Existing figures
get their hash here; nothing else changes.

Revision ID: 0060
Revises: 0059
"""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op

revision: str = "0060"
down_revision: str | None = "0059"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.add_column("question_figures", sa.Column("sha256", sa.String(length=64), nullable=True))
    op.execute("UPDATE question_figures SET sha256 = encode(sha256(data), 'hex')")
    op.create_index(
        op.f("ix_question_figures_sha256"), "question_figures", ["sha256"], unique=False
    )
    op.create_table(
        "attempt_events",
        sa.Column("id", sa.BigInteger(), sa.Identity(always=True), nullable=False),
        sa.Column("owner_id", sa.Uuid(), nullable=False),
        sa.Column("session_id", sa.Uuid(), nullable=False),
        sa.Column("position", sa.Integer(), nullable=False),
        sa.Column("question_id", sa.Uuid(), nullable=True),
        sa.Column("exam_code", sa.String(length=32), nullable=True),
        sa.Column("topic_id", sa.Uuid(), nullable=True),
        sa.Column("kind", sa.String(length=8), nullable=False),
        sa.Column("correct", sa.Boolean(), nullable=True),
        sa.Column("was_correct", sa.Boolean(), nullable=True),
        sa.Column("time_ms", sa.Integer(), nullable=True),
        sa.Column(
            "occurred_at",
            sa.DateTime(timezone=True),
            server_default=sa.text("now()"),
            nullable=False,
        ),
        sa.CheckConstraint(
            "kind IN ('final', 'remarked')", name=op.f("ck_attempt_events_kind_valid")
        ),
        sa.ForeignKeyConstraint(
            ["owner_id"],
            ["users.id"],
            name=op.f("fk_attempt_events_owner_id_users"),
            ondelete="CASCADE",
        ),
        sa.PrimaryKeyConstraint("id", name=op.f("pk_attempt_events")),
    )
    op.create_index(
        op.f("ix_attempt_events_owner_id"), "attempt_events", ["owner_id"], unique=False
    )
    op.create_index(
        op.f("ix_attempt_events_question_id"), "attempt_events", ["question_id"], unique=False
    )
    op.create_table(
        "job_cursors",
        sa.Column("name", sa.String(length=40), nullable=False),
        sa.Column("last_id", sa.BigInteger(), nullable=False),
        sa.Column(
            "updated_at",
            sa.DateTime(timezone=True),
            server_default=sa.text("now()"),
            nullable=False,
        ),
        sa.PrimaryKeyConstraint("name", name=op.f("pk_job_cursors")),
    )


def downgrade() -> None:
    op.drop_table("job_cursors")
    op.drop_index(op.f("ix_attempt_events_question_id"), table_name="attempt_events")
    op.drop_index(op.f("ix_attempt_events_owner_id"), table_name="attempt_events")
    op.drop_table("attempt_events")
    op.drop_index(op.f("ix_question_figures_sha256"), table_name="question_figures")
    op.drop_column("question_figures", "sha256")
