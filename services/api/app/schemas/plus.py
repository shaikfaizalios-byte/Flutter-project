from datetime import datetime
from typing import Annotated, Literal

from pydantic import BaseModel, ConfigDict, Field, StringConstraints

PlusSource = Literal["test", "operator", "play", "web"]
TEST_DAYS_MAX = 31


class WebOffer(BaseModel):
    """Plus bought on the website: one payment gives `days` of Plus, with no renewal."""

    provider: Literal["paytm"] = "paytm"
    amount_paise: int
    currency: Literal["INR"] = "INR"
    days: int
    # Paytm's staging environment: no real money moves.
    test_payments: bool


class PlusStatus(BaseModel):
    """The account's PrepLoop Plus state, as the server sees it."""

    active: bool
    source: PlusSource | None
    active_until: datetime | None
    # Successful AI requests this calendar month (UTC) and the monthly allowance with Plus.
    ai_used_this_month: int
    ai_monthly_allowance: int
    period_resets_at: datetime
    # A development server lets learners start a free test subscription.
    test_mode: bool
    # Plus can be bought on this server (Google Play is configured; docs/plus.md).
    purchases_available: bool
    # Google Play subscription product ids the app may offer (prices come from Play).
    play_product_ids: list[str] = []
    # Passed to Play as the obfuscated account id at purchase time, so the purchase can only
    # be added to this account (null when purchases are not available).
    play_account_id: str | None = None
    # Paying on the website (Paytm); null when this server doesn't offer it.
    web_offer: WebOffer | None = None


class PlayPurchaseVerify(BaseModel):
    """A Google Play purchase the app reports after buying or restoring."""

    model_config = ConfigDict(extra="forbid")

    product_id: Annotated[str, StringConstraints(min_length=1, max_length=100)]
    purchase_token: Annotated[str, StringConstraints(min_length=10, max_length=512)]


class PlusTestStart(BaseModel):
    model_config = ConfigDict(extra="forbid")

    days: int = Field(default=7, ge=1, le=TEST_DAYS_MAX)


WebPaymentStatus = Literal["created", "pending", "success", "failed", "refunded"]


class PaytmOrderCreated(BaseModel):
    order_id: str
    # Open this (on the API's address) in the browser: it sends the learner to Paytm. It expires
    # in 15 minutes.
    pay_path: str
    amount_paise: int
    days: int


class PaytmOrderRead(BaseModel):
    order_id: str
    status: WebPaymentStatus
    amount_paise: int
    days: int
    granted_until: datetime | None
    test_payment: bool
