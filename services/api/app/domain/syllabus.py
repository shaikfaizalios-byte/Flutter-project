"""Reading subjects and topics from a syllabus PDF's text - pure rules, no AI.

A syllabus lists subjects as heading lines with topics under them. Headings are recognised
when they end with ":" ("Reasoning:"), are written in capitals ("GENERAL AWARENESS"), carry a
part/section label ("PART B: General Awareness", "Section 2 - English"), or name a known
subject ("Quantitative Aptitude", or one of the exam's own subjects). Topics are written as
bullets or numbered lines ("• Percentage", "1. Profit and Loss", "(a) Ratio"), one per line,
or as comma/semicolon separated runs ("Number System, Percentage, Averages."); "Subject: topic,
topic" on one line works too. Topics before any heading go under "General".

Nothing is saved from here: the learner reviews the draft, unticks what doesn't belong and
saves the rest. Lines that look like notes, marks, dates or sentences are left out, so a noisy
PDF gives fewer topics rather than wrong ones.
"""

import re
import unicodedata
from collections.abc import Iterable, Sequence
from dataclasses import dataclass, field

MAX_NAME = 100  # same limits as topics (app/schemas/exam.py)
MIN_NAME = 2
MAX_TOPICS = 300
MAX_TOPIC_WORDS = 10
GENERAL = "General"

# Words that make a heading line a subject ("Quantitative Aptitude", "English Language").
SUBJECT_WORDS = (
    "aptitude",
    "reasoning",
    "intelligence",
    "awareness",
    "general knowledge",
    "general studies",
    "current affairs",
    "english",
    "hindi",
    "language",
    "comprehension",
    "verbal ability",
    "mathematics",
    "quantitative",
    "numerical ability",
    "data interpretation",
    "logical",
    "computer",
    "science",
    "physics",
    "chemistry",
    "biology",
    "history",
    "geography",
    "polity",
    "economy",
    "economics",
)

_BULLET = re.compile(r"^\s*(?:[•●▪■◦○·\-\u2013\u2014*➢➤►]|o\s)\s*(.+)$")
_NUMBERED = re.compile(
    r"^\s*\(?(?:\d{1,2}|[a-z]|i{1,3}|iv|v|vi{1,3}|ix|x)[.)]\s+(.+)$", re.IGNORECASE
)
_SECTION_LABEL = re.compile(
    r"^\s*(?:part|section|paper|unit|module)\s*[-\u2013:]?\s*[A-Z0-9IVX]{1,4}\s*[-\u2013:.)]?\s*(.*)$",
    re.IGNORECASE,
)
_SUBJECT_LINE = re.compile(r"^([^:]{2,60}):\s*(.*)$")
_SPLIT = re.compile(r"\s*[;,]\s*")
# Notes, marks, timings, dates and links: never topics or headings.
_NOISE = re.compile(
    r"\b(?:marks?|minutes?|hours?|duration|negative|note|page|notification|official|website|"
    r"time\s+allowed|total|questions?|mcqs?|syllabus|exam(?:ination)?\s+pattern|"
    r"scheme\s+of\s+exam)\b"
    r"|www\.|https?://|\b(?:19|20)\d{2}\b",
    re.IGNORECASE,
)


@dataclass(slots=True)
class SyllabusSubject:
    name: str
    topics: list[str] = field(default_factory=list)


@dataclass(slots=True)
class SyllabusDraft:
    subjects: list[SyllabusSubject]
    topic_count: int
    truncated: bool = False  # more than MAX_TOPICS were found; the rest were left out


def _clean(text: str) -> str:
    text = unicodedata.normalize("NFC", text)
    return re.sub(r"\s+", " ", text).strip(" .;:,-\u2013\u2014•\t")


def _topic_ok(name: str) -> bool:
    return (
        MIN_NAME <= len(name) <= MAX_NAME
        and len(name.split()) <= MAX_TOPIC_WORDS
        and not _NOISE.search(name)
        and any(c.isalpha() for c in name)
    )


_SMALL_WORDS = frozenset({"and", "of", "the", "in", "for", "to", "on", "with"})


def _title(text: str) -> str:
    """ "GENERAL AWARENESS" -> "General Awareness" (small words stay lower case)."""
    if not text.isupper():
        return text
    words = text.title().split(" ")
    return " ".join(
        w.lower() if i and w.lower() in _SMALL_WORDS else w for i, w in enumerate(words)
    )


def _heading(line: str, known: frozenset[str]) -> str | None:
    """The subject named by a heading line, or None when the line isn't a heading."""
    raw = line.strip()
    section = _SECTION_LABEL.match(raw)
    labelled = section is not None
    text = _clean(section.group(1) if section else raw)
    if not (MIN_NAME <= len(text) <= 60) or _NOISE.search(text):
        return None
    if "," in text or ";" in text or text.endswith((".", "?")) or len(text.split()) > 7:
        return None
    folded = text.casefold()
    if (
        labelled
        or raw.endswith(":")
        or (text.isupper() and len(text) > 3)
        or folded in known
        or any(word in folded for word in SUBJECT_WORDS)
    ):
        return _title(text)
    return None


def _items(text: str) -> list[str]:
    parts = [p for p in (_clean(part) for part in _SPLIT.split(text)) if p]
    # "Time, Speed and Distance": a short "A, B and C" run is one topic's name, not a list.
    if 1 < len(parts) <= 3 and " and " in parts[-1] and all(len(p.split()) <= 3 for p in parts):
        return [_clean(text)]
    return parts


def parse_syllabus(pages: Sequence[str], known_subjects: Iterable[str] = ()) -> SyllabusDraft:
    known = frozenset(s.strip().casefold() for s in known_subjects if s.strip())
    subjects: dict[str, SyllabusSubject] = {}
    seen: set[tuple[str, str]] = set()
    total = 0
    truncated = False
    current = GENERAL

    def add(subject: str, topic: str) -> None:
        nonlocal total, truncated
        name = _title(_clean(topic))
        if not _topic_ok(name) or name.casefold() == subject.casefold():
            return
        key = (subject.casefold(), name.casefold())
        if key in seen:
            return
        if total >= MAX_TOPICS:
            truncated = True
            return
        seen.add(key)
        subjects.setdefault(subject, SyllabusSubject(subject)).topics.append(name)
        total += 1

    for page in pages:
        for raw in page.splitlines():
            line = raw.strip()
            if not line or len(line) > 400:
                continue
            item = _BULLET.match(line) or _NUMBERED.match(line)
            body = item.group(1) if item else line
            labelled = _SUBJECT_LINE.match(body)
            if labelled:
                heading = _heading(labelled.group(1) + ":", known)
                if heading:
                    current = heading
                    for topic in _items(labelled.group(2)):
                        add(current, topic)
                    continue
            heading = None if item else _heading(line, known)
            if heading:
                current = heading
                continue
            parts = _items(body)
            if len(parts) > 1 or item:
                for topic in parts:
                    add(current, topic)
            elif parts and not body.endswith("."):
                add(current, parts[0])  # one topic per line ("Profit and Loss")

    result = [s for s in subjects.values() if s.topics]
    return SyllabusDraft(subjects=result, topic_count=total, truncated=truncated)
