"""Suggestions from learners: stored per account, listed back to the sender, read by the
operator with `python -m app.cli.suggestions`."""

import uuid
from collections.abc import Callable
from datetime import UTC, datetime, timedelta

from sqlalchemy import func, select
from sqlalchemy.orm import Session

from app.domain.errors import RateLimitedError
from app.models.feedback import Suggestion
from app.schemas.feedback import SUGGESTIONS_PER_DAY, SuggestionCreate, SuggestionRead


class FeedbackService:
    def __init__(
        self,
        session: Session,
        owner_id: uuid.UUID,
        now: Callable[[], datetime] | None = None,
    ) -> None:
        self._session = session
        self._owner_id = owner_id
        self._now = now or (lambda: datetime.now(UTC))

    def suggest(self, body: SuggestionCreate) -> SuggestionRead:
        now = self._now()
        since = now - timedelta(days=1)
        recent, oldest = self._session.execute(
            select(func.count(Suggestion.id), func.min(Suggestion.created_at)).where(
                Suggestion.owner_id == self._owner_id, Suggestion.created_at >= since
            )
        ).one()
        if recent >= SUGGESTIONS_PER_DAY and oldest is not None:
            wait = int((oldest + timedelta(days=1) - now).total_seconds()) + 1
            raise RateLimitedError(
                "Too many suggestions today. Please try again later.", max(wait, 1)
            )
        suggestion = Suggestion(
            owner_id=self._owner_id,
            kind=body.kind,
            text=body.text,
            status="new",
            created_at=self._now(),
        )
        self._session.add(suggestion)
        self._session.commit()
        return SuggestionRead.model_validate(suggestion)

    def mine(self, limit: int = 50) -> list[SuggestionRead]:
        rows = self._session.scalars(
            select(Suggestion)
            .where(Suggestion.owner_id == self._owner_id)
            .order_by(Suggestion.created_at.desc())
            .limit(limit)
        ).all()
        return [SuggestionRead.model_validate(r) for r in rows]
