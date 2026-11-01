"""Checks that an exam format states every fact a timed mock needs. Pure.

A mock scores with the format's own numbers only: a missing number is never filled in with a
default (no negative marks, one mark a question, ...), because that would present an invented
rule as the official one. A format with problems lists them and cannot start a mock.
"""

from collections.abc import Mapping, Sequence
from typing import Any


def _positive_number(value: object) -> bool:
    return isinstance(value, int | float) and not isinstance(value, bool) and value > 0


def _positive_int(value: object) -> bool:
    return isinstance(value, int) and not isinstance(value, bool) and value > 0


def format_problems(
    *,
    sections: Sequence[Mapping[str, Any]] | None,
    total_questions: int | None,
    duration_minutes: int | None,
    negative_marks_per_wrong: float | None,
) -> list[str]:
    """What the format does not state (empty when a mock can be built and scored from it).

    ``negative_marks_per_wrong`` must be stated even when it is 0 (no negative marking):
    None means "not verified", not "none".
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
    if negative_marks_per_wrong is None:
        problems.append("The format does not state its negative marking (0 if there is none).")
    elif negative_marks_per_wrong < 0:
        problems.append("Negative marks must be stated as a deduction of 0 or more.")
    return problems
