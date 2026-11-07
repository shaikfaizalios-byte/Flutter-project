"""Rules of the curated question library. Pure.

A question reaches learners only once it is approved and its rights are settled. Nobody checks their
own work: the second solve and the approval each need someone other than the author. Difficulty
starts as assigned and moves only on real attempts. All numbers come from defaults.json.
"""

from collections.abc import Sequence
from dataclasses import dataclass
from functools import cache

from app.domain.exam_profile import library_settings

SOURCE_TYPES = ("official_pyq", "original_expert", "original_ai_verified")
RIGHTS = ("licensed", "owned", "pending")
VISIBLE_RIGHTS = ("licensed", "owned")
DRAFT, SOLVED, APPROVED, WITHDRAWN = "draft", "solved", "approved", "withdrawn"
LEVELS = ("easy", "medium", "hard")


def is_visible(status: str, rights: str) -> bool:
    return status == APPROVED and rights in VISIBLE_RIGHTS


def solve_problem(*, status: str, author_id: object, solver_id: object) -> str | None:
    if status != DRAFT:
        return "Only a draft can be solved."
    return "The author can't be the second solver." if author_id == solver_id else None


def approve_problem(*, status: str, author_id: object, approver_id: object) -> str | None:
    if status != SOLVED:
        return "A second reviewer has to solve it first."
    return "The author can't approve their own question." if author_id == approver_id else None


@dataclass(frozen=True, slots=True)
class Band:
    level: str
    min_accuracy: float


@cache
def _bands() -> tuple[Band, ...]:
    return tuple(Band(b["level"], float(b["min_accuracy"])) for b in library_settings()["bands"])


def calibrated(
    attempts: int, correct: int, median_ms: int | None, base_seconds: float | None
) -> str | None:
    """The level real attempts show, or None until there are enough. Accuracy sets the band; a
    question that takes much longer than the paper allows moves one level harder."""
    settings = library_settings()
    if attempts < int(settings["calibration_min_attempts"]):
        return None
    accuracy = correct / attempts
    level = next(b.level for b in _bands() if accuracy >= b.min_accuracy)
    limit = None if base_seconds is None else base_seconds * float(settings["slow_multiple"]) * 1000
    if limit is not None and median_ms is not None and median_ms > limit:
        return LEVELS[min(LEVELS.index(level) + 1, len(LEVELS) - 1)]
    return level


def shown_level(assigned: str, observed: str | None) -> str:
    return observed or assigned


def percent_right(attempts: int, correct: int) -> int | None:
    """Only from real attempts, and only once there are enough to mean something."""
    if attempts < int(library_settings()["percent_min_attempts"]):
        return None
    return round(correct * 100 / attempts)


def median(values: Sequence[int]) -> int | None:
    ordered = sorted(values)
    if not ordered:
        return None
    middle = len(ordered) // 2
    if len(ordered) % 2:
        return ordered[middle]
    return (ordered[middle - 1] + ordered[middle]) // 2
