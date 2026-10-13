import pytest

from app.domain.text_quality import (
    ReviewReason,
    assess_text_layer,
    normalize_text,
    ocr_languages,
)
from app.services.extraction import summarize_methods


def assess(text: str, language: str = "en") -> tuple[bool, tuple[str, ...]]:
    verdict = assess_text_layer(
        text, language=language, min_chars=25, hindi_min_devanagari_ratio=0.05
    )
    return verdict.acceptable, verdict.reasons


def test_normalize_text_only_touches_whitespace_and_unicode_form() -> None:
    raw = "Q.1  What?   \r\n(1) 20\r\n\r\n\r\n\r\n(2) 30  "
    assert normalize_text(raw) == "Q.1  What?\n(1) 20\n\n(2) 30"
    # NFC composes "e" + combining acute into a single character. Devanagari nukta letters
    # (e.g. U+0958) are composition exclusions, so NFC keeps them as base + nukta.
    assert normalize_text("é") == "é"
    assert normalize_text("क़") == "क़"


def test_good_english_text_layer_is_accepted() -> None:
    assert assess("Q.1 What is the capital of India? (1) Delhi (2) Mumbai") == (True, ())


def test_little_text_triggers_ocr() -> None:
    assert assess("   12  ") == (False, (ReviewReason.LITTLE_TEXT,))


def test_replacement_characters_are_suspect() -> None:
    acceptable, reasons = assess("Q.1 " + "�" * 5 + " what is the value of x here?")
    assert not acceptable
    assert ReviewReason.REPLACEMENT_CHARACTERS in reasons


def test_hindi_page_with_devanagari_is_accepted() -> None:
    assert assess("प्रश्न 1. निम्नलिखित में से कौन सा सही है? (1) A (2) B", "hi") == (True, ())


def test_hindi_page_without_devanagari_is_suspect() -> None:
    acceptable, reasons = assess("iz'u 1- fuEufyf[kr esa ls dkSu lk 'kCn lgh gS", "hi")
    assert not acceptable
    assert reasons == (ReviewReason.NO_DEVANAGARI,)


def test_english_rule_does_not_require_devanagari() -> None:
    assert assess("iz'u 1- fuEufyf[kr esa ls dkSu lk 'kCn lgh gS", "en")[0]


@pytest.mark.parametrize(("language", "expected"), [("en", "eng"), ("hi", "hin+eng")])
def test_ocr_languages(language: str, expected: str) -> None:
    assert ocr_languages(language) == expected


@pytest.mark.parametrize(
    ("methods", "expected"),
    [
        ({"text"}, "text"),
        ({"ocr"}, "ocr"),
        ({"text", "ocr"}, "mixed"),
        ({"text", "none"}, "text"),
        ({"none"}, "none"),
        (set(), "none"),
    ],
)
def test_summarize_methods(methods: set[str], expected: str) -> None:
    assert summarize_methods(methods) == expected
