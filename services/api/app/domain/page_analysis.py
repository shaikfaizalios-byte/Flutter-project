"""What a page looks like, for review flags. Pure.

- `detect_script`: which script a page's text is mostly in (Devanagari, Latin, both). An
  English paper whose page is mostly Devanagari was probably read with the wrong OCR language.
- `two_columns`: whether a text-layer page is laid out in two columns. Questions on such pages
  may come out of order or mixed, so the page is flagged for review; the text is never
  reordered by guesswork.
"""

from collections.abc import Sequence
from typing import Literal

from app.domain.figures import LayoutLine
from app.domain.text_quality import DEVANAGARI, LETTER

Script = Literal["devanagari", "latin", "mixed", "none"]

MIN_LETTERS = 20  # fewer letters than this: too little to tell
MAJORITY = 0.8

# Two columns: most lines sit wholly in one half, both halves have several lines, and few lines
# run across the middle.
MIN_LINES_PER_COLUMN = 5
MIN_IN_COLUMNS = 0.6
MAX_ACROSS = 0.25


def detect_script(text: str) -> Script:
    letters = LETTER.findall(text)
    if len(letters) < MIN_LETTERS:
        return "none"
    devanagari = sum(1 for ch in letters if DEVANAGARI.match(ch)) / len(letters)
    if devanagari >= MAJORITY:
        return "devanagari"
    if devanagari <= 1 - MAJORITY:
        return "latin"
    return "mixed"


def two_columns(lines: Sequence[LayoutLine], page_width: float) -> bool:
    if page_width <= 0:
        return False
    middle = page_width / 2
    gutter = page_width * 0.02
    useful = [ln for ln in lines if len(ln.text.strip()) >= 3 and ln.box.width > 0]
    if not useful:
        return False
    left = [ln for ln in useful if ln.box.right <= middle + gutter]
    right = [ln for ln in useful if ln.box.left >= middle - gutter]
    across = [
        ln for ln in useful if ln.box.left < middle - gutter and ln.box.right > middle + gutter
    ]
    return (
        len(left) >= MIN_LINES_PER_COLUMN
        and len(right) >= MIN_LINES_PER_COLUMN
        and (len(left) + len(right)) / len(useful) >= MIN_IN_COLUMNS
        and len(across) / len(useful) <= MAX_ACROSS
    )
