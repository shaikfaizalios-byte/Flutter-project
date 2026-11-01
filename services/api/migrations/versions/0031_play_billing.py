"""play billing

Google Play subscriptions for PrepLoop Plus. `play_purchases` holds each purchase token as last
read from the Play Developer API (one token belongs to one account); `billing_events` audits every
purchase check and store notification without tokens (hash only) and makes notifications
idempotent (`event_key`). It keeps rows after account deletion with the account link cleared.

Revision ID: 0031
Revises: 0030
Create Date: 2026-11-01 16:30:00

"""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op

# revision identifiers, used by Alembic.
revision: str = "0031"
down_revision: str | Sequence[str] | None = "0030"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    """Upgrade schema."""
    op.create_table(
        "billing_events",
        sa.Column("id", sa.Uuid(), nullable=False),
        sa.Column("provider", sa.String(length=8), nullable=False),
        sa.Column("event_key", sa.String(length=160), nullable=False),
        sa.Column("kind", sa.String(length=16), nullable=False),
        sa.Column("notification_type", sa.Integer(), nullable=True),
        sa.Column("token_hash", sa.String(length=64), nullable=True),
        sa.Column("owner_id", sa.Uuid(), nullable=True),
        sa.Column("outcome", sa.String(length=16), nullable=False),
        sa.Column("detail", sa.String(length=200), server_default="", nullable=False),
        sa.Column(
            "received_at",
            sa.DateTime(timezone=True),
            server_default=sa.text("now()"),
            nullable=False,
        ),
        sa.CheckConstraint(
            "kind IN ('verify', 'subscription', 'voided', 'test')",
            name=op.f("ck_billing_events_kind_valid"),
        ),
        sa.CheckConstraint(
            "outcome IN ('applied', 'ignored', 'refused', 'unknown_token', 'error')",
            name=op.f("ck_billing_events_outcome_valid"),
        ),
        sa.CheckConstraint("provider IN ('play')", name=op.f("ck_billing_events_provider_valid")),
        sa.ForeignKeyConstraint(
            ["owner_id"],
            ["users.id"],
            name=op.f("fk_billing_events_owner_id_users"),
            ondelete="SET NULL",
        ),
        sa.PrimaryKeyConstraint("id", name=op.f("pk_billing_events")),
        sa.UniqueConstraint("event_key", name=op.f("uq_billing_events_event_key")),
    )
    op.create_index(
        op.f("ix_billing_events_owner_id"), "billing_events", ["owner_id"], unique=False
    )
    op.create_index("ix_billing_events_received", "billing_events", ["received_at"], unique=False)
    op.create_index(
        op.f("ix_billing_events_token_hash"), "billing_events", ["token_hash"], unique=False
    )
    op.create_table(
        "play_purchases",
        sa.Column("id", sa.Uuid(), nullable=False),
        sa.Column("owner_id", sa.Uuid(), nullable=False),
        sa.Column("purchase_token", sa.String(length=512), nullable=False),
        sa.Column("product_id", sa.String(length=100), nullable=False),
        sa.Column("state", sa.String(length=48), nullable=False),
        sa.Column("expires_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("acknowledged", sa.Boolean(), nullable=False),
        sa.Column("test_purchase", sa.Boolean(), nullable=False),
        sa.Column("replaced_by_id", sa.Uuid(), nullable=True),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.text("now()"),
            nullable=False,
        ),
        sa.Column(
            "updated_at",
            sa.DateTime(timezone=True),
            server_default=sa.text("now()"),
            nullable=False,
        ),
        sa.ForeignKeyConstraint(
            ["owner_id"],
            ["users.id"],
            name=op.f("fk_play_purchases_owner_id_users"),
            ondelete="CASCADE",
        ),
        sa.ForeignKeyConstraint(
            ["replaced_by_id"],
            ["play_purchases.id"],
            name=op.f("fk_play_purchases_replaced_by_id_play_purchases"),
            ondelete="SET NULL",
        ),
        sa.PrimaryKeyConstraint("id", name=op.f("pk_play_purchases")),
        sa.UniqueConstraint("purchase_token", name=op.f("uq_play_purchases_purchase_token")),
    )
    op.create_index(
        op.f("ix_play_purchases_owner_id"), "play_purchases", ["owner_id"], unique=False
    )


def downgrade() -> None:
    """Downgrade schema."""
    op.drop_index(op.f("ix_play_purchases_owner_id"), table_name="play_purchases")
    op.drop_table("play_purchases")
    op.drop_index(op.f("ix_billing_events_token_hash"), table_name="billing_events")
    op.drop_index("ix_billing_events_received", table_name="billing_events")
    op.drop_index(op.f("ix_billing_events_owner_id"), table_name="billing_events")
    op.drop_table("billing_events")
