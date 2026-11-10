"""web payments

PrepLoop Plus bought on the website with Paytm (one payment = a set number of days, no automatic
renewal). `web_payments` holds each order as last confirmed with Paytm's Transaction Status API;
`billing_events` now accepts the provider 'paytm' and its kinds (order, callback, webhook, status).
Nothing changes for existing rows.

Revision ID: 0061
Revises: 0060
"""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op

revision: str = "0061"
down_revision: str | None = "0060"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None

OLD_KINDS = "kind IN ('verify', 'subscription', 'voided', 'test')"
NEW_KINDS = (
    "kind IN ('verify', 'subscription', 'voided', 'test', 'order', 'callback', 'webhook', 'status')"
)


def upgrade() -> None:
    op.create_table(
        "web_payments",
        sa.Column("id", sa.Uuid(), nullable=False),
        sa.Column("owner_id", sa.Uuid(), nullable=False),
        sa.Column("provider", sa.String(length=8), nullable=False),
        sa.Column("environment", sa.String(length=16), nullable=False),
        sa.Column("order_id", sa.String(length=50), nullable=False),
        sa.Column("amount_paise", sa.Integer(), nullable=False),
        sa.Column("currency", sa.String(length=3), nullable=False),
        sa.Column("days", sa.Integer(), nullable=False),
        sa.Column("status", sa.String(length=16), nullable=False),
        sa.Column("txn_token", sa.String(length=200), nullable=True),
        sa.Column("txn_id", sa.String(length=64), nullable=True),
        sa.Column("payment_mode", sa.String(length=16), nullable=True),
        sa.Column("result_code", sa.String(length=16), nullable=True),
        sa.Column("granted_from", sa.DateTime(timezone=True), nullable=True),
        sa.Column("granted_until", sa.DateTime(timezone=True), nullable=True),
        sa.Column("paid_at", sa.DateTime(timezone=True), nullable=True),
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
        sa.CheckConstraint("provider IN ('paytm')", name=op.f("ck_web_payments_provider_valid")),
        sa.CheckConstraint(
            "environment IN ('staging', 'production')",
            name=op.f("ck_web_payments_environment_valid"),
        ),
        sa.CheckConstraint(
            "status IN ('created', 'pending', 'success', 'failed', 'refunded')",
            name=op.f("ck_web_payments_status_valid"),
        ),
        sa.CheckConstraint("amount_paise > 0", name=op.f("ck_web_payments_amount_positive")),
        sa.CheckConstraint("days > 0", name=op.f("ck_web_payments_days_positive")),
        sa.CheckConstraint(
            "(status IN ('success', 'refunded')) = (granted_until IS NOT NULL)",
            name=op.f("ck_web_payments_granted_when_paid"),
        ),
        sa.ForeignKeyConstraint(
            ["owner_id"],
            ["users.id"],
            name=op.f("fk_web_payments_owner_id_users"),
            ondelete="CASCADE",
        ),
        sa.PrimaryKeyConstraint("id", name=op.f("pk_web_payments")),
        sa.UniqueConstraint("order_id", name=op.f("uq_web_payments_order_id")),
    )
    op.create_index(op.f("ix_web_payments_owner_id"), "web_payments", ["owner_id"], unique=False)
    op.drop_constraint(op.f("ck_billing_events_provider_valid"), "billing_events", type_="check")
    op.create_check_constraint(
        op.f("ck_billing_events_provider_valid"), "billing_events", "provider IN ('play', 'paytm')"
    )
    op.drop_constraint(op.f("ck_billing_events_kind_valid"), "billing_events", type_="check")
    op.create_check_constraint(op.f("ck_billing_events_kind_valid"), "billing_events", NEW_KINDS)


def downgrade() -> None:
    op.execute("DELETE FROM billing_events WHERE provider = 'paytm'")
    op.drop_constraint(op.f("ck_billing_events_kind_valid"), "billing_events", type_="check")
    op.create_check_constraint(op.f("ck_billing_events_kind_valid"), "billing_events", OLD_KINDS)
    op.drop_constraint(op.f("ck_billing_events_provider_valid"), "billing_events", type_="check")
    op.create_check_constraint(
        op.f("ck_billing_events_provider_valid"), "billing_events", "provider IN ('play')"
    )
    op.drop_index(op.f("ix_web_payments_owner_id"), table_name="web_payments")
    op.drop_table("web_payments")
