"""Typed-in (TITA) answers: what counts as the same answer."""

import pytest

from app.domain import typed_answers

MINUS = chr(0x2212)


@pytest.mark.parametrize(
    ("expected", "given", "same"),
    [
        ("2.5", "2.50", True),
        ("2.5", "2.49", False),  # never rounded
        ("-15", MINUS + "15.0", True),  # minus sign from PDF text
        ("12", " 12 ", True),
        ("3421", "3 4 2 1", True),
        ("3421", "3412", False),
        ("Delhi", "delhi", True),
        ("1,000", "1000", True),
    ],
)
def test_matches(expected: str, given: str, same: bool) -> None:
    assert typed_answers.matches(expected, given) is same


@pytest.mark.parametrize(
    ("line", "typed"),
    [
        ("12", "12"),
        ("Sentence 5", "5"),
        ("3-4-2-1", "3421"),
        ("2.5.", "2.5"),
        ("(b) and (c)", None),
        ("see solution", None),
        ("1,000", "1000"),  # same value; stored as keyed in
        ("", None),
    ],
)
def test_from_paper(line: str, typed: str | None) -> None:
    assert typed_answers.from_paper(line) == typed


def test_orders_and_numeric() -> None:
    assert typed_answers.orders_items("3-4-2-1", 4)
    assert not typed_answers.orders_items("3-4-2-2", 4)
    assert typed_answers.is_numeric("-2.5") and typed_answers.is_numeric("1,000")
    assert not typed_answers.is_numeric("3,4")
