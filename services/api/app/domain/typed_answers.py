"""Typed-in answers ("TITA": type in the answer) - pure rules.

A typed answer is stored as text exactly as the paper or reviewer gave it (whitespace tidied).
Checking a learner's answer:

- both numbers (e.g. "2.5" and "2.50", "-15" and "-15.0") -> equal by value;
- otherwise (e.g. a sentence order "3142") -> equal after removing spaces and ignoring case.

Nothing is rounded or guessed: "2.49" is not "2.5".
"""

import re
import unicodedata
from decimal import Decimal, InvalidOperation

MAX_TYPED_ANSWER = 100
_NUMBER = re.compile(r"^[+-]?(?:\d+(?:\.\d*)?|\.\d+)$")
_GROUPED = re.compile(r"^[+-]?\d{1,3}(?:,\d{3})+(?:\.\d+)?$")
# "Correct Answer: Sentence 5" / "Statement 3" names the number to key in.
_ITEM_REFERENCE = re.compile(r"^(?:sentence|statement)\s*(\d{1,2})$", re.IGNORECASE)
# "3-4-2-1", "3, 4, 2, 1", "3 4 2 1": an order of numbered items (e.g. a para-jumble).
_ORDER = re.compile(r"^\d(?:\s*[-,]?\s*\d){2,8}$")
_MINUS = chr(0x2212)  # PDF text often uses the minus sign for "-"


def clean(value: str) -> str:
    text = unicodedata.normalize("NFKC", value).replace(_MINUS, "-")
    return " ".join(text.split())[:MAX_TYPED_ANSWER]


def from_paper(value: str) -> str | None:
    """The typed answer an answer line gives: a number ("12", "2.5", "1,000"), an item
    ("Sentence 5" -> "5") or an order ("3-4-2-1" -> "3421"). Anything else -> None (left for the
    reviewer, who can type any answer)."""
    text = clean(value).rstrip(".")
    if not text:
        return None
    item = _ITEM_REFERENCE.match(text)
    if item:
        return item.group(1)
    order = _ORDER.match(text)
    if order:
        return re.sub(r"\D", "", text)  # "3-4-2-1" -> "3421", as it is keyed in
    compact = text.replace(" ", "")
    if _NUMBER.match(compact) or _GROUPED.match(compact):
        return compact
    return None  # words ("see solution") are left to the reviewer


def orders_items(value: str, count: int) -> bool:
    """ "3-4-2-1": an order of the ``count`` listed items (each number once, 1..count)."""
    if not _ORDER.match(clean(value).rstrip(".")):
        return False
    digits = [int(d) for d in re.findall(r"\d", value)]
    return sorted(digits) == list(range(1, count + 1))


def names_an_item(value: str) -> bool:
    """ "Sentence 5" / "Statement 3": the answer is the number of one of the listed items."""
    return bool(_ITEM_REFERENCE.match(clean(value).rstrip(".")))


def _number(value: str) -> Decimal | None:
    compact = clean(value).replace(" ", "")
    if _GROUPED.match(compact):
        compact = compact.replace(",", "")  # thousands separators only: "1,000"
    if not _NUMBER.match(compact):
        return None
    try:
        return Decimal(compact)
    except InvalidOperation:
        return None


def matches(expected: str, given: str) -> bool:
    expected_number, given_number = _number(expected), _number(given)
    if expected_number is not None and given_number is not None:
        return expected_number == given_number
    return clean(expected).replace(" ", "").casefold() == clean(given).replace(" ", "").casefold()


def is_numeric(value: str) -> bool:
    """Whether the expected answer is a number (the app then shows a number keyboard)."""
    return _number(value) is not None
