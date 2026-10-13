"""Keyword-based topic *suggestions*. A suggestion is never treated as confirmed; a reviewer
must accept it. When matches are tied or absent, no topic is suggested."""

import re
import uuid
from collections.abc import Sequence
from dataclasses import dataclass

from app.domain.segmentation import same_subject


@dataclass(frozen=True, slots=True)
class TopicCandidate:
    id: uuid.UUID
    subject: str
    name: str
    keywords: Sequence[str]


def subject_for_section(section: str | None, subjects: Sequence[str]) -> str | None:
    """Map a detected section heading to exactly one taxonomy subject, else None."""
    if not section:
        return None
    matches = [s for s in subjects if same_subject(section, s)]
    return matches[0] if len(matches) == 1 else None


def _occurrences(text: str, keyword: str) -> int:
    keyword = keyword.casefold()
    if keyword.replace(" ", "").isalnum() and keyword.isascii():
        return len(re.findall(rf"\b{re.escape(keyword)}\b", text))
    return text.count(keyword)


def suggest_topic(
    stem: str, *, subject: str | None, topics: Sequence[TopicCandidate]
) -> uuid.UUID | None:
    text = stem.casefold()
    pool = [t for t in topics if subject is None or t.subject == subject]
    scores = [(sum(_occurrences(text, k) for k in t.keywords), t.id) for t in pool]
    scores = [s for s in scores if s[0] > 0]
    if not scores:
        return None
    scores.sort(key=lambda s: s[0], reverse=True)
    if len(scores) > 1 and scores[0][0] == scores[1][0]:
        return None  # tie: leave it to the reviewer
    return scores[0][1]
