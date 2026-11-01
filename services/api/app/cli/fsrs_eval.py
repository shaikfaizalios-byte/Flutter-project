"""Checks FSRS against the synced revision history before any change to scheduling.

    python -m app.cli.fsrs_eval

Reads every synced ``card_review`` (learners who use sync), replays each card's reviews and
prints aggregate numbers only: how well FSRS predicted recall compared with a constant guess,
its calibration, and how often learners recalled cards at the ladder's gaps. No account,
card or text is printed. The app's scheduler is not changed (docs/revision.md "FSRS check").
"""

import json
import sys
import uuid
from collections import defaultdict
from dataclasses import asdict
from datetime import datetime
from typing import Any

from sqlalchemy import select
from sqlalchemy.orm import Session

from app.core.config import get_settings
from app.database.session import build_engine, build_sessionmaker
from app.domain.fsrs import GRADES, Evaluation, Review, evaluate
from app.models.sync import SyncItem


def card_histories(session: Session) -> tuple[list[list[Review]], int]:
    """Each card's reviews (per account), and the number of accounts they came from.
    Malformed events are skipped."""
    cards: dict[tuple[uuid.UUID, str], list[Review]] = defaultdict(list)
    rows = session.execute(
        select(SyncItem.owner_id, SyncItem.data).where(
            SyncItem.entity == "card_review", SyncItem.deleted.is_(False)
        )
    )
    for owner_id, data in rows:
        if not isinstance(data, dict):
            continue
        rating, card_id, reviewed_at = (
            data.get("rating"),
            data.get("card_id"),
            data.get("reviewed_at"),
        )
        if rating not in GRADES or not isinstance(card_id, str) or not isinstance(reviewed_at, str):
            continue
        try:
            moment = datetime.fromisoformat(reviewed_at)
        except ValueError:
            continue
        cards[(owner_id, card_id)].append(Review(reviewed_on=moment.date(), rating=rating))
    return list(cards.values()), len({owner for owner, _ in cards})


def report(evaluation: Evaluation, accounts: int) -> dict[str, Any]:
    return {"accounts": accounts, **asdict(evaluation)}


def main(argv: list[str] | None = None) -> int:
    del argv  # no options yet
    engine = build_engine(get_settings())
    if engine is None:
        print("PREPLOOP_DATABASE_URL is not set.", file=sys.stderr)
        return 2
    with build_sessionmaker(engine)() as session:
        cards, accounts = card_histories(session)
    print(json.dumps(report(evaluate(cards), accounts), indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
