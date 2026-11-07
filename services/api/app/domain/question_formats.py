"""Question formats: how a question is answered and marked. Pure.

Most formats keep the answer where it always was: one correct option (``correct_option_position``
on the question), a typed answer, or a written one. They differ only in how they are shown.
The rest keep theirs in ``answer_spec``:

- multiple_correct: {"correct_positions": [1, 3]}; every correct option and no other is needed
- numeric: {"value": "2.5", "tolerance": "0.01"} or {"min": "2.4", "max": "2.6"}, as text so no
  precision is lost; compared as decimals, nothing is rounded
- fill_blank: {"accepted": ["mitochondria"]}; any of them, ignoring case and spacing
- match: {"left": [...], "right": [...], "pairs": [[0, 2], [1, 0]]}; exactly these pairs
- ordering: {"items": [...], "order": [2, 0, 1]}; exactly this order

Partial marks come from the exam's marking rules, not from here.
"""

import unicodedata
from collections.abc import Mapping, Sequence
from decimal import Decimal, InvalidOperation
from typing import Any

from app.domain import typed_answers

# One correct option, shown in different ways.
SINGLE_ANSWER = ("single_correct", "assertion_reason", "statement", "true_false")
# What every typed-in question was before formats existed: compared by typed_answers.
TYPED_IN = "typed_in"
DESCRIPTIVE = "descriptive"
# Answered through ``SessionAnswer.response``.
RESPONSE_FORMATS = ("multiple_correct", "match", "ordering")
# Typed, but marked by their ``answer_spec``.
TYPED_SPEC_FORMATS = ("numeric", "fill_blank")
SPEC_FORMATS = (*RESPONSE_FORMATS, *TYPED_SPEC_FORMATS)
FORMATS = (*SINGLE_ANSWER, TYPED_IN, DESCRIPTIVE, *SPEC_FORMATS)
# Formats that list their own items instead of using the question's options.
OWN_ITEMS = ("match", "ordering")

MAX_ITEMS = 12
MAX_ACCEPTED = 20


def answer_type_of(format_name: str) -> str:
    """Where the answer lives: the existing ``answer_type`` of the format."""
    if format_name == DESCRIPTIVE:
        return "written"
    if format_name == TYPED_IN or format_name in TYPED_SPEC_FORMATS:
        return "typed"
    return "choice"


def _decimal(value: object) -> Decimal | None:
    if isinstance(value, bool) or not isinstance(value, str | int):
        return None
    try:
        number = Decimal(typed_answers.clean(str(value)).replace(",", ""))
    except InvalidOperation:
        return None
    return number if number.is_finite() else None


def _indices(value: object) -> list[int] | None:
    if not isinstance(value, list) or not all(
        isinstance(v, int) and not isinstance(v, bool) for v in value
    ):
        return None
    return value


def _texts(value: object) -> list[str] | None:
    if not isinstance(value, list) or not value or len(value) > MAX_ITEMS:
        return None
    if not all(isinstance(v, str) and v.strip() for v in value):
        return None
    return value


def _pairs(value: object) -> set[tuple[int, int]] | None:
    if not isinstance(value, list):
        return None
    pairs: set[tuple[int, int]] = set()
    for pair in value:
        numbers = _indices(pair)
        if numbers is None or len(numbers) != 2:
            return None
        pairs.add((numbers[0], numbers[1]))
    return pairs


def spec_problems(format_name: str, spec: Mapping[str, Any] | None, option_count: int) -> list[str]:
    """Why ``spec`` can't mark this format (empty: it can)."""
    if format_name not in FORMATS:
        return ["unknown format"]
    if format_name not in SPEC_FORMATS:
        return [] if spec is None else ["this format keeps its answer elsewhere"]
    if spec is None:
        return ["the answer is missing"]
    if format_name == "multiple_correct":
        positions = _indices(spec.get("correct_positions"))
        if not positions or len(set(positions)) != len(positions):
            return ["give the correct options, each once"]
        if not all(1 <= p <= option_count for p in positions):
            return ["a correct option doesn't exist"]
        return []
    if format_name == "numeric":
        return _numeric_problems(spec)
    if format_name == "fill_blank":
        accepted = spec.get("accepted")
        if _texts(accepted) is None or len(accepted or []) > MAX_ACCEPTED:
            return ["give the accepted answers"]
        return []
    if format_name == "match":
        left, right = _texts(spec.get("left")), _texts(spec.get("right"))
        pairs = _pairs(spec.get("pairs"))
        if left is None or right is None or not pairs:
            return ["give both lists and the pairs"]
        if not all(0 <= a < len(left) and 0 <= b < len(right) for a, b in pairs):
            return ["a pair points outside the lists"]
        return []
    items = _texts(spec.get("items"))
    order = _indices(spec.get("order"))
    if items is None or len(items) < 2 or order is None:
        return ["give the items and their order"]
    return [] if sorted(order) == list(range(len(items))) else ["the order must use each item once"]


