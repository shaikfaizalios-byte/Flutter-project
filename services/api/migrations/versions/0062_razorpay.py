"""razorpay

PrepLoop Plus can also be bought on the website with Razorpay. `web_payments` accepts the provider
'razorpay' and keeps Razorpay's own order id (`provider_order_id`); `billing_events` accepts the
provider 'razorpay'. Nothing changes for existing rows.

Revision ID: 0062
Revises: 0061
"""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op

revision: str = "0062"
down_revision: str | None = "0061"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def _checks(web: str, events: str) -> None:
    op.drop_constraint(op.f("ck_web_payments_provider_valid"), "web_payments", type_="check")
    op.create_check_constraint(op.f("ck_web_payments_provider_valid"), "web_payments", web)
    op.drop_constraint(op.f("ck_billing_events_provider_valid"), "billing_events", type_="check")
    op.create_check_constraint(op.f("ck_billing_events_provider_valid"), "billing_events", events)


def upgrade() -> None:
    op.add_column(
        "web_payments", sa.Column("provider_order_id", sa.String(length=64), nullable=True)
    )
    op.create_unique_constraint(
        op.f("uq_web_payments_provider_order_id"), "web_payments", ["provider_order_id"]
    )
    _checks("provider IN ('paytm', 'razorpay')", "provider IN ('play', 'paytm', 'razorpay')")


def downgrade() -> None:
    op.execute("DELETE FROM web_payments WHERE provider = 'razorpay'")
    op.execute("DELETE FROM billing_events WHERE provider = 'razorpay'")
    _checks("provider IN ('paytm')", "provider IN ('play', 'paytm')")
    op.drop_constraint(op.f("uq_web_payments_provider_order_id"), "web_payments", type_="unique")
    op.drop_column("web_payments", "provider_order_id")
