"""Pooling learners' reviewed counts into the shared Repeat Radar.

Pure. Input: one contribution per (account, paper) with the paper's exam shift and the
number of *confirmed* questions per topic and per pattern. Output: per shift, only the counts
that at least ``min_accounts`` different accounts agree on.

- A shift is identified by exam, date and shift number (all confirmed by the reviewer).
- Each account counts once per shift (if it imported the same shift twice, the contribution
  with more classified questions is used).
- A shift is published only when at least ``min_accounts`` accounts contributed.
- For each topic / pattern, the published count is the value reported by at least
  ``min_accounts`` accounts (a topic an account doesn't list counts as 0 for it). If no value
  reaches that, or two values tie, the count is withheld for that shift: one account alone can
  never publish or skew a number.
"""

import datetime as dt
from collections import Counter
from collections.abc import Hashable, Iterable, Mapping
from dataclasses import dataclass, field
from typing import Any

MIN_ACCOUNTS = 2


@dataclass(frozen=True, slots=True)
class ShiftKey:
    exam_code: str
    date: dt.date
    shift: int


@dataclass(frozen=True, slots=True)
class Contribution:
    account: Hashable
    shift: ShiftKey
    topics: Mapping[Any, int]  # topic id -> confirmed questions
    patterns: Mapping[Any, int]  # pattern id -> confirmed questions (topic confirmed too)

    @property
    def size(self) -> int:
        return sum(self.topics.values())


@dataclass(frozen=True, slots=True)
class PooledShift:
    shift: ShiftKey
    accounts: int
    topics: dict[Hashable, int] = field(default_factory=dict)  # agreed counts > 0
    patterns: dict[Hashable, int] = field(default_factory=dict)
    withheld: int = 0  # topics/patterns whose counts the accounts did not agree on


def agreed(values: Iterable[int], min_accounts: int = MIN_ACCOUNTS) -> int | None:
    """The value at least ``min_accounts`` reports share; None if none does or two tie."""
    counts = Counter(values).most_common()
    if not counts or counts[0][1] < min_accounts:
        return None
    if len(counts) > 1 and counts[1][1] == counts[0][1]:
        return None
    return counts[0][0]


def _agree_all(
    per_account: list[Mapping[Hashable, int]], min_accounts: int
) -> tuple[dict[Hashable, int], int]:
    keys = set().union(*(m.keys() for m in per_account)) if per_account else set()
    published: dict[Hashable, int] = {}
    withheld = 0
    for key in keys:
        value = agreed((m.get(key, 0) for m in per_account), min_accounts)
        if value is None:
            withheld += 1
        elif value > 0:
            published[key] = value
    return published, withheld


def pool(
    contributions: Iterable[Contribution], min_accounts: int = MIN_ACCOUNTS
) -> list[PooledShift]:
    best: dict[tuple[ShiftKey, Hashable], Contribution] = {}
    for c in contributions:
        key = (c.shift, c.account)
        if key not in best or c.size > best[key].size:
            best[key] = c
    by_shift: dict[ShiftKey, list[Contribution]] = {}
    for (shift, _), c in best.items():
        by_shift.setdefault(shift, []).append(c)

    result = []
    for shift, items in by_shift.items():
        if len(items) < min_accounts:
            continue
        topics, withheld_topics = _agree_all([c.topics for c in items], min_accounts)
        patterns, withheld_patterns = _agree_all([c.patterns for c in items], min_accounts)
        result.append(
            PooledShift(
                shift=shift,
                accounts=len(items),
                topics=topics,
                patterns=patterns,
                withheld=withheld_topics + withheld_patterns,
            )
        )
    result.sort(key=lambda p: (p.shift.exam_code, p.shift.date, p.shift.shift))
    return result
