"""Question formats: the pure answer rules."""

from typing import Any

import pytest

from app.domain.question_formats import (
    FORMATS,
    SINGLE_ANSWER,
    answer_type_of,
    is_correct,
    public_data,
    spec_problems,
    valid_response,
)

MATCH = {"left": ["a", "b"], "right": ["x", "y", "z"], "pairs": [[0, 2], [1, 0]]}
ORDER = {"items": ["p", "q", "r"], "order": [2, 0, 1]}


def test_existing_kinds_of_question_keep_their_storage() -> None:
    assert answer_type_of("typed_in") == "typed"
    assert answer_type_of("descriptive") == "written"
    for name in SINGLE_ANSWER:
        assert answer_type_of(name) == "choice"
        assert spec_problems(name, None, 4) == []


@pytest.mark.parametrize(
    ("format_name", "spec"),
    [
        ("multiple_correct", {"correct_positions": [1, 3]}),
        ("multiple_correct", {"correct_positions": [2]}),
        ("numeric", {"value": "2.5"}),
        ("numeric", {"value": "2.5", "tolerance": "0.01"}),
        ("numeric", {"min": "2.4", "max": "2.6"}),
        ("fill_blank", {"accepted": ["Mitochondria", "mitochondrion"]}),
        ("match", MATCH),
        ("ordering", ORDER),
    ],
)
def test_good_specs(format_name: str, spec: dict[str, Any]) -> None:
    assert spec_problems(format_name, spec, 4) == []


@pytest.mark.parametrize(
    ("format_name", "spec"),
    [
        ("multiple_correct", None),
        ("multiple_correct", {"correct_positions": []}),
        ("multiple_correct", {"correct_positions": [1, 1]}),
        ("multiple_correct", {"correct_positions": [5]}),
        ("multiple_correct", {"correct_positions": [True]}),
        ("numeric", {"value": "about two"}),
        ("numeric", {"value": "2", "tolerance": "-1"}),
        ("numeric", {"min": "3", "max": "2"}),
        ("numeric", {"value": "NaN"}),
        ("numeric", {}),
        ("fill_blank", {"accepted": []}),
        ("fill_blank", {"accepted": [" "]}),
        ("match", {"left": ["a"], "right": ["x"], "pairs": []}),
        ("match", {"left": ["a"], "right": ["x"], "pairs": [[0, 1]]}),
        ("ordering", {"items": ["p"], "order": [0]}),
        ("ordering", {"items": ["p", "q"], "order": [0, 0]}),
        ("single_correct", {"correct_positions": [1]}),
        ("descriptive", {"accepted": ["x"]}),
        ("oral", None),
    ],
)
def test_bad_specs_are_refused(format_name: str, spec: dict[str, Any] | None) -> None:
    assert spec_problems(format_name, spec, 4)


def test_multiple_correct_needs_exactly_the_correct_set() -> None:
    spec = {"correct_positions": [1, 3]}
    assert is_correct("multiple_correct", spec, {"positions": [3, 1]})
    assert not is_correct("multiple_correct", spec, {"positions": [1]})
    assert not is_correct("multiple_correct", spec, {"positions": [1, 2, 3]})
    assert not is_correct("multiple_correct", spec, "1")


def test_numeric_tolerance_includes_its_edges_and_nothing_is_rounded() -> None:
    spec = {"value": "2.5", "tolerance": "0.01"}
    assert is_correct("numeric", spec, "2.5")
    assert is_correct("numeric", spec, "2.50")
    assert is_correct("numeric", spec, "2.49")
    assert is_correct("numeric", spec, "2.51")
    assert not is_correct("numeric", spec, "2.511")
    assert not is_correct("numeric", spec, "2.489")
    assert not is_correct("numeric", spec, "two")


def test_numeric_without_tolerance_is_by_value() -> None:
    assert is_correct("numeric", {"value": "15"}, "15.0")
    assert is_correct("numeric", {"value": "-15"}, "−15")  # the PDF minus sign
    assert not is_correct("numeric", {"value": "15"}, "15.01")


def test_decimals_are_exact() -> None:
    assert is_correct("numeric", {"value": "0.3", "tolerance": "0"}, "0.30")
    assert is_correct("numeric", {"value": "0.1", "tolerance": "0.2"}, "0.3")


def test_numeric_range() -> None:
    spec = {"min": "2.4", "max": "2.6"}
    assert is_correct("numeric", spec, "2.4")
    assert is_correct("numeric", spec, "2.6")
    assert not is_correct("numeric", spec, "2.61")


def test_fill_blank_ignores_case_and_spacing_only() -> None:
    spec = {"accepted": ["Golgi body", "Golgi apparatus"]}
    assert is_correct("fill_blank", spec, "  golgi   BODY ")
    assert is_correct("fill_blank", spec, "golgi apparatus")
    assert not is_correct("fill_blank", spec, "golgi")


def test_match_needs_exact_pairing_in_any_order() -> None:
    assert is_correct("match", MATCH, {"pairs": [[1, 0], [0, 2]]})
    assert not is_correct("match", MATCH, {"pairs": [[0, 2]]})
    assert not is_correct("match", MATCH, {"pairs": [[0, 2], [1, 1]]})


def test_ordering_needs_the_exact_order() -> None:
    assert is_correct("ordering", ORDER, {"order": [2, 0, 1]})
    assert not is_correct("ordering", ORDER, {"order": [0, 1, 2]})


def test_a_format_marked_elsewhere_is_refused() -> None:
    with pytest.raises(ValueError, match="answer_spec"):
        is_correct("single_correct", {}, {"x": 1})


@pytest.mark.parametrize(
    ("format_name", "spec", "response", "expected"),
    [
        ("multiple_correct", {}, {"positions": [1, 2]}, True),
        ("multiple_correct", {}, {"positions": []}, False),
        ("multiple_correct", {}, {"positions": [5]}, False),
        ("multiple_correct", {}, {"positions": [1, 1]}, False),
        ("multiple_correct", {}, "1", False),
        ("match", MATCH, {"pairs": [[0, 0]]}, True),
        ("match", MATCH, {"pairs": [[0, 9]]}, False),
        ("match", MATCH, {"pairs": []}, False),
        ("ordering", ORDER, {"order": [1, 0, 2]}, True),
        ("ordering", ORDER, {"order": [1, 0]}, False),
        ("numeric", {}, {"x": 1}, False),
    ],
)
def test_impossible_responses_are_told_apart_from_wrong_ones(
    format_name: str, spec: dict[str, Any], response: Any, expected: bool
) -> None:
    assert valid_response(format_name, spec, response, 4) is expected


def test_learners_see_the_lists_never_the_answer() -> None:
    assert public_data("match", MATCH) == {"left": ["a", "b"], "right": ["x", "y", "z"]}
    assert public_data("ordering", ORDER) == {"items": ["p", "q", "r"]}
    assert public_data("multiple_correct", {"correct_positions": [1]}) is None
    assert public_data("numeric", {"value": "1"}) is None


def test_the_list_of_formats_matches_the_brief() -> None:
    assert len(FORMATS) == 11
