"""Speed training: a target time per question and "right but slow". Pure.

The target comes only from a verified exam format: a timed section's seconds per question, else
the whole paper's (minutes divided by questions). An exam without one has no target unless the
learner sets their own (labelled as theirs). A right answer that took more than ``slow_factor``
times the target is "right but slow". Nothing here is a prediction or a score.
"""

import uuid
from collections.abc import Iterable, Mapping, Sequence
from dataclasses import dataclass, field
from typing import Any, Literal

TargetSource = Literal["format", "own"]


@dataclass(frozen=True, slots=True)
class SpeedTarget:
    seconds: float | None  # the whole paper's, when it states minutes and questions
    by_section: Mapping[str, float]  # timed sections: their own
    source: TargetSource
    format_name: str | None = None

    def for_subject(self, subject: str | None) -> float | None:
        if subject and subject in self.by_section:
            return self.by_section[subject]
        return self.seconds


def format_target(
    *,
    name: str | None,
    duration_minutes: int | None,
    total_questions: int | None,
    sections: Sequence[Mapping[str, Any]],
    sectional_timing: bool,
) -> SpeedTarget | None:
    """The verified format's seconds per question; None when it states neither."""
    seconds = (
        duration_minutes * 60 / total_questions if duration_minutes and total_questions else None
    )
    by_section: dict[str, float] = {}
    if sectional_timing:
        for section in sections:
            subject = str(section.get("subject") or "")
            minutes, questions = section.get("timer_minutes"), section.get("questions")
            if subject and minutes and questions:
                by_section[subject] = float(minutes) * 60 / float(questions)
    if seconds is None and not by_section:
        return None
    return SpeedTarget(seconds, by_section, "format", name)


def own_target(seconds: float | None) -> SpeedTarget | None:
    return SpeedTarget(seconds, {}, "own") if seconds else None


def right_but_slow(
    correct: bool | None, spent_ms: int | None, target: float | None, factor: float
) -> bool:
    return (
        bool(correct)
        and spent_ms is not None
        and target is not None
        and (spent_ms > target * factor * 1000)
    )


@dataclass(slots=True)
class TypeSpeed:
    pattern_id: uuid.UUID
    name: str
    topic: str | None
    subject: str | None
    answered: int = 0
    correct: int = 0
    timed_answered: int = 0
    time_spent_ms: int = 0
    slow_correct: int = 0
    target_seconds: float | None = None
    _targets: set[float] = field(default_factory=set)


@dataclass(frozen=True, slots=True)
class Answered:
    pattern_id: uuid.UUID
    name: str
    topic: str | None
    subject: str | None
    correct: bool | None
    spent_ms: int | None


def speed_by_type(
    answers: Iterable[Answered], target: SpeedTarget | None, slow_factor: float
) -> list[TypeSpeed]:
    """Raw counts per question type, most answered first. A type's target is shown only when
    all its answers share one (its questions sit in one section)."""
    types: dict[uuid.UUID, TypeSpeed] = {}
    for a in answers:
        row = types.get(a.pattern_id)
        if row is None:
            row = types[a.pattern_id] = TypeSpeed(a.pattern_id, a.name, a.topic, a.subject)
        seconds = target.for_subject(a.subject) if target else None
        row.answered += 1
        row.correct += 1 if a.correct else 0
        if a.spent_ms is not None:
            row.timed_answered += 1
            row.time_spent_ms += a.spent_ms
        if seconds is not None:
            row._targets.add(seconds)
        if right_but_slow(a.correct, a.spent_ms, seconds, slow_factor):
            row.slow_correct += 1
    for row in types.values():
        row.target_seconds = next(iter(row._targets)) if len(row._targets) == 1 else None
    return sorted(types.values(), key=lambda t: (-t.answered, t.name))
