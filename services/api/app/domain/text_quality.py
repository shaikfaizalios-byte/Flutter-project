"""Deterministic checks on extracted text. They decide whether a page's embedded text layer
can be trusted or whether OCR should be tried, and why a page needs human review."""

import re
import unicodedata
from dataclasses import dataclass

DEVANAGARI = re.compile(r"[ऀ-ॿ]")
LETTER = re.compile(r"[^\W\d_]", re.UNICODE)
REPLACEMENT_CHAR = "�"


class ReviewReason:
    """Stable codes stored in ``document_pages.review_reasons`` (shown to reviewers)."""

    LITTLE_TEXT = "little_text"
    REPLACEMENT_CHARACTERS = "replacement_characters"
    NO_DEVANAGARI = "no_devanagari_in_hindi_page"
    LOW_OCR_CONFIDENCE = "low_ocr_confidence"
    OCR_EMPTY = "ocr_found_no_text"
    OCR_FAILED = "ocr_failed"
    OCR_UNAVAILABLE = "ocr_unavailable"


def normalize_text(text: str) -> str:
    """NFC-normalise, unify line endings, trim trailing spaces and excess blank lines.
    Content is never altered beyond whitespace and Unicode normalisation."""
    text = unicodedata.normalize("NFC", text).replace("\r\n", "\n").replace("\r", "\n")
    lines = [line.rstrip() for line in text.split("\n")]
    collapsed = re.sub(r"\n{3,}", "\n\n", "\n".join(lines))
    return collapsed.strip()


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
    """Tesseract language set. Hindi papers routinely mix in English, digits and symbols."""
    return "hin+eng" if document_language == "hi" else "eng"
