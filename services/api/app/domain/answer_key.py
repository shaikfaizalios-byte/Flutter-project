"""Matching a separate answer-key file to a paper's questions. Pure.

A key only fills in what is missing. An answer already on a question stays, whoever gave it: if
the key says something else the question is flagged for a person. Questions numbered again in
each section can't be matched by number, so nothing is applied then.
"""

import uuid
from collections import Counter, defaultdict
from collections.abc import Iterable, Sequence
from dataclasses import dataclass, field

from app.domain.segmentation import option_position


@dataclass(frozen=True, slots=True)
class KeyQuestion:
    id: uuid.UUID
    number: int
    answer_position: int | None
    option_count: int


@dataclass(slots=True)
class KeyPlan:
    apply: dict[uuid.UUID, int] = field(default_factory=dict)
    conflicts: dict[uuid.UUID, str] = field(default_factory=dict)
    agreed: int = 0  # the question already had the same answer
    unmatched: list[int] = field(default_factory=list)  # key numbers with no such question
    ambiguous: bool = False  # numbers repeat in the paper: nothing could be matched


def plan_key(questions: Sequence[KeyQuestion], entries: Iterable[tuple[int, str]]) -> KeyPlan:
    plan = KeyPlan()
    key: dict[int, set[int]] = defaultdict(set)
    for number, label in entries:
        key[number].add(option_position(label))
    if not key:
        return plan
    counts = Counter(q.number for q in questions)
    if any(count > 1 for count in counts.values()):
        plan.ambiguous = True
        return plan
    by_number = {q.number: q for q in questions}
    plan.unmatched = sorted(n for n in key if n not in by_number)
    for number, positions in key.items():
        question = by_number.get(number)
        if question is None:
            continue
        if len(positions) > 1:
            plan.conflicts[question.id] = f"The key gives several answers: {sorted(positions)}"
            continue
        position = next(iter(positions))
        if position > question.option_count:
            plan.conflicts[question.id] = f"The key's answer {position} isn't one of the options"
        elif question.answer_position is None:
            plan.apply[question.id] = position
        elif question.answer_position == position:
            plan.agreed += 1
        else:
            plan.conflicts[question.id] = (
                f"Answer {question.answer_position} is set, but the key says {position}"
            )
    return plan
