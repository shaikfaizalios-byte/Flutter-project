"""An offline check of FSRS against the learners' own revision history (global Phase 9).

The app schedules flashcards with a fixed ladder (docs/revision.md). FSRS ("Free Spaced
Repetition Scheduler") predicts, for every review, how likely the learner is to recall the card.
Before FSRS could ever become the default it must predict our learners' real outcomes better
than a plain guess, so this module replays synced ``card_review`` events and measures that.
Nothing here schedules a card or changes any setting.

Model: the FSRS-4.5 formulas with its published default weights (open-spaced-repetition).
They are not fitted to PrepLoop's data; check them against the reference implementation before
relying on a result. Days are whole calendar days between reviews (UTC); same-day repeats update
the card but are not scored (FSRS treats them as short-term reviews).
"""

import math
from collections.abc import Iterable, Sequence
from dataclasses import dataclass, field
from datetime import date
from typing import Literal

Rating = Literal["again", "hard", "good", "easy"]
GRADES: dict[str, int] = {"again": 1, "hard": 2, "good": 3, "easy": 4}

DEFAULT_WEIGHTS: tuple[float, ...] = (
    0.4872, 1.4003, 3.7145, 13.8206, 5.1618, 1.2298, 0.8975, 0.031, 1.6474,
    0.1367, 1.0461, 2.1072, 0.0793, 0.3246, 1.587, 0.2272, 2.8755,
)  # fmt: skip
DECAY = -0.5
FACTOR = 19 / 81  # so that recall is 90 % after S days

# The verdict needs at least this much scored history, and FSRS's log loss must be lower than
# the constant guess's by this share. Product choices, not research results.
MIN_REVIEWS = 1000
MIN_CARDS = 100
CLEAR_GAIN = 0.05

# Gap bands (days) for the ladder's own recall rates.
GAP_BANDS: tuple[tuple[int, int], ...] = ((1, 1), (2, 3), (4, 7), (8, 14), (15, 30), (31, 365_000))
_EPS = 1e-6


@dataclass(frozen=True)
class Review:
    reviewed_on: date
    rating: Rating


@dataclass(frozen=True)
class CardState:
    stability: float  # days until recall falls to 90 %
    difficulty: float  # 1 (easy) .. 10 (hard)


def retrievability(elapsed_days: float, stability: float) -> float:
    """Predicted chance of recalling a card ``elapsed_days`` after its last review."""
    return float((1 + FACTOR * max(0.0, elapsed_days) / stability) ** DECAY)


def _clamp_difficulty(d: float) -> float:
    return min(10.0, max(1.0, d))


def _initial_difficulty(grade: int, w: Sequence[float]) -> float:
    return w[4] - (grade - 3) * w[5]


def initial_state(rating: Rating, w: Sequence[float] = DEFAULT_WEIGHTS) -> CardState:
    grade = GRADES[rating]
    return CardState(
        stability=max(0.1, w[grade - 1]),
        difficulty=_clamp_difficulty(_initial_difficulty(grade, w)),
    )


def next_state(
    state: CardState, rating: Rating, elapsed_days: float, w: Sequence[float] = DEFAULT_WEIGHTS
) -> CardState:
    grade = GRADES[rating]
    s, d = state.stability, state.difficulty
    r = retrievability(elapsed_days, s)
    moved = d - w[6] * (grade - 3)
    difficulty = _clamp_difficulty(w[7] * _initial_difficulty(3, w) + (1 - w[7]) * moved)
    if grade == 1:
        stability = w[11] * d ** -w[12] * ((s + 1) ** w[13] - 1) * math.exp(w[14] * (1 - r))
    else:
        hard = w[15] if grade == 2 else 1.0
        easy = w[16] if grade == 4 else 1.0
        growth = math.exp(w[8]) * (11 - d) * s ** -w[9] * (math.exp(w[10] * (1 - r)) - 1)
        stability = s * (1 + growth * hard * easy)
    return CardState(stability=max(0.1, stability), difficulty=difficulty)


def interval_days(stability: float, desired_retention: float = 0.9) -> float:
    """Days until recall is predicted to fall to ``desired_retention``."""
    return float(stability / FACTOR * (desired_retention ** (1 / DECAY) - 1))


