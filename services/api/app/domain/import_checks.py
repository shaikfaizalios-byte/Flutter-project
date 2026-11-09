"""Checks on an imported paper against its exam format. Pure.

Each one is a fact to look at, never a correction: question counts per section, a key for every
question, and formats that fit their section.
"""

from collections import Counter
from collections.abc import Mapping, Sequence
from dataclasses import dataclass
from typing import Any

from app.domain.segmentation import same_subject


@dataclass(frozen=True, slots=True)
class CheckedQuestion:
    number: int
    section: str | None
    format: str
    has_key: bool


@dataclass(frozen=True, slots=True)
class SectionCount:
    section: str
    expected: int
    found: int


@dataclass(frozen=True, slots=True)
class ImportCheck:
    sections: tuple[SectionCount, ...]
    problems: tuple[str, ...]

    @property
    def ok(self) -> bool:
        return not self.problems


def section_name(section: Mapping[str, Any]) -> str:
    """How the paper names a section: "Mathematics Section A", or just the subject."""
    subject, part = str(section.get("subject") or ""), str(section.get("part") or "")
    return f"{subject} {part}" if part.startswith("Section") else subject


def _section_of(
    question: CheckedQuestion, sections: Sequence[Mapping[str, Any]]
) -> Mapping[str, Any] | None:
    for section in sections:
        if question.section and same_subject(question.section, section_name(section)):
            return section
    return None


def check_import(
    sections: Sequence[Mapping[str, Any]], questions: Sequence[CheckedQuestion]
) -> ImportCheck:
    problems: list[str] = []
    found: Counter[str] = Counter()
    for question in questions:
        section = _section_of(question, sections)
        if section is None:
            problems.append(f"Question {question.number} isn't in a section of this format")
            continue
        found[section_name(section)] += 1
        allowed = section.get("formats")
        if allowed and question.format not in allowed:
            problems.append(
                f"Question {question.number} is {question.format}; "
                f"{section_name(section)} takes {', '.join(allowed)}"
            )
    counts = tuple(
        SectionCount(section_name(s), int(s["questions"]), found[section_name(s)]) for s in sections
    )
    problems += [
        f"{c.section}: {c.found} questions, the format has {c.expected}"
        for c in counts
        if c.found != c.expected
    ]
    keyless = sorted(q.number for q in questions if not q.has_key)
    if keyless:
        shown = ", ".join(map(str, keyless[:20]))
        problems.append(f"{len(keyless)} questions have no key: {shown}")
    return ImportCheck(counts, tuple(problems))
