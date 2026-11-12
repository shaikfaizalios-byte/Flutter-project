"""Deterministic checks on extracted text. They decide whether a page's embedded text layer
can be trusted or whether OCR should be tried, and why a page needs human review."""

import re
import unicodedata
from dataclasses import dataclass

from app.domain import languages

DEVANAGARI = re.compile(r"[ऀ-ॿ]")
LETTER = re.compile(r"[^\W\d_]", re.UNICODE)
REPLACEMENT_CHAR = "�"
# Characters a PDF text layer yields for glyphs it cannot map to text: control characters
# (PDFium returns e.g. U+001F for an unmapped "fi" ligature) and replacement/non-characters.
UNREADABLE_CHARS = r"[\x00-\x08\x0b\x0c\x0e-\x1f\ufffd\ufffe\uffff]"
UNREADABLE = re.compile(UNREADABLE_CHARS)


class ReviewReason:
    """Stable codes stored in ``document_pages.review_reasons`` (shown to reviewers)."""

    LITTLE_TEXT = "little_text"
    REPLACEMENT_CHARACTERS = "replacement_characters"
    NO_DEVANAGARI = "no_devanagari_in_hindi_page"
    LOW_OCR_CONFIDENCE = "low_ocr_confidence"
    OCR_EMPTY = "ocr_found_no_text"
    OCR_FAILED = "ocr_failed"
    OCR_UNAVAILABLE = "ocr_unavailable"
    # Global Phase 8 (app/domain/page_analysis.py):
    TWO_COLUMNS = "two_columns"  # check the question order on this page
    DEVANAGARI_IN_ENGLISH = "devanagari_in_english_document"  # read as English: check it


def normalize_text(text: str) -> str:
    """NFC-normalise, unify line endings, trim trailing spaces and excess blank lines.
    Content is never altered beyond whitespace and Unicode normalisation."""
    text = unicodedata.normalize("NFC", text).replace("\r\n", "\n").replace("\r", "\n")
    lines = [line.rstrip() for line in text.split("\n")]
    collapsed = re.sub(r"\n{3,}", "\n\n", "\n".join(lines))
    return collapsed.strip()


def unreadable_char_count(text: str) -> int:
    return len(UNREADABLE.findall(text))


# Characters a text layer gives for maths that app fonts can't draw: Mathematical Alphanumeric
# Symbols (the italic x of an equation) and the Private Use Area (font-specific symbols).
MATH_SYMBOLS = re.compile(r"[\U0001D400-\U0001D7FF\uE000-\uF8FF]")
# A line that is only a raised or lowered part of a formula (an exponent "2", a lone "+"):
# the text layer split a formula across lines, so the text no longer reads as printed.
FORMULA_PIECE = re.compile(r"^[\d+\-=()^/.,\u2212\u00d7\u00f7\u221a]{1,3}$")
MIN_FORMULA_PIECES = 2


def math_layout_problems(text: str, options: str = "") -> list[str]:
    """Why a question's text may not read as printed (maths symbols the app can't show, or a
    formula split over lines); [] when it reads fine. Nothing is changed: an image of the
    question as printed is shown instead, and a reviewer can correct the text. [text] is the
    question itself; [options] only count for symbols (a number option is not a split formula)."""
    problems = []
    symbols = len(MATH_SYMBOLS.findall(text)) + len(MATH_SYMBOLS.findall(options))
    if symbols:
        problems.append(f"{symbols} mathematical symbol(s) that may not display as printed")
    pieces = sum(1 for line in text.splitlines() if FORMULA_PIECE.match(line.strip()))
    if pieces >= MIN_FORMULA_PIECES:
        problems.append("a formula is split over several lines (exponents or fractions)")
    return problems


def meaningful_char_count(text: str) -> int:
    return sum(1 for ch in text if not ch.isspace())


@dataclass(frozen=True, slots=True)
class QualityVerdict:
    acceptable: bool
    reasons: tuple[str, ...]


def assess_text_layer(
    text: str, *, language: str, min_chars: int, hindi_min_devanagari_ratio: float
) -> QualityVerdict:
    """Is an embedded text layer good enough to use without OCR?"""
    reasons: list[str] = []
    if meaningful_char_count(text) < min_chars:
        reasons.append(ReviewReason.LITTLE_TEXT)
    if text and text.count(REPLACEMENT_CHAR) / len(text) > 0.01:
        reasons.append(ReviewReason.REPLACEMENT_CHARACTERS)
    if language == "hi" and not reasons:
        letters = LETTER.findall(text)
        devanagari = sum(1 for ch in letters if DEVANAGARI.match(ch))
        # Hindi papers set in legacy fonts (e.g. Kruti Dev) extract as Latin gibberish.
        if letters and devanagari / len(letters) < hindi_min_devanagari_ratio:
            reasons.append(ReviewReason.NO_DEVANAGARI)
    return QualityVerdict(acceptable=not reasons, reasons=tuple(reasons))


def ocr_languages(document_language: str) -> str:
    """Tesseract language set. Papers in other languages routinely mix in English, digits and
    symbols, so English is added (see app/domain/languages.py)."""
    return languages.ocr_languages(document_language)
