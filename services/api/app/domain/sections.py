"""Sectional timers in mocks. Pure.

When a verified format times each section (``sectional_timing``), a mock takes its sections in
order, each with its own timer from the format. A section closes when its time is up or when
the learner finishes it early; a closed section can't be reopened. The plan (positions and
minutes per section) is copied into the session when the mock starts, so later format
changes never change an attempt.
"""

from collections.abc import Sequence
from dataclasses import dataclass
from datetime import datetime, timedelta
from typing import Any


@dataclass(frozen=True, slots=True)
class PlannedSection:
    name: str
    first_position: int  # 1-based, inclusive
    last_position: int
    minutes: int

    def to_json(self) -> dict[str, Any]:
        return {
            "name": self.name,
            "first_position": self.first_position,
            "last_position": self.last_position,
            "minutes": self.minutes,
        }

    @staticmethod
    def from_json(data: dict[str, Any]) -> "PlannedSection":
        return PlannedSection(
            name=str(data["name"]),
            first_position=int(data["first_position"]),
            last_position=int(data["last_position"]),
            minutes=int(data["minutes"]),
        )


@dataclass(frozen=True, slots=True)
class SectionClock:
    """Where a sectional mock is: the open section (index into the plan) and when it opened.
    ``current == len(plan)`` means every section has closed."""

    current: int
    started_at: datetime

    def finished(self, plan: Sequence[PlannedSection]) -> bool:
        return self.current >= len(plan)

    def deadline(self, plan: Sequence[PlannedSection]) -> datetime | None:
        if self.finished(plan):
            return None
        return self.started_at + timedelta(minutes=plan[self.current].minutes)


def advance(plan: Sequence[PlannedSection], clock: SectionClock, now: datetime) -> SectionClock:
    """Closes every section whose time is up; the next one opens when the previous closed."""
    current, started = clock.current, clock.started_at
    while current < len(plan):
        ends = started + timedelta(minutes=plan[current].minutes)
        if now < ends:
            break
        current, started = current + 1, ends
    return SectionClock(current, started)


def finish_early(
    plan: Sequence[PlannedSection], clock: SectionClock, now: datetime
) -> SectionClock:
    """The learner closes the open section now; the next one starts now."""
    if clock.finished(plan):
        return clock
    return SectionClock(clock.current + 1, now)


def section_of(plan: Sequence[PlannedSection], position: int) -> int | None:
    for index, section in enumerate(plan):
        if section.first_position <= position <= section.last_position:
            return index
    return None
