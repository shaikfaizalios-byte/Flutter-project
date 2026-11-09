"""Reading an answer-key PDF sent with a request. The file is deleted at once."""

import uuid
from pathlib import Path
from typing import BinaryIO

from app.core.config import Settings
from app.domain.segmentation import AnswerKeyRead, read_answer_key
from app.integrations.ocr import OcrEngine
from app.models.document import ExtractionMethod
from app.services.extraction import extract_pages
from app.services.pdf_upload import page_count, save_limited

MAX_KEY_PAGES = 40


def _too_long(pages: int) -> str:
    return (
        f"An answer key has at most {MAX_KEY_PAGES} pages; this PDF has {pages}. "
        "Is it a question paper?"
    )


def read_key_pdf(
    stream: BinaryIO, *, language: str, settings: Settings, ocr: OcrEngine, temp_dir: Path
) -> tuple[AnswerKeyRead, str]:
    """The key, and how the pages were read."""
    pages, read_by = read_key_pages(
        stream, language=language, settings=settings, ocr=ocr, temp_dir=temp_dir
    )
    return read_answer_key(pages), read_by


def read_key_pages(
    stream: BinaryIO, *, language: str, settings: Settings, ocr: OcrEngine, temp_dir: Path
) -> tuple[list[str], str]:
    """The text of each page of a key file, and how the pages were read."""
    temp = temp_dir / f"answer-key-{uuid.uuid4().hex}.pdf"
    try:
        save_limited(stream, temp, settings.max_upload_bytes)
        page_count(temp, MAX_KEY_PAGES, _too_long)
        extracted = list(extract_pages(temp, language=language, ocr=ocr, settings=settings))
    finally:
        temp.unlink(missing_ok=True)
    methods = {p.method for p in extracted if p.method != ExtractionMethod.NONE}
    read_by = "mixed" if len(methods) > 1 else (methods.pop() if methods else "none")
    return [p.text for p in extracted], str(read_by)
