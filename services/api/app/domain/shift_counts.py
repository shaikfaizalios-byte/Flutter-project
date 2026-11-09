"""Counts for "appeared in X of Y shifts" and chapter weightage. Pure.

A shift is one counting unit (app.domain.counting): a sitting where the exam counts sessions, else a
paper. A question without a confirmed year still counts towards the totals, but in no year.
"""

from collections import defaultdict
from collections.abc import Hashable, Iterable
from dataclasses import dataclass


@dataclass(frozen=True, slots=True)
class Counted:
    unit: Hashable
    year: int | None
    session: str | None
    marks: float | None


@dataclass(frozen=True, slots=True)
class YearTally:
    year: int
    questions: int
    shifts: int
    marks: float | None


@dataclass(frozen=True, slots=True)
class SessionTally:
    session: str
    questions: int
    shifts: int


@dataclass(frozen=True, slots=True)
class Tally:
    questions: int
    shifts: int
    marks: float | None
    years: tuple[YearTally, ...]
    sessions: tuple[SessionTally, ...]


def _marks(rows: list[Counted]) -> float | None:
    stated = [r.marks for r in rows if r.marks is not None]
    return sum(stated) if stated else None


def tally(rows: Iterable[Counted]) -> Tally:
    counted = list(rows)
    by_year: dict[int, list[Counted]] = defaultdict(list)
    by_session: dict[str, list[Counted]] = defaultdict(list)
    for row in counted:
        if row.year is not None:
            by_year[row.year].append(row)
        if row.session:
            by_session[row.session].append(row)
    return Tally(
        questions=len(counted),
        shifts=len({r.unit for r in counted}),
        marks=_marks(counted),
        years=tuple(
            YearTally(y, len(group), len({r.unit for r in group}), _marks(group))
            for y, group in sorted(by_year.items())
        ),
        sessions=tuple(
            SessionTally(s, len(group), len({r.unit for r in group}))
            for s, group in sorted(by_session.items())
        ),
    )
