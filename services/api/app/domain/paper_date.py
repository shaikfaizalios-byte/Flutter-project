"""Suggesting when a paper was held (date, year, shift) from its filename and first page.

Only a *suggestion*: the reviewer confirms or corrects it, and year trends use confirmed dates
only. Nothing is guessed beyond what is written: a date needs day, month and year in one of
the listed forms, a shift needs the word "shift" next to its number, and when the filename and
the page disagree, nothing is suggested for that part.
"""

import datetime as dt
import re
from dataclasses import dataclass

MIN_YEAR = 1990
MAX_YEAR = 2100

_MONTHS = {
    name: number
    for number, names in enumerate(
        (
            ("january", "jan"),
            ("february", "feb"),
            ("march", "mar"),
            ("april", "apr"),
            ("may",),
            ("june", "jun"),
            ("july", "jul"),
            ("august", "aug"),
            ("september", "sep", "sept"),
            ("october", "oct"),
            ("november", "nov"),
            ("december", "dec"),
        ),
        start=1,
    )
    for name in names
}
_MONTH = "|".join(sorted(_MONTHS, key=len, reverse=True))
_SEP = r"[\s._/-]*"

# 2 July 2019, 02-jul-2019, 2nd July, 2019
_DAY_MONTH_YEAR = re.compile(
    rf"(?<!\d)(\d{{1,2}})(?:st|nd|rd|th)?{_SEP}({_MONTH})[a-z]*{_SEP},?{_SEP}((?:19|20)\d\d)(?!\d)"
)
# July 2, 2019
_MONTH_DAY_YEAR = re.compile(
    rf"(?<![a-z])({_MONTH})[a-z]*{_SEP}(\d{{1,2}})(?:st|nd|rd|th)?{_SEP},?{_SEP}((?:19|20)\d\d)(?!\d)"
)
# 02/07/2019, 02-07-2019, 02.07.2019 (Indian order: day first)
_NUMERIC_DMY = re.compile(r"(?<!\d)(\d{1,2})[./-](\d{1,2})[./-]((?:19|20)\d\d)(?!\d)")
# 2019-07-02
_NUMERIC_YMD = re.compile(r"(?<!\d)((?:19|20)\d\d)[./-](\d{1,2})[./-](\d{1,2})(?!\d)")
_YEAR = re.compile(r"(?<!\d)((?:19|20)\d\d)(?!\d)")
_SHIFT = re.compile(
    r"shift[\s._-]*(?:no\.?|number)?[\s._:-]*(\d{1,2})(?!\d)|(?<!\d)(\d)(?:st|nd|rd|th)?[\s._-]*shift"
)
# Only the start of the first page is read: where SSC papers print "Exam Date" and "Shift".
FIRST_PAGE_CHARS = 1500


@dataclass(frozen=True, slots=True)
class PaperDateSuggestion:
    year: int | None
    date: dt.date | None
    shift: int | None
    reason: str

    @property
    def empty(self) -> bool:
        return self.year is None and self.shift is None


@dataclass(frozen=True, slots=True)
class _Found:
    year: int | None = None
    date: dt.date | None = None
    shift: int | None = None


def _make_date(year: int, month: int, day: int) -> dt.date | None:
    try:
        return dt.date(year, month, day)
    except ValueError:
        return None


def _dates(text: str) -> set[dt.date]:
    found: set[dt.date] = set()
    for m in _DAY_MONTH_YEAR.finditer(text):
        d = _make_date(int(m[3]), _MONTHS[m[2]], int(m[1]))
        if d:
            found.add(d)
    for m in _MONTH_DAY_YEAR.finditer(text):
        d = _make_date(int(m[3]), _MONTHS[m[1]], int(m[2]))
        if d:
            found.add(d)
    for m in _NUMERIC_DMY.finditer(text):
        d = _make_date(int(m[3]), int(m[2]), int(m[1]))
        if d:
            found.add(d)
    for m in _NUMERIC_YMD.finditer(text):
        d = _make_date(int(m[1]), int(m[2]), int(m[3]))
        if d:
            found.add(d)
    return {d for d in found if MIN_YEAR <= d.year <= MAX_YEAR}


def _read(text: str) -> _Found:
    """One unambiguous date / year / shift from ``text``, else None for that part."""
    folded = text.casefold()
    dates = _dates(folded)
    shifts = {int(m[1] or m[2]) for m in _SHIFT.finditer(folded)}
    shift = next(iter(shifts)) if len(shifts) == 1 and 1 <= next(iter(shifts)) <= 9 else None
    if len(dates) == 1:
        only = next(iter(dates))
        return _Found(only.year, only, shift)
    if dates:  # several different dates: don't pick one
        return _Found(None, None, shift)
    years = {int(y) for y in _YEAR.findall(folded) if MIN_YEAR <= int(y) <= MAX_YEAR}
    return _Found(next(iter(years)) if len(years) == 1 else None, None, shift)


def _agree(a: int | dt.date | None, b: int | dt.date | None) -> tuple[bool, int | dt.date | None]:
    """Combine one part from two sources: equal or only one known -> that value."""
    if a is None or b is None or a == b:
        return True, a if a is not None else b
    return False, None


def suggest_paper_date(filename: str, first_page: str) -> PaperDateSuggestion:
    name = re.sub(r"\.pdf$", "", filename, flags=re.IGNORECASE)
    from_name = _read(name)
    from_page = _read(first_page[:FIRST_PAGE_CHARS])

    ok_date, paper_date = _agree(from_name.date, from_page.date)
    ok_year, year = _agree(from_name.year, from_page.year)
    ok_shift, shift = _agree(from_name.shift, from_page.shift)
    years_seen = {y for y in (from_name.year, from_page.year) if y is not None}
    if (
        not ok_date
        or not ok_year
        or (isinstance(paper_date, dt.date) and years_seen - {paper_date.year})
    ):
        paper_date = None
        year = None

    sources = []
    if (from_name.year or from_name.shift) and (year or shift):
        sources.append("file name")
    if (from_page.year or from_page.shift) and (year or shift):
        sources.append("first page")
    conflict = not (ok_date and ok_year and ok_shift) or (year is None and bool(years_seen))
    reason = ("Read from the " + " and ".join(sources)) if sources else ""
    if conflict:
        reason = (
            reason + "; " if reason else ""
        ) + "file name and first page disagree on some parts"
    return PaperDateSuggestion(
        year=year if isinstance(year, int) else None,
        date=paper_date if isinstance(paper_date, dt.date) else None,
        shift=shift if isinstance(shift, int) else None,
        reason=reason[:200],
    )
