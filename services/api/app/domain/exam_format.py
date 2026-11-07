"""Checks on exam formats. Pure.

- `format_problems`: every fact a timed mock needs. A mock scores with the format's own numbers
  only: a missing number is never filled in with a default (no negative marks, one mark a
  question, ...), because that would present an invented rule as the official one. A format
  with problems lists them and cannot start a mock.
- `config_problems`: what else a draft needs before a reviewer can publish it (consistent
  section timers, supported answer types, dates, an https official source).
- `in_effect`: whether a format may be used for a new mock today.
"""

from collections.abc import Mapping, Sequence
from dataclasses import dataclass
from datetime import date
from typing import Any

from app.domain.question_formats import SPEC_FORMATS


def _positive_number(value: object) -> bool:
    return isinstance(value, int | float) and not isinstance(value, bool) and value > 0


def _positive_int(value: object) -> bool:
    return isinstance(value, int) and not isinstance(value, bool) and value > 0


def _number(value: object) -> float | None:
    try:
        return float(str(value))
    except ValueError:
        return None


def format_problems(
    *,
    sections: Sequence[Mapping[str, Any]] | None,
    total_questions: int | None,
    duration_minutes: int | None,
    negative_marks_per_wrong: float | None,
    penalty_fraction: float | None = None,
) -> list[str]:
    """What the format does not state (empty when a mock can be built and scored from it).

    ``negative_marks_per_wrong`` must be stated even when it is 0 (no negative marking):
    None means "not verified", not "none". A penalty can instead be stated as
    ``penalty_fraction`` of the question's marks, or as ``marks_wrong`` on every section.
    """
    problems: list[str] = []
    if not sections:
        problems.append("The format lists no sections.")
    else:
        for index, section in enumerate(sections, start=1):
            subject = section.get("subject")
            name = subject.strip() if isinstance(subject, str) and subject.strip() else None
            label = name or f"Section {index}"
            if name is None:
                problems.append(f"Section {index} has no subject.")
            if not _positive_int(section.get("questions")):
                problems.append(f"{label} has no question count.")
            if not _positive_number(section.get("max_marks")):
                problems.append(f"{label} has no maximum marks.")
        counts = [s.get("questions") for s in sections]
        if (
            _positive_int(total_questions)
            and all(_positive_int(c) for c in counts)
            and sum(int(c) for c in counts if c is not None) != total_questions
        ):
            problems.append("The section question counts do not add up to the total.")
    if not _positive_int(total_questions):
        problems.append("The format has no total question count.")
    if not _positive_int(duration_minutes):
        problems.append("The format has no verified duration.")
    every_section = bool(sections) and all(
        isinstance(s.get("marks_wrong"), int | float) for s in sections or []
    )
    if negative_marks_per_wrong is None and penalty_fraction is None and not every_section:
        problems.append("The format does not state its negative marking (0 if there is none).")
    elif negative_marks_per_wrong is not None and negative_marks_per_wrong < 0:
        problems.append("Negative marks must be stated as a deduction of 0 or more.")
    if penalty_fraction is not None and not 0 <= penalty_fraction <= 1:
        problems.append("A penalty fraction must be between 0 and 1.")
    return problems


@dataclass(frozen=True, slots=True)
class SectionMarking:
    marks_correct: float
    marks_wrong: float
    marks_unanswered: float
    partial: Mapping[str, Any] | None


def section_marking(
    section: Mapping[str, Any],
    *,
    negative_marks_per_wrong: float | None,
    penalty_fraction: float | None,
) -> SectionMarking:
    """The marks of one section's questions. A section's own number wins, then the penalty
    fraction, then the format's negative mark. ``format_problems`` has checked one is stated."""
    correct = float(section["max_marks"]) / int(section["questions"])
    wrong = section.get("marks_wrong")
    if wrong is None:
        wrong = (
            correct * penalty_fraction
            if penalty_fraction is not None
            else (negative_marks_per_wrong)
        )
    return SectionMarking(
        marks_correct=correct,
        marks_wrong=float(wrong or 0),
        marks_unanswered=float(section.get("marks_unanswered") or 0),
        partial=section.get("partial"),
    )


SUPPORTED_QUESTION_TYPES = frozenset({"choice", "typed", *SPEC_FORMATS})


def section_key(section: Mapping[str, Any], sections: Sequence[Mapping[str, Any]]) -> str:
    """A section's name in a mock: its subject, with its part where a subject has several."""
    subject = str(section.get("subject") or "")
    repeated = sum(str(s.get("subject") or "") == subject for s in sections) > 1
    return f"{subject} {section.get('part')}" if repeated else subject


def config_problems(
    *,
    sections: Sequence[Mapping[str, Any]] | None,
    duration_minutes: int | None,
    sections_in_fixed_order: bool,
    sectional_timing: bool,
    question_types: Sequence[str],
    effective_from: date | None,
    effective_to: date | None,
    source_title: str,
    source_url: str,
    source_reference: str,
) -> list[str]:
    """What stops a draft format from being published, beyond its scoring facts."""
    problems: list[str] = []
    if not question_types or not set(question_types) <= SUPPORTED_QUESTION_TYPES:
        problems.append(
            "Question types must be among: " + ", ".join(sorted(SUPPORTED_QUESTION_TYPES)) + "."
        )
    keys = [section_key(section, sections or []) for section in sections or []]
    if len(set(keys)) != len(keys):
        # Mocks keep marks and limits by section, so these sections would mark as one.
        problems.append("Two sections have the same subject and part.")
    for section in sections or []:
        rule = section.get("partial")
        if rule is not None and not _positive_number(_number(rule.get("per_correct"))):
            problems.append(f"{section.get('subject')}: the partial rule states no marks.")
        limit = section.get("attempt_limit")
        if limit is not None and not (
            _positive_int(limit) and limit <= int(section.get("questions") or 0)
        ):
            problems.append(f"{section.get('subject')}: the attempt limit doesn't fit the section.")
    if sectional_timing:
        raw = [s.get("timer_minutes") for s in sections or []]
        timers = [t for t in raw if isinstance(t, int) and _positive_int(t)]
        if not raw or len(timers) != len(raw):
            problems.append("Sectional timing needs a timer for every section.")
        elif _positive_int(duration_minutes) and sum(timers) != duration_minutes:
            problems.append("The section timers do not add up to the duration.")
        if not sections_in_fixed_order:
            problems.append("Sectionally timed sections must be taken in a fixed order.")
    if effective_from and effective_to and effective_to < effective_from:
        problems.append("The format ends before it starts.")
    for label, value in (
        ("title", source_title),
        ("URL", source_url),
        ("reference", source_reference),
    ):
        if not value or not value.strip():
            problems.append(f"The official source has no {label}.")
    if source_url and not source_url.startswith("https://"):
        problems.append("The official source URL must be https.")
    return problems


def in_effect(
    *, status: str, effective_from: date | None, effective_to: date | None, today: date
) -> bool:
    """Whether a format can be used for a new mock today (verified and within its dates)."""
    if status != "verified":
        return False
    if effective_from is not None and today < effective_from:
        return False
    return effective_to is None or today <= effective_to
