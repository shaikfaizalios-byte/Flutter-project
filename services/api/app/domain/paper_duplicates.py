"""Is this the same paper in another set? Pure.

Sets of a paper hold the same questions in a different order. The numbers stay in the comparison:
two shifts often ask the same question with different numbers, and those are different papers. A
match is only ever a suggestion; a person confirms it.
"""

from collections import Counter
from collections.abc import Sequence

from app.domain.similarity import normalise

SAME_PAPER_SHARE = 0.9
MIN_QUESTIONS = 5  # too few questions say nothing


def _key(stem: str) -> str:
    return " ".join(normalise(stem, mask_numbers=False))


def shared_share(stems: Sequence[str], others: Sequence[str]) -> float:
    """The share of the shorter paper's questions that the other paper has, word for word."""
    if not stems or not others:
        return 0.0
    mine, theirs = Counter(_key(s) for s in stems), Counter(_key(s) for s in others)
    return sum((mine & theirs).values()) / min(len(stems), len(others))


def looks_like_same_paper(stems: Sequence[str], others: Sequence[str]) -> bool:
    if min(len(stems), len(others)) < MIN_QUESTIONS:
        return False
    return shared_share(stems, others) >= SAME_PAPER_SHARE
