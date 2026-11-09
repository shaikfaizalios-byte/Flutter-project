"""Answer-key states. Pure.

A question's key can be provisional or final. It can have one answer, accept several, or be dropped,
which gives every candidate the marks. Exam notices state these outcomes; this only checks that a
key is one the question can have. Past attempts are re-marked once a key is final.
"""

from collections.abc import Sequence

from app.domain.question_formats import SINGLE_ANSWER

STAGES = ("provisional", "final")
ONE, SEVERAL, DROPPED = "one", "several", "dropped"
OUTCOMES = (ONE, SEVERAL, DROPPED)


def key_problems(
    *, format_name: str, outcome: str, accepted: Sequence[int] | None, option_count: int
) -> list[str]:
    """Why this key can't stand (empty: it can)."""
    if outcome not in OUTCOMES:
        return ["unknown outcome"]
    if outcome != SEVERAL:
        return [] if not accepted else ["only several answers can list accepted options"]
    if format_name not in SINGLE_ANSWER:
        return ["several accepted answers apply to questions with one correct option"]
    positions = list(accepted or [])
    if len(positions) < 2 or len(set(positions)) != len(positions):
        return ["give at least two accepted options, each once"]
    if not all(1 <= p <= option_count for p in positions):
        return ["an accepted option doesn't exist"]
    return []


def answer_changed(before: Sequence[object], after: Sequence[object], stage: str | None) -> bool:
    """A provisional key became final with a different answer or outcome."""
    return stage == "final" and before != after
