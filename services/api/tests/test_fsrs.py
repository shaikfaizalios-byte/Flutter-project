"""FSRS offline check (global Phase 9): model properties, evaluation verdicts, and reading the
synced review history."""

import random
import uuid
from datetime import date, timedelta

import pytest
from sqlalchemy.orm import Session

from app.cli.fsrs_eval import card_histories, report
from app.domain.fsrs import (
    MIN_CARDS,
    MIN_REVIEWS,
    Rating,
    Review,
    evaluate,
    initial_state,
    interval_days,
    next_state,
    retrievability,
)
from app.models.sync import SyncItem
from app.models.user import User
from tests.conftest import make_user

DAY0 = date(2026, 1, 1)


def test_recall_is_ninety_percent_after_stability_days() -> None:
    assert retrievability(0, 5.0) == 1.0
    assert retrievability(5.0, 5.0) == pytest.approx(0.9)
    assert retrievability(20, 5.0) < retrievability(10, 5.0)
    assert interval_days(7.0) == pytest.approx(7.0)
    assert interval_days(7.0, 0.8) > 7.0


def test_ratings_move_stability_and_difficulty_the_right_way() -> None:
    starts = [initial_state(r).stability for r in ("again", "hard", "good", "easy")]
    assert starts == sorted(starts)
    good = initial_state("good")
    later = next_state(good, "good", 3)
    assert later.stability > good.stability
    assert next_state(later, "again", 10).stability < later.stability
    assert next_state(good, "again", 3).difficulty > good.difficulty
    assert next_state(good, "easy", 3).difficulty < good.difficulty
    assert 1 <= next_state(good, "again", 3).difficulty <= 10


def test_no_history_or_same_day_repeats_give_no_verdict() -> None:
    assert evaluate([]).verdict == "insufficient_data"
    same_day = [Review(DAY0, "good"), Review(DAY0, "again"), Review(DAY0, "good")]
    result = evaluate([same_day])
    assert (result.cards, result.reviews_scored, result.recall_rate) == (1, 0, None)


def test_a_small_history_is_measured_but_not_judged() -> None:
    card = [Review(DAY0, "good"), Review(DAY0 + timedelta(days=3), "good")]
    card += [Review(DAY0 + timedelta(days=9), "again")]
    result = evaluate([card])
    assert result.reviews_scored == 2
    assert result.recall_rate == 0.5
    assert result.fsrs_log_loss is not None and result.baseline_log_loss is not None
    assert result.verdict == "insufficient_data"
    assert [(g.min_days, g.reviews) for g in result.gaps] == [(2, 1), (4, 1)]


def _history(outcome: "random.Random", follows_model: bool, cards: int) -> list[list[Review]]:
    """Synthetic cards reviewed after random gaps (1-90 days). Recall follows FSRS's own
    prediction, or is a coin flip whatever the gap."""
    history = []
    for _ in range(cards):
        reviews = [Review(DAY0, "good")]
        state = initial_state("good")
        day = DAY0
        for _ in range(10):
            gap = outcome.randint(1, 90)
            day += timedelta(days=gap)
            p = retrievability(gap, state.stability) if follows_model else 0.5
            rating: Rating = "good" if outcome.random() < p else "again"
            reviews.append(Review(day, rating))
            state = next_state(state, rating, gap)
        history.append(reviews)
    return history


def test_fsrs_wins_only_when_it_predicts_recall_better() -> None:
    cards = MIN_CARDS + 50
    fits = evaluate(_history(random.Random(7), True, cards))  # noqa: S311 - test data
    assert fits.reviews_scored >= MIN_REVIEWS
    assert fits.verdict == "fsrs_fits_better"
    assert fits.calibration and all(0 <= b.actual <= 1 for b in fits.calibration)

    noise = evaluate(_history(random.Random(7), False, cards))  # noqa: S311 - test data
    assert noise.verdict == "no_clear_gain"


def _review(owner: uuid.UUID, card: str, day: int, rating: str) -> SyncItem:
    return SyncItem(
        owner_id=owner,
        entity="card_review",
        item_id=str(uuid.uuid4()),
        data={
            "card_id": card,
            "reviewed_at": f"2026-03-{day:02d}T08:00:00+00:00",
            "rating": rating,
            "due_before": "2026-03-01",
            "due_after": "2026-03-02",
            "gap_days": 1,
        },
    )


def test_history_is_read_per_account_and_card_and_reported_without_ids(
    db_session: Session, user: User
) -> None:
    other = make_user(db_session, "second@example.com")
    card = str(uuid.uuid4())
    db_session.add_all(
        [
            _review(user.id, card, 1, "good"),
            _review(user.id, card, 4, "again"),
            _review(other.id, card, 2, "good"),  # same card id, other account: another card
            _review(other.id, card, 9, "good"),
            SyncItem(owner_id=user.id, entity="card_review", item_id="x", data={"rating": "?"}),
            SyncItem(owner_id=user.id, entity="card_review", item_id="y", deleted=True),
        ]
    )
    db_session.flush()

    cards, accounts = card_histories(db_session)
    assert accounts == 2
    assert sorted(len(c) for c in cards) == [2, 2]

    printed = report(evaluate(cards), accounts)
    assert printed["reviews_scored"] == 2
    assert printed["recall_rate"] == 0.5
    text = repr(printed)
    assert str(user.id) not in text and card not in text
