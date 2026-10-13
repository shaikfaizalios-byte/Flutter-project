"""Per-page PDF text extraction with OCR fallback.

Pages are opened, processed and released one at a time so memory stays bounded for long
documents. Text is only ever taken from the PDF's text layer or from OCR output; when neither
is reliable, the page is stored with whatever was found (possibly nothing) and flagged for
review. Nothing is ever invented or "corrected".
"""

import logging
import time
from collections.abc import Callable, Iterator
from dataclasses import dataclass, field
from pathlib import Path

import pypdfium2 as pdfium

from app.core.config import Settings
from app.domain.text_quality import (
    ReviewReason,
    assess_text_layer,
    meaningful_char_count,
    normalize_text,
    ocr_languages,
)
from app.integrations.ocr import OcrEngine, OcrFailedError, OcrUnavailableError
from app.models.document import ExtractionMethod

logger = logging.getLogger("app.extraction")


@dataclass(frozen=True, slots=True)
class PageExtraction:
    page_number: int  # 1-based
    method: ExtractionMethod
    text: str
    ocr_confidence: float | None = None
    review_reasons: tuple[str, ...] = field(default_factory=tuple)

    @property
    def needs_review(self) -> bool:
        return bool(self.review_reasons)


class ProcessingTimeoutError(RuntimeError):
    """The document's processing budget ran out before all pages were done."""


def extract_pages(
    pdf_path: Path,
    *,
    language: str,
    ocr: OcrEngine,
    settings: Settings,
    start_page: int = 1,
    deadline: float | None = None,
    monotonic: Callable[[], float] = time.monotonic,
) -> Iterator[PageExtraction]:
    """Yield one ``PageExtraction`` per page from ``start_page`` (1-based) to the end.

    Raises ``ProcessingTimeoutError`` (between pages) once ``deadline`` (a
    ``time.monotonic()`` value) has passed.
    """
    document = pdfium.PdfDocument(pdf_path)
    try:
        for index in range(start_page - 1, len(document)):
            if deadline is not None and monotonic() > deadline:
                raise ProcessingTimeoutError
            page = document[index]
            try:
                yield _extract_page(page, index + 1, language=language, ocr=ocr, settings=settings)
            finally:
                page.close()
    finally:
        document.close()


def _extract_page(
    page: pdfium.PdfPage, page_number: int, *, language: str, ocr: OcrEngine, settings: Settings
) -> PageExtraction:
    text_page = page.get_textpage()
    try:
        layer_text = normalize_text(text_page.get_text_bounded())
    finally:
        text_page.close()

    verdict = assess_text_layer(
        layer_text,
        language=language,
        min_chars=settings.text_layer_min_chars,
        hindi_min_devanagari_ratio=settings.hindi_min_devanagari_ratio,
    )
    if verdict.acceptable:
        return PageExtraction(page_number, ExtractionMethod.TEXT, layer_text)

    # The text layer is missing or suspect: try OCR on a rendered image of the page.
    bitmap = page.render(scale=settings.ocr_dpi / 72)
    image = bitmap.to_pil()
    try:
        result = ocr.recognize(
            image,
            languages=ocr_languages(language),
            timeout_seconds=settings.ocr_page_timeout_seconds,
        )
    except OcrUnavailableError:
        return _fallback(page_number, layer_text, (*verdict.reasons, ReviewReason.OCR_UNAVAILABLE))
    except OcrFailedError:
        logger.warning("OCR failed on page %d", page_number)
        return _fallback(page_number, layer_text, (*verdict.reasons, ReviewReason.OCR_FAILED))
    finally:
        image.close()
        bitmap.close()

    ocr_text = normalize_text(result.text)
    if meaningful_char_count(ocr_text) == 0:
        return _fallback(page_number, layer_text, (*verdict.reasons, ReviewReason.OCR_EMPTY))

    reasons: list[str] = []
    if result.mean_confidence is None or result.mean_confidence < settings.ocr_min_confidence:
        reasons.append(ReviewReason.LOW_OCR_CONFIDENCE)
    if meaningful_char_count(ocr_text) < settings.text_layer_min_chars:
        reasons.append(ReviewReason.LITTLE_TEXT)
    return PageExtraction(
        page_number,
        ExtractionMethod.OCR,
        ocr_text,
        ocr_confidence=result.mean_confidence,
        review_reasons=tuple(reasons),
    )


def _fallback(page_number: int, layer_text: str, reasons: tuple[str, ...]) -> PageExtraction:
    """Keep whatever the text layer had (never invented text) and flag the page."""
    method = ExtractionMethod.TEXT if meaningful_char_count(layer_text) else ExtractionMethod.NONE
    return PageExtraction(page_number, method, layer_text, review_reasons=reasons)


def summarize_methods(methods: set[str]) -> str:
    """Document-level summary of how its pages were extracted."""
    useful = methods - {ExtractionMethod.NONE}
    if not useful:
        return ExtractionMethod.NONE
    if len(useful) == 1:
        return next(iter(useful))
    return "mixed"
