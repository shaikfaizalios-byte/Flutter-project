"""PrepLoop Plus: whether an account is subscribed and how much of its monthly AI allowance it
has used. The server decides; the app only shows it. Test subscriptions exist only while
`plus_test_mode` is on (development); store purchases are not built yet."""

import uuid
from collections.abc import Callable
from datetime import UTC, datetime, timedelta

from sqlalchemy import func, select
from sqlalchemy.orm import Session

from app.core.config import Settings
from app.domain.errors import AIAllowanceUsedError, ConflictError, PlusRequiredError
from app.models.ai import AIGeneration
from app.models.plus import Subscription
from app.schemas.plus import PlusStatus

# AI requests that count against the allowance (failed and invalid ones don't).
COUNTED_OUTCOMES = ("ok", "partial")


def month_bounds(now: datetime) -> tuple[datetime, datetime]:
    """Start of this calendar month and of the next one, in UTC."""
    start = now.astimezone(UTC).replace(day=1, hour=0, minute=0, second=0, microsecond=0)
    following = (start + timedelta(days=32)).replace(day=1)
    return start, following


def active_subscription(
    session: Session, owner_id: uuid.UUID, now: datetime
) -> Subscription | None:
    sub = session.get(Subscription, owner_id)
    return sub if sub is not None and sub.active_until > now else None


class PlusService:
    def __init__(
        self,
        session: Session,
        owner_id: uuid.UUID,
        settings: Settings,
        now: Callable[[], datetime] | None = None,
    ) -> None:
        self._session = session
        self._owner_id = owner_id
        self._settings = settings
        self._now = now or (lambda: datetime.now(UTC))

    def status(self) -> PlusStatus:
        now = self._now()
        start, following = month_bounds(now)
        used = self._session.scalar(
            select(func.count(AIGeneration.id)).where(
                AIGeneration.owner_id == self._owner_id,
                AIGeneration.created_at >= start,
                AIGeneration.outcome.in_(COUNTED_OUTCOMES),
            )
        )
        sub = active_subscription(self._session, self._owner_id, now)
        return PlusStatus(
            active=sub is not None,
            source=sub.source if sub else None,
            active_until=sub.active_until if sub else None,
            ai_used_this_month=used or 0,
            ai_monthly_allowance=self._settings.plus_ai_monthly_allowance,
            period_resets_at=following,
            test_mode=self._settings.plus_test_mode,
            purchases_available=False,
        )

    def check_ai_allowed(self) -> None:
        """Raises unless the account may make another AI request: an active subscription with
        allowance left this month. Does nothing when the server doesn't require Plus."""
        if not self._settings.plus_required_for_ai:
            return
        status = self.status()
        if not status.active:
            raise PlusRequiredError("AI features are part of PrepLoop Plus.")
        if status.ai_used_this_month >= status.ai_monthly_allowance:
            wait = int((status.period_resets_at - self._now()).total_seconds())
            raise AIAllowanceUsedError(
                "This month's AI requests are used up. They reset at the start of next month.",
                retry_after_seconds=max(wait, 1),
            )

    def start_test(self, days: int) -> PlusStatus:
        if not self._settings.plus_test_mode:
            raise ConflictError(
                "plus_test_disabled", "Test subscriptions are not available on this server."
            )
        now = self._now()
        sub = self._session.get(Subscription, self._owner_id)
        if sub is not None and sub.source != "test" and sub.active_until > now:
            raise ConflictError("plus_active", "This account already has PrepLoop Plus.")
        if sub is None:
            sub = Subscription(owner_id=self._owner_id, plan="plus", source="test")
            self._session.add(sub)
        sub.source = "test"
        sub.active_until = now + timedelta(days=days)
        sub.note = None
        self._session.commit()
        return self.status()

    def end_test(self) -> PlusStatus:
        sub = self._session.get(Subscription, self._owner_id)
        if sub is not None and sub.source == "test":
            self._session.delete(sub)
            self._session.commit()
        return self.status()
