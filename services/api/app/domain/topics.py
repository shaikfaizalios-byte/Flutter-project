"""Keyword-based topic *suggestions*. A suggestion is never treated as confirmed; a reviewer
must accept it (one by one or all at once). When the best scores tie or nothing matches, no
topic is suggested.

Scoring: every keyword found in the stem scores its number of words (phrases are more
specific than single words), three times as much when it appears in the question's first
sentence, which is where SSC questions state what is asked ("Select the correct passive
form ...", "Given below are four jumbled sentences ..."). A keyword also matches when its first
letters were lost as an unreadable PDF glyph (ligatures like "fi").
"""

import re
import uuid
from collections.abc import Sequence
from dataclasses import dataclass
from functools import lru_cache

from app.domain.segmentation import same_subject
from app.domain.text_quality import UNREADABLE_CHARS

INSTRUCTION_WEIGHT = 3
MAX_REASON_KEYWORDS = 3


@dataclass(frozen=True, slots=True)
class TopicCandidate:
    id: uuid.UUID
    subject: str
    name: str
    keywords: Sequence[str]


@dataclass(frozen=True, slots=True)
class TopicSuggestion:
    topic_id: uuid.UUID
    subject: str
    matched: tuple[str, ...]  # keywords that matched, strongest first

    @property
    def reason(self) -> str:
        shown = ", ".join(f'"{k}"' for k in self.matched[:MAX_REASON_KEYWORDS])
        return f"Matched {shown}"


def subject_for_section(section: str | None, subjects: Sequence[str]) -> str | None:
    """Map a detected section heading to exactly one taxonomy subject, else None."""
    if not section:
        return None
    matches = [s for s in subjects if same_subject(section, s)]
    return matches[0] if len(matches) == 1 else None


@lru_cache(maxsize=2048)
def _pattern(keyword: str) -> re.Pattern[str]:
    keyword = keyword.casefold()
    variants = [re.escape(keyword)] + [
        UNREADABLE_CHARS + re.escape(keyword[k:]) for k in (1, 2) if len(keyword) - k >= 3
    ]
    body = "|".join(variants)
    if keyword.replace(" ", "").isalnum() and keyword.isascii():
        return re.compile(rf"(?<![\w])(?:{body})(?![\w])")
    return re.compile(body)


def _instruction(stem: str) -> str:
    """The first sentence (or line) of the stem."""
    first_line = stem.strip().split("\n", 1)[0]
    match = re.search(r"[.?:](?:\s|$)", first_line)
    return first_line[: match.end()] if match else first_line


def _weight(keyword: str) -> int:
    return max(1, len(keyword.split()))


def suggest_topic(
    stem: str, *, subject: str | None, topics: Sequence[TopicCandidate]
) -> TopicSuggestion | None:
    text = stem.casefold()
    instruction = _instruction(text)
    scored: list[tuple[int, TopicCandidate, tuple[str, ...]]] = []
    for topic in topics:
        if subject is not None and topic.subject != subject:
            continue
        hits: list[tuple[int, str]] = []
        for keyword in topic.keywords:
            pattern = _pattern(keyword)
            if not pattern.search(text):
                continue
            factor = INSTRUCTION_WEIGHT if pattern.search(instruction) else 1
            hits.append((_weight(keyword) * factor, keyword))
        if hits:
            hits.sort(key=lambda h: -h[0])
            scored.append((sum(h[0] for h in hits), topic, tuple(k for _, k in hits)))
    if not scored:
        return None
    scored.sort(key=lambda s: -s[0])
    if len(scored) > 1 and scored[0][0] == scored[1][0]:
        return None  # tie: leave it to the reviewer
    _, best, matched = scored[0]
    return TopicSuggestion(best.id, best.subject, matched)