def _numeric_problems(spec: Mapping[str, Any]) -> list[str]:
    if "value" in spec:
        tolerance = _decimal(spec.get("tolerance", "0"))
        if _decimal(spec["value"]) is None or tolerance is None or tolerance < 0:
            return ["give a number and a tolerance of 0 or more"]
        return []
    low, high = _decimal(spec.get("min")), _decimal(spec.get("max"))
    if low is None or high is None or low > high:
        return ["give a number, or a range from low to high"]
    return []


def _fold(text: str) -> str:
    return " ".join(unicodedata.normalize("NFKC", text).casefold().split())


def valid_response(format_name: str, spec: Mapping[str, Any], response: object, count: int) -> bool:
    """Whether ``response`` is an answer this question could take, right or wrong."""
    if not isinstance(response, Mapping):
        return False
    if format_name == "multiple_correct":
        positions = _indices(response.get("positions"))
        return (
            bool(positions)
            and len(set(positions or [])) == len(positions or [])
            and all(1 <= p <= count for p in positions or [])
        )
    if format_name == "match":
        pairs = _pairs(response.get("pairs"))
        return bool(pairs) and all(
            0 <= a < len(spec["left"]) and 0 <= b < len(spec["right"]) for a, b in pairs or set()
        )
    if format_name == "ordering":
        order = _indices(response.get("order"))
        return order is not None and sorted(order) == list(range(len(spec["items"])))
    return False


def is_correct(format_name: str, spec: Mapping[str, Any], answer: object) -> bool:
    """``answer``: the typed text, or the response of a RESPONSE_FORMATS question."""
    if format_name == "numeric":
        return _numeric_correct(spec, answer)
    if format_name == "fill_blank":
        return isinstance(answer, str) and _fold(answer) in {_fold(a) for a in spec["accepted"]}
    if not isinstance(answer, Mapping):
        return False
    if format_name == "multiple_correct":
        return set(answer.get("positions") or []) == set(spec["correct_positions"])
    if format_name == "match":
        return _pairs(answer.get("pairs")) == _pairs(spec["pairs"])
    if format_name == "ordering":
        return bool(answer.get("order") == spec["order"])
    raise ValueError(f"{format_name} isn't marked by its answer_spec")


def partial_marks(
    format_name: str,
    spec: Mapping[str, Any],
    answer: object,
    rule: Mapping[str, Any],
) -> Decimal | None:
    """The marks of a partly right answer under the exam's rule, or None if it earns none.
    Only ``{"per_correct": "1"}`` on multiple_correct exists so far: some correct options chosen
    and no wrong one earn that much each."""
    if format_name != "multiple_correct" or not isinstance(answer, Mapping):
        return None
    chosen = set(answer.get("positions") or [])
    correct = set(spec["correct_positions"])
    if not chosen or chosen - correct or chosen == correct:
        return None
    each = _decimal(rule.get("per_correct"))
    return None if each is None else each * len(chosen)


def _numeric_correct(spec: Mapping[str, Any], answer: object) -> bool:
    given = _decimal(answer) if isinstance(answer, str) else None
    if given is None:
        return False
    if "value" in spec:
        value, tolerance = _decimal(spec["value"]), _decimal(spec.get("tolerance", "0"))
        return value is not None and tolerance is not None and abs(given - value) <= tolerance
    low, high = _decimal(spec["min"]), _decimal(spec["max"])
    return low is not None and high is not None and low <= given <= high


def public_data(
    format_name: str, spec: Mapping[str, Any] | None
) -> dict[str, Sequence[str]] | None:
    """What a learner sees before answering: the lists, never the answer."""
    if spec is None or format_name not in OWN_ITEMS:
        return None
    if format_name == "match":
        return {"left": spec["left"], "right": spec["right"]}
    return {"items": spec["items"]}
