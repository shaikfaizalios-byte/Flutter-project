"""Paper date suggestions: read only what is written, never guess between conflicts."""

from datetime import date

import pytest

from app.domain.paper_date import suggest_paper_date


@pytest.mark.parametrize(
    ("filename", "page", "expected"),
    [
        (
            "ssc-chsl-2-july-2019-shift-3.pdf",
            "SSC CHSL Previous Year Paper [2nd July 3rd Shift]",
            (2019, date(2019, 7, 2), 3),
        ),
        (
            "chsl.pdf",
            "Exam Date : 02/07/2019  Exam Time : 4:00 PM  Shift 3",
            (2019, date(2019, 7, 2), 3),
        ),
        ("cgl 12-08-2022 1st shift.pdf", "", (2022, date(2022, 8, 12), 1)),
        ("paper.pdf", "Test Date 13 March 2023, 2nd Shift", (2023, date(2023, 3, 13), 2)),
        ("cgl-2023-07-24.pdf", "", (2023, date(2023, 7, 24), None)),
        ("SSC CGL Tier 1 2023 paper.pdf", "", (2023, None, None)),
        ("July 14, 2024 morning.pdf", "", (2024, date(2024, 7, 14), None)),
    ],
)
def test_reads_dates_years_and_shifts(
    filename: str, page: str, expected: tuple[int | None, date | None, int | None]
) -> None:
    s = suggest_paper_date(filename, page)
    assert (s.year, s.date, s.shift) == expected
    assert s.reason.startswith("Read from the")


def test_year_inside_a_date_does_not_produce_a_stray_shift() -> None:
    # "2019-shift" must not read the 9 of 2019 as a shift number.
    s = suggest_paper_date("chsl-2019-shift-2.pdf", "")
    assert (s.year, s.shift) == (2019, 2)


def test_conflicts_suggest_nothing_for_that_part() -> None:
    s = suggest_paper_date("chsl-2019.pdf", "Exam Date 05/07/2020")
    assert (s.year, s.date) == (None, None)
    assert "disagree" in s.reason

    s = suggest_paper_date("shift-1.pdf", "Shift 2 on 05/07/2020")
    assert s.date == date(2020, 7, 5) and s.shift is None
    assert "disagree" in s.reason


def test_several_dates_or_years_are_not_picked_from() -> None:
    assert suggest_paper_date("x.pdf", "Held on 01/07/2019 and 02/07/2019").date is None
    assert suggest_paper_date("chsl 2018 2019 combined.pdf", "").year is None


def test_impossible_dates_and_nothing_found() -> None:
    assert suggest_paper_date("31-02-2019.pdf", "").date is None
    s = suggest_paper_date("chsl paper.pdf", "Q1. Select the odd one out.")
    assert s.empty and s.reason == ""
