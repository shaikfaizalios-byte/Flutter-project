"""Snap a question: read a photo with OCR, then find the same question in the learner's own
material (their papers' pages, their questions and the shared bank, their synced concepts).

The photo is read in memory and never stored or logged; the text read is returned to the learner
and not kept either. No AI is involved."""

import io
import uuid

from PIL import Image, ImageOps, UnidentifiedImageError
from sqlalchemy.orm import Session

from app.core.config import Settings
from app.domain.errors import DomainError, InvalidReferenceError
from app.domain.languages import ocr_languages
from app.domain.rag import RagSource, query_terms
from app.domain.text_quality import meaningful_char_count, normalize_text
from app.integrations.ocr import OcrEngine, OcrFailedError, OcrUnavailableError
from app.repositories.exam_repository import ExamRepository
from app.schemas.snap import SNAP_MAX_TEXT, SnapMatch, SnapRead
from app.services.rag_service import RagRetriever

MAX_PHOTO_BYTES = 12 * 1024 * 1024
MAX_PHOTO_PIXELS = 40_000_000  # far above any phone camera; stops decompression bombs
MAX_SIDE = 3000  # larger photos are scaled down before reading: no better text, much slower
MATCHES = 8
MIN_WORDS = 4  # fewer words read: say the reading is unsure
FORMATS = {"JPEG", "PNG", "WEBP"}


class PhotoUnreadableError(DomainError):
    status_code = 422
    code = "photo_unreadable"


class PhotoTooLargeError(DomainError):
    status_code = 413
    code = "photo_too_large"


class OcrNotAvailableError(DomainError):
    status_code = 503
    code = "ocr_unavailable"


class SnapService:
    def __init__(
        self, session: Session, owner_id: uuid.UUID, settings: Settings, ocr: OcrEngine
    ) -> None:
        self._session = session
        self._owner_id = owner_id
        self._settings = settings
        self._ocr = ocr

    def read_photo(self, exam_code: str, photo: bytes, language: str) -> SnapRead:
        self._check_exam(exam_code)
        if len(photo) > MAX_PHOTO_BYTES:
            raise PhotoTooLargeError("The photo is too large (12 MB at most).")
        image = _open(photo)
        try:
            result = self._ocr.recognize(
                image,
                languages=ocr_languages(language),
                timeout_seconds=self._settings.ocr_page_timeout_seconds,
            )
        except OcrUnavailableError as exc:
            raise OcrNotAvailableError("Reading photos isn't available on this server.") from exc
        except OcrFailedError as exc:
            raise PhotoUnreadableError("No text could be read from this photo.") from exc
        finally:
            image.close()
        text = normalize_text(result.text)[:SNAP_MAX_TEXT]
        if meaningful_char_count(text) == 0:
            raise PhotoUnreadableError("No text could be read from this photo.")
        unsure = (
            result.mean_confidence is None
            or result.mean_confidence < self._settings.ocr_min_confidence
            or result.word_count < MIN_WORDS
        )
        return SnapRead(text=text, low_confidence=unsure, matches=self._matches(exam_code, text))

    def match_text(self, exam_code: str, text: str) -> list[SnapMatch]:
        """The learner corrected the text read: search again."""
        self._check_exam(exam_code)
        return self._matches(exam_code, text)

    def _matches(self, exam_code: str, text: str) -> list[SnapMatch]:
        sources = RagRetriever(self._session, self._owner_id).retrieve(
            query_terms(text), exam_code, limit=MATCHES
        )
        return [_match(s) for s in sources]

    def _check_exam(self, exam_code: str) -> None:
        if ExamRepository(self._session).get_visible(exam_code, self._owner_id) is None:
            raise InvalidReferenceError(f"Unknown exam '{exam_code}'.")


def _open(photo: bytes) -> Image.Image:
    """A JPEG, PNG or WebP photo, turned upright (phones store the turn separately), in grey and
    no larger than OCR needs."""
    try:
        with Image.open(io.BytesIO(photo)) as probe:
            if probe.format not in FORMATS:
                raise PhotoUnreadableError("Send a JPEG, PNG or WebP photo.")
            if probe.width * probe.height > MAX_PHOTO_PIXELS:
                raise PhotoTooLargeError("The photo has too many pixels.")
            probe.verify()
        with Image.open(io.BytesIO(photo)) as image:
            upright = ImageOps.exif_transpose(image) or image
            grey = upright.convert("L")
        grey.thumbnail((MAX_SIDE, MAX_SIDE))
        return grey
    except (UnidentifiedImageError, OSError, SyntaxError) as exc:
        raise PhotoUnreadableError("This file isn't a photo that can be read.") from exc


def _match(source: RagSource) -> SnapMatch:
    return SnapMatch(
        kind=source.kind,
        label=source.label,
        snippet=source.text[:400],
        verified=source.verified,
        document_id=uuid.UUID(source.document_id) if source.document_id else None,
        page_number=source.page_number,
        question_id=uuid.UUID(source.question_id) if source.question_id else None,
        concept_id=source.concept_id,
    )
