"""Post-test analysis of a mock. Pure.

A percentile is shown only from real PrepLoop attempts, with enough accounts behind it, and says so.
It compares scores among PrepLoop users, so it says nothing about a rank in the exam.
"""

from collections.abc import Sequence
from dataclasses import dataclass

from app.domain.exam_profile import mock_analysis_settings


@dataclass(frozen=True, slots=True)
class Percentile:
    percent: int  # share of the attempts below this score
    accounts: int


def percentile(score: float, first_attempts: Sequence[float]) -> Percentile | None:
    """Against each account's first attempt, one each, so repeating a mock can't move it."""
    needed = int(mock_analysis_settings()["percentile_min_accounts"])
    if len(first_attempts) < needed:
        return None
    below = sum(other < score for other in first_attempts)
    return Percentile(round(below * 100 / len(first_attempts)), len(first_attempts))


def sectional_minutes(duration: int, questions: int, total: int) -> int:
    """A section's share of the paper's time. Exams state no time for one section, so this is a
    practice rule, not an exam fact."""
    return max(1, round(duration * questions / total))
