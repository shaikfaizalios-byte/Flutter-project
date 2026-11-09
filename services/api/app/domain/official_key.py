"""Reading answer keys published by question ID, and matching them to a paper. Pure.

A key file lists each "QUESTION ID  CORRECT OPTION ID" pair, for every shift of a session at once.
A typed question has its value instead of an option ID, "41 or 42" when either is accepted, and a
dropped question says "Dropped". Nothing is guessed: an ID the paper doesn't have is reported.
"""

import re
from collections.abc import Iterable, Mapping, Sequence
from dataclasses import dataclass, field
from decimal import Decimal, InvalidOperation
from typing import Any

ENTRY = re.compile(r"^\s*(?P<id>\d{6,})\s+(?P<answer>\S.*?)\s*$")
DROPPED = "dropped"
MIN_ENTRIES = 1


@dataclass(frozen=True, slots=True)
class KeyEntry:
    values: tuple[str, ...]
    dropped: bool = False


@dataclass(frozen=True, slots=True)
class OfficialKey:
    stage: str | None  # provisional | final; None when the file doesn't say
    entries: Mapping[str, KeyEntry]


def read_official_key(pages_text: Iterable[str]) -> OfficialKey:
    text = "\n".join(pages_text)
    upper = text.upper()
    stage = "final" if "FINAL ANSWER KEY" in upper else None
    if "PROVISIONAL ANSWER KEY" in upper:
        stage = "provisional"
    entries: dict[str, KeyEntry] = {}
    for line in text.splitlines():
        match = ENTRY.match(line)
        if match is None:
            continue
        answer = match["answer"]
        if answer.casefold() == DROPPED:
            entries[match["id"]] = KeyEntry((), dropped=True)
        else:
            entries[match["id"]] = KeyEntry(
                tuple(v.strip() for v in re.split(r"\s+or\s+", answer, flags=re.IGNORECASE))
            )
    return OfficialKey(stage, entries)


@dataclass(frozen=True, slots=True)
class KeyTarget:
    """What a question offers a key to match."""

    external_id: str
    number: int
    typed: bool
    options: Mapping[str, int]  # option ID -> position


@dataclass(frozen=True, slots=True)
class KeyDecision:
    external_id: str
    outcome: str  # one | several | dropped
    position: int | None = None
    accepted: tuple[int, ...] | None = None
    spec: Mapping[str, Any] | None = None


@dataclass(slots=True)
class KeyPlan:
    decisions: list[KeyDecision] = field(default_factory=list)
    missing: list[int] = field(default_factory=list)  # question numbers the key doesn't cover
    problems: list[str] = field(default_factory=list)


def _whole(value: str) -> bool:
    try:
        number = Decimal(value)
    except InvalidOperation:
        return False
    return number.is_finite() and number == number.to_integral_value()


def _decide(target: KeyTarget, entry: KeyEntry) -> KeyDecision | str:
    """The decision, or why this entry can't stand."""
    if entry.dropped:
        return KeyDecision(target.external_id, "dropped")
    if target.typed:
        if not all(_whole(v) for v in entry.values):
            return f"Question {target.number}: the key's answer isn't a whole number"
        first, *rest = entry.values
        spec: dict[str, Any] = {"value": first}
        if rest:
            spec["also"] = rest
        return KeyDecision(target.external_id, "one", spec=spec)
    positions = [target.options.get(v) for v in entry.values]
    if None in positions:
        return f"Question {target.number}: the key names an option this paper doesn't have"
    found = tuple(p for p in positions if p is not None)
    if len(found) == 1:
        return KeyDecision(target.external_id, "one", position=found[0])
    return KeyDecision(target.external_id, "several", accepted=found)


def plan_official_key(targets: Sequence[KeyTarget], key: OfficialKey) -> KeyPlan:
    """One decision per question the key covers. The file's other shifts are simply not asked
    about, because a key file covers a whole session."""
    plan = KeyPlan()
    for target in targets:
        entry = key.entries.get(target.external_id)
        if entry is None:
            plan.missing.append(target.number)
            continue
        decision = _decide(target, entry)
        if isinstance(decision, str):
            plan.problems.append(decision)
        else:
            plan.decisions.append(decision)
    return plan
