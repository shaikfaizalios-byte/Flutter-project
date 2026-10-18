"""Session scoring. Pure and deterministic; uses Decimal so marks like 0.50 add up exactly.

* Mock tests: marks come from the verified exam format (section max marks / question count
  for a correct answer; the format's negative marks for a wrong one; 0 when unattempted).
* Practice: 1 point per correct answer, no negative marking (it is practice, not an exam).

The result includes a human-readable explanation of every total so the learner can see
exactly how the score was computed.
"""

from collections.abc import Mapping, Sequence
from dataclasses import dataclass, field
from decimal import ROUND_HALF_UP, Decimal

from app.domain import typed_answers


@dataclass(frozen=True, slots=True)
class ScoredItem:
    position: int
    section: str | None
    topic_id: str | None
    correct_position: int | None  # None for a typed-in question
    marks_correct: Decimal
    marks_wrong: Decimal  # deducted for a wrong answer (>= 0)
    typed_answer: str | None = None  # expected answer of a typed-in question


@dataclass(slots=True)
class Tally:
    correct: int = 0
    wrong: int = 0
    unattempted: int = 0
    score: Decimal = Decimal(0)
    max_score: Decimal = Decimal(0)
    # (count, marks each) per outcome, for the explanation; None when marks vary.
    correct_marks: set[Decimal] = field(default_factory=set)
    wrong_marks: set[Decimal] = field(default_factory=set)

    @property
    def attempted(self) -> int:
        return self.correct + self.wrong

    @property
    def accuracy(self) -> float | None:
        """Share of attempted questions answered correctly (None if nothing attempted)."""
        return None if self.attempted == 0 else self.correct / self.attempted


@dataclass(slots=True)
class ScoreResult:
    total: Tally
    sections: dict[str, Tally]
    topics: dict[str, Tally]
    outcomes: dict[int, bool | None]  # position -> correct / wrong / unattempted (None)


def to_decimal(value: float) -> Decimal:
    return Decimal(str(value))


def is_correct(item: ScoredItem, answer: int | str) -> bool:
    if item.typed_answer is not None:
        return isinstance(answer, str) and typed_answers.matches(item.typed_answer, answer)
    return answer == item.correct_position


def score_session(
    items: Sequence[ScoredItem], selections: Mapping[int, int | str | None]
) -> ScoreResult:
    """``selections`` maps item position to the chosen option position, or the typed answer
    of a typed-in question (None/missing = unattempted)."""
    total = Tally()
    sections: dict[str, Tally] = {}
    topics: dict[str, Tally] = {}
    outcomes: dict[int, bool | None] = {}
    for item in items:
        selected = selections.get(item.position)
        outcome = None if selected is None else is_correct(item, selected)
        outcomes[item.position] = outcome
        tallies = [total]
        if item.section:
            tallies.append(sections.setdefault(item.section, Tally()))
        if item.topic_id:
            tallies.append(topics.setdefault(item.topic_id, Tally()))
        for tally in tallies:
            tally.max_score += item.marks_correct
            if outcome is None:
                tally.unattempted += 1
            elif outcome:
                tally.correct += 1
                tally.score += item.marks_correct
                tally.correct_marks.add(item.marks_correct)
            else:
                tally.wrong += 1
                tally.score -= item.marks_wrong
                tally.wrong_marks.add(item.marks_wrong)
    return ScoreResult(total=total, sections=sections, topics=topics, outcomes=outcomes)


def money(value: Decimal) -> str:
    """Two decimals, half-up (e.g. 22.5 -> '22.50')."""
    return str(value.quantize(Decimal("0.01"), rounding=ROUND_HALF_UP))


def explain(tally: Tally) -> str:
    """'Correct 12 × 2.00 = 24.00; Wrong 3 × −0.50 = −1.50; Unattempted 5 × 0 = 0;
    Total 22.50 of 40.00'."""

    def part(label: str, count: int, marks: set[Decimal], sign: str) -> str:
        if count == 0:
            return f"{label} 0"
        if len(marks) == 1:
            each = next(iter(marks))
            amount = each * count
            return f"{label} {count} × {sign}{money(each)} = {sign}{money(amount)}"
        return f"{label} {count} (marks vary by section)"

    wrong_sign = "−" if any(m > 0 for m in tally.wrong_marks) else ""
    pieces = [
        part("Correct", tally.correct, tally.correct_marks, ""),
        part("Wrong", tally.wrong, tally.wrong_marks, wrong_sign),
        f"Unattempted {tally.unattempted} × 0 = 0",
        f"Total {money(tally.score)} of {money(tally.max_score)}",
    ]
    return "; ".join(pieces)


def tally_json(tally: Tally) -> dict[str, object]:
    return {
        "correct": tally.correct,
        "wrong": tally.wrong,
        "unattempted": tally.unattempted,
        "score": float(tally.score),
        "max_score": float(tally.max_score),
        "accuracy": tally.accuracy,
        "explanation": explain(tally),
    }
