"""Canonical topics: one id per subject or topic, whatever an exam or a learner calls it. Pure.

Exam-specific topics (shared syllabus topics and learners' own) keep their own wording; a link
says which canonical topic they mean. Links are only *suggested* by rules (the same name as a
canonical label, ignoring case, spacing, "&"/"and" and a plural "s") and count only once
confirmed, so a guess never merges two different topics in analytics.
"""

import re
import unicodedata
from collections.abc import Mapping, Sequence
from dataclasses import dataclass

_SPACES = re.compile(r"\s+")
_NON_WORD = re.compile(r"[^\w\s]")
_SAME_IN_PLURAL = frozenset({"series", "species", "mathematics", "physics", "economics"})


def normalize(label: str) -> str:
    """Comparable form of a topic name ("Ratio & Proportions" ~ "ratio and proportion")."""
    text = unicodedata.normalize("NFC", label).casefold().replace("&", " and ")
    text = _NON_WORD.sub(" ", text)
    return " ".join(_singular(w) for w in _SPACES.split(text.strip()) if w)


def _singular(word: str) -> str:
    """A simple English plural: analogies → analogy, series stays, relations → relation."""
    if word in _SAME_IN_PLURAL:
        return word
    if len(word) > 4 and word.endswith("ies"):
        return word[:-3] + "y"
    if len(word) > 3 and word.endswith("s") and not word.endswith(("ss", "ies")):
        return word[:-1]
    return word


def slug(label: str) -> str:
    """Stable key part of a canonical node: "Time, Speed and Distance" → time-speed-and-distance."""
    return re.sub(r"[^a-z0-9]+", "-", unicodedata.normalize("NFKD", label).casefold()).strip("-")


@dataclass(frozen=True, slots=True)
class Suggestion:
    node_id: str
    reason: str


def suggest(name: str, labels: Mapping[str, Sequence[str]]) -> Suggestion | None:
    """A canonical topic for ``name`` when exactly one topic node has a label with the same
    normalized form; ``labels`` maps node id → its labels (all languages, aliases included).
    Two or more candidates, or none: no suggestion (never a guess between topics)."""
    key = normalize(name)
    if not key:
        return None
    matches = [node for node, names in labels.items() if any(normalize(n) == key for n in names)]
    if len(matches) != 1:
        return None
    return Suggestion(matches[0], f'Same name as the shared topic "{name.strip()[:80]}"')