@dataclass(frozen=True)
class CalibrationBin:
    low: float
    high: float
    reviews: int
    predicted: float  # mean predicted recall
    actual: float  # share actually recalled


@dataclass(frozen=True)
class GapBand:
    min_days: int
    max_days: int
    reviews: int
    recalled: float


@dataclass(frozen=True)
class Evaluation:
    cards: int
    reviews_scored: int
    recall_rate: float | None
    fsrs_log_loss: float | None
    baseline_log_loss: float | None  # a constant guess = the overall recall rate (in-sample)
    fsrs_rmse: float | None
    baseline_rmse: float | None
    verdict: Literal["insufficient_data", "fsrs_fits_better", "no_clear_gain"]
    calibration: list[CalibrationBin] = field(default_factory=list)
    gaps: list[GapBand] = field(default_factory=list)


def _log_loss(pairs: Sequence[tuple[float, int]]) -> float:
    total = 0.0
    for p, y in pairs:
        p = min(1 - _EPS, max(_EPS, p))
        total -= y * math.log(p) + (1 - y) * math.log(1 - p)
    return total / len(pairs)


def _rmse(pairs: Sequence[tuple[float, int]]) -> float:
    return math.sqrt(sum((p - y) ** 2 for p, y in pairs) / len(pairs))


def evaluate(cards: Iterable[Sequence[Review]], w: Sequence[float] = DEFAULT_WEIGHTS) -> Evaluation:
    """Replays each card's reviews in date order. The first review only sets the card's
    state; every later review on a later day is scored: FSRS's predicted recall against
    whether the learner recalled it (any rating but "again")."""
    scored: list[tuple[float, int, int]] = []  # predicted, recalled, gap days
    card_count = 0
    for reviews in cards:
        ordered = sorted(reviews, key=lambda r: r.reviewed_on)
        if not ordered:
            continue
        card_count += 1
        state = initial_state(ordered[0].rating, w)
        last = ordered[0].reviewed_on
        for review in ordered[1:]:
            gap = (review.reviewed_on - last).days
            if gap > 0:
                predicted = retrievability(gap, state.stability)
                scored.append((predicted, 0 if review.rating == "again" else 1, gap))
            state = next_state(state, review.rating, gap, w)
            last = review.reviewed_on

    if not scored:
        return Evaluation(
            cards=card_count,
            reviews_scored=0,
            recall_rate=None,
            fsrs_log_loss=None,
            baseline_log_loss=None,
            fsrs_rmse=None,
            baseline_rmse=None,
            verdict="insufficient_data",
        )

    pairs = [(p, y) for p, y, _ in scored]
    rate = sum(y for _, y in pairs) / len(pairs)
    constant = [(rate, y) for _, y in pairs]
    fsrs_loss, base_loss = _log_loss(pairs), _log_loss(constant)
    enough = len(pairs) >= MIN_REVIEWS and card_count >= MIN_CARDS
    if not enough:
        verdict: Literal["insufficient_data", "fsrs_fits_better", "no_clear_gain"] = (
            "insufficient_data"
        )
    elif fsrs_loss < base_loss * (1 - CLEAR_GAIN):
        verdict = "fsrs_fits_better"
    else:
        verdict = "no_clear_gain"

    calibration = []
    for i in range(10):
        low, high = i / 10, (i + 1) / 10
        inside = [(p, y) for p, y in pairs if low <= p < high or (i == 9 and p == 1.0)]
        if inside:
            calibration.append(
                CalibrationBin(
                    low=low,
                    high=high,
                    reviews=len(inside),
                    predicted=sum(p for p, _ in inside) / len(inside),
                    actual=sum(y for _, y in inside) / len(inside),
                )
            )
    gaps = []
    for lo, hi in GAP_BANDS:
        band = [y for _, y, g in scored if lo <= g <= hi]
        if band:
            gaps.append(
                GapBand(min_days=lo, max_days=hi, reviews=len(band), recalled=sum(band) / len(band))
            )

    return Evaluation(
        cards=card_count,
        reviews_scored=len(pairs),
        recall_rate=rate,
        fsrs_log_loss=fsrs_loss,
        baseline_log_loss=base_loss,
        fsrs_rmse=_rmse(pairs),
        baseline_rmse=_rmse(constant),
        verdict=verdict,
        calibration=calibration,
        gaps=gaps,
    )
