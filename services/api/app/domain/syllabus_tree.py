"""Which syllabus version applies to which paper. Pure.

An exam's syllabus has versions by effective year (a version with no year applies from the
start). Trees of any depth sit over ``topics``, which questions keep pointing to, so an exam with
one version behaves as if versions didn't exist. Shared versions and a learner's own are
separate lines: the scope is worked out for each and then combined.
"""

import uuid
from collections.abc import Iterable, Sequence
from dataclasses import dataclass

MAX_DEPTH = 8
MAX_NODES = 2000


@dataclass(frozen=True, slots=True)
class VersionRef:
    id: uuid.UUID
    effective_year: int | None
    topic_ids: frozenset[uuid.UUID]


@dataclass(frozen=True, slots=True)
class SyllabusScope:
    # Topics no version in force for these papers has: not part of the question.
    out_of_scope: frozenset[uuid.UUID]
    # In force for the papers, but no longer in the current syllabus.
    dropped: frozenset[uuid.UUID]


def _start(version: VersionRef) -> int:
    return version.effective_year if version.effective_year is not None else -1


def in_force(versions: Sequence[VersionRef], year: int) -> VersionRef | None:
    """The newest version effective by ``year``; for an older paper, the earliest there is."""
    if not versions:
        return None
    started = [v for v in versions if _start(v) <= year]
    return max(started, key=_start) if started else min(versions, key=_start)


def scope_for(
    lines: Iterable[Sequence[VersionRef]], years: Iterable[int], current_year: int
) -> SyllabusScope:
    """``years``: the years of the counted papers (an undated paper counts as the current year).
    With at most one version in a line, nothing is out of scope or dropped."""
    wanted = set(years)
    forced: set[uuid.UUID] = set()
    current: set[uuid.UUID] = set()
    known: set[uuid.UUID] = set()
    for versions in lines:
        latest = in_force(versions, current_year)
        if latest is None:
            continue
        current |= latest.topic_ids
        for version in versions:
            known |= version.topic_ids
        for year in wanted or {current_year}:
            found = in_force(versions, year)
            if found is not None:
                forced |= found.topic_ids
    return SyllabusScope(
        out_of_scope=frozenset(known - forced), dropped=frozenset(forced - current)
    )


def outline_size(nodes: Sequence[object], children_of: str = "children") -> tuple[int, int]:
    """(number of nodes, depth) of a tree of objects with a ``children`` attribute."""
    count, depth = 0, 0
    for node in nodes:
        below, below_depth = outline_size(getattr(node, children_of), children_of)
        count += 1 + below
        depth = max(depth, 1 + below_depth)
    return count, depth
