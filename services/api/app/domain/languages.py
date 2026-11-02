"""The languages PrepLoop supports for content (papers, questions, notes, AI text).

One reference list (global Phase 10) instead of `'en', 'hi'` written into CHECK constraints,
Pydantic literals and branches. The `languages` table holds the same codes (migration 0037)
and every content table's `language` column references it; `tests/test_languages.py` fails if
the two lists differ. Adding a language = an entry here + a migration row, after checking OCR
data, fonts and AI quality for it; nothing else in the schema changes.

This is the language of the *content*, not of the app's interface (the app has its own
translations) and not of an exam (an exam's languages come from its official notice).
"""

from dataclasses import dataclass
from typing import Literal


@dataclass(frozen=True)
class Language:
    code: str  # ISO 639-1 (or 639-3 when there is no two-letter code), lowercase
    english_name: str
    native_name: str
    script: str  # ISO 15924 code of the usual script, e.g. "Latn", "Deva", "Arab"
    direction: Literal["ltr", "rtl"]
    # Tesseract language data used to OCR a scanned page in this language. English is always
    # added for non-English papers, which mix in English terms, digits and symbols.
    ocr: str
    # Named this way in AI prompts ("in Hindi (Devanagari script)").
    prompt_name: str
    # AI-written text in this language gets a review flag before it can be approved
    # (spelling and terms are less reliable than in English).
    review_ai_text: bool


ENGLISH = Language(
    code="en",
    english_name="English",
    native_name="English",
    script="Latn",
    direction="ltr",
    ocr="eng",
    prompt_name="English",
    review_ai_text=False,
)
HINDI = Language(
    code="hi",
    english_name="Hindi",
    native_name="हिन्दी",
    script="Deva",
    direction="ltr",
    ocr="hin",
    prompt_name="Hindi (Devanagari script)",
    review_ai_text=True,
)

LANGUAGES: dict[str, Language] = {lang.code: lang for lang in (ENGLISH, HINDI)}
CODES: tuple[str, ...] = tuple(LANGUAGES)


def is_supported(code: str) -> bool:
    return code in LANGUAGES


def language(code: str) -> Language:
    """The language for a supported code (KeyError otherwise: validate input first)."""
    return LANGUAGES[code]


def ocr_languages(code: str) -> str:
    """Tesseract language set for a paper in this language."""
    own = language(code).ocr
    return own if own == ENGLISH.ocr else f"{own}+{ENGLISH.ocr}"
