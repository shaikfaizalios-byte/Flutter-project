"""Reading a PDF sent with a request: saved to a temporary file that is deleted at once."""

from collections.abc import Callable
from pathlib import Path
from typing import BinaryIO

import pypdfium2 as pdfium

from app.domain.errors import InvalidDocumentError, UnsupportedFileTypeError, UploadTooLargeError

_CHUNK = 1024 * 1024


def save_limited(stream: BinaryIO, destination: Path, limit: int) -> None:
    size = 0
    with destination.open("wb") as out:
        while chunk := stream.read(_CHUNK):
            size += len(chunk)
            if size > limit:
                raise UploadTooLargeError(f"The file is larger than {limit // (1024 * 1024)} MB.")
            out.write(chunk)
    if size == 0:
        raise InvalidDocumentError("empty_file", "The file is empty.")
    with destination.open("rb") as file:
        if b"%PDF-" not in file.read(1024):
            raise UnsupportedFileTypeError("Only PDF files can be imported.")


def page_count(path: Path, max_pages: int, too_long: Callable[[int], str]) -> int:
    try:
        document = pdfium.PdfDocument(path)
    except pdfium.PdfiumError as exc:
        raise InvalidDocumentError(
            "invalid_pdf", "The file is damaged, password-protected or not a valid PDF."
        ) from exc
    try:
        pages = len(document)
    finally:
        document.close()
    if pages == 0:
        raise InvalidDocumentError("invalid_pdf", "The PDF has no pages.")
    if pages > max_pages:
        raise InvalidDocumentError("too_many_pages", too_long(pages))
    return pages
