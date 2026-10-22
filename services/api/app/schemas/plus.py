from datetime import datetime
from typing import Literal

from pydantic import BaseModel, ConfigDict, Field

PlusSource = Literal["test", "operator", "play", "web"]
TEST_DAYS_MAX = 31


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
    # Real purchases (Google Play, web payments) are not built yet.
    purchases_available: bool


class PlusTestStart(BaseModel):
    model_config = ConfigDict(extra="forbid")

    days: int = Field(default=7, ge=1, le=TEST_DAYS_MAX)
