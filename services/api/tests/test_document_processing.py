import uuid
from datetime import UTC, datetime, timedelta

import pytest
from fastapi.testclient import TestClient
from sqlalchemy.orm import Session

from app.core.config import Settings
from app.integrations.storage import LocalDocumentStorage
from app.models.document import Document, DocumentPage, DocumentStatus
from app.services.processing_service import MAX_ATTEMPTS, DocumentProcessor
from tests.fakes import FakeOcrEngine
from tests.pdf_factory import SAMPLE_QUESTION, image_pdf, mixed_pdf, text_image, text_pdf

URL = "/api/v1/documents"


def upload(client: TestClient, content: bytes, language: str = "en") -> uuid.UUID:
    response = client.post(
        URL,
        files={"file": ("p.pdf", content, "application/pdf")},
        data={"exam_code": "SSC_CGL", "language": language},
    )
    assert response.status_code == 201, response.text
    return uuid.UUID(response.json()["id"])


def run_worker(
    session: Session,
    storage: LocalDocumentStorage,
    settings: Settings,
    ocr: FakeOcrEngine | None = None,
    **kwargs: object,
) -> uuid.UUID | None:
    processor = DocumentProcessor(
        storage=storage,
        ocr=ocr or FakeOcrEngine(),
        settings=settings,
        **kwargs,  # type: ignore[arg-type]
    )
    document_id = processor.claim_next(session)
    if document_id is not None:
        processor.process(session, document_id)
    return document_id


def pages(client: TestClient, document_id: uuid.UUID) -> list[dict[str, object]]:
    items: list[dict[str, object]] = client.get(f"{URL}/{document_id}/pages").json()["items"]
    return items


def test_text_layer_pages_are_extracted_without_ocr(
    db_client: TestClient, db_session: Session, storage: LocalDocumentStorage, settings: Settings
) -> None:
    ocr = FakeOcrEngine()
    document_id = upload(db_client, text_pdf([SAMPLE_QUESTION, ["Q.3 " + "x" * 40]]))

    assert run_worker(db_session, storage, settings, ocr) == document_id

    document = db_client.get(f"{URL}/{document_id}").json()
    assert document["status"] == "completed"
    assert document["pages_processed"] == 2
    assert document["extraction_summary"] == "text"
    assert document["needs_review_count"] == 0
    assert document["processing_finished_at"] is not None
    result = pages(db_client, document_id)
    assert [p["page_number"] for p in result] == [1, 2]
    assert result[0]["method"] == "text"
    assert "Q.1 What is 20% of 150?" in str(result[0]["text"])
    assert "(1) 20" in str(result[0]["text"])
    assert ocr.calls == []


def test_image_only_page_uses_ocr(
    db_client: TestClient, db_session: Session, storage: LocalDocumentStorage, settings: Settings
) -> None:
    ocr = FakeOcrEngine(text="Q.5 Find the odd one out: (1) cat (2) dog", confidence=88.0)
    document_id = upload(db_client, image_pdf([text_image(["scan"])]))

    run_worker(db_session, storage, settings, ocr)

    [page] = pages(db_client, document_id)
    assert page["method"] == "ocr"
    assert page["text"] == "Q.5 Find the odd one out: (1) cat (2) dog"
    assert page["ocr_confidence"] == 88.0
    assert page["needs_review"] is False
    assert ocr.calls[0][1] == "eng"
    # Rendered at the configured DPI (A4 width 595 pt at 300 dpi ≈ 2480 px).
    assert ocr.calls[0][0][0] == pytest.approx(2480, abs=2)
    assert db_client.get(f"{URL}/{document_id}").json()["extraction_summary"] == "ocr"


def test_low_confidence_ocr_is_flagged_not_corrected(
    db_client: TestClient, db_session: Session, storage: LocalDocumentStorage, settings: Settings
) -> None:
    ocr = FakeOcrEngine(text="Q.5 F1nd th3 0dd one out: (1) c4t (2) d0g", confidence=41.0)
    document_id = upload(db_client, image_pdf([text_image(["scan"])]))

    run_worker(db_session, storage, settings, ocr)

    [page] = pages(db_client, document_id)
    assert page["text"] == "Q.5 F1nd th3 0dd one out: (1) c4t (2) d0g"  # stored as recognised
    assert page["needs_review"] is True
    assert page["review_reasons"] == ["low_ocr_confidence"]
    assert db_client.get(f"{URL}/{document_id}").json()["needs_review_count"] == 1


@pytest.mark.parametrize(
    ("mode", "reason"), [("unavailable", "ocr_unavailable"), ("failed", "ocr_failed")]
)
def test_ocr_problems_never_invent_text(
    db_client: TestClient,
    db_session: Session,
    storage: LocalDocumentStorage,
    settings: Settings,
    mode: str,
    reason: str,
) -> None:
    document_id = upload(db_client, image_pdf([text_image(["scan"])]))

    run_worker(db_session, storage, settings, FakeOcrEngine(mode=mode))

    [page] = pages(db_client, document_id)
    assert page["method"] == "none"
    assert page["text"] == ""
    assert page["needs_review"] is True
    assert page["review_reasons"] == ["little_text", reason]
    document = db_client.get(f"{URL}/{document_id}").json()
    assert document["status"] == "completed"
    assert document["extraction_summary"] == "none"


def test_ocr_finding_nothing_is_flagged(
    db_client: TestClient, db_session: Session, storage: LocalDocumentStorage, settings: Settings
) -> None:
    document_id = upload(db_client, image_pdf([text_image([""])]))

    run_worker(db_session, storage, settings, FakeOcrEngine(text="   ", confidence=None))

    [page] = pages(db_client, document_id)
    assert page["method"] == "none"
    assert "ocr_found_no_text" in page["review_reasons"]  # type: ignore[operator]


def test_mixed_document_uses_the_right_method_per_page(
    db_client: TestClient, db_session: Session, storage: LocalDocumentStorage, settings: Settings
) -> None:
    ocr = FakeOcrEngine(text="Scanned page with a question about averages.")
    document_id = upload(db_client, mixed_pdf())

    run_worker(db_session, storage, settings, ocr)

    assert [p["method"] for p in pages(db_client, document_id)] == ["text", "ocr"]
    assert len(ocr.calls) == 1
    assert db_client.get(f"{URL}/{document_id}").json()["extraction_summary"] == "mixed"


def test_hindi_document_with_latin_only_text_layer_is_ocred(
    db_client: TestClient, db_session: Session, storage: LocalDocumentStorage, settings: Settings
) -> None:
    # Legacy Hindi fonts extract as Latin gibberish like this.
    gibberish = ["iz'u 1- fuEufyf[kr esa ls dkSu lk 'kCn lgh gS\\ " * 2]
    ocr = FakeOcrEngine(text="प्रश्न 1. निम्नलिखित में से कौन सा शब्द सही है?")
    document_id = upload(db_client, text_pdf([gibberish]), language="hi")

    run_worker(db_session, storage, settings, ocr)

    [page] = pages(db_client, document_id)
    assert page["method"] == "ocr"
    assert str(page["text"]).startswith("प्रश्न 1.")
    assert ocr.calls[0][1] == "hin+eng"


def test_timeout_fails_document_and_keeps_finished_pages(
    db_client: TestClient, db_session: Session, storage: LocalDocumentStorage, settings: Settings
) -> None:
    document_id = upload(db_client, text_pdf([SAMPLE_QUESTION] * 3))
    ticks = iter([0.0, 0.0, 0.0, 10_000.0])  # deadline set, page 1 ok, page 2 ok, then late

    run_worker(db_session, storage, settings, monotonic=lambda: next(ticks))

    document = db_client.get(f"{URL}/{document_id}").json()
    assert document["status"] == "failed"
    assert document["error_code"] == "processing_timeout"
    assert document["pages_processed"] == 2
    assert len(pages(db_client, document_id)) == 2


def test_missing_source_file_fails_cleanly(
    db_client: TestClient, db_session: Session, storage: LocalDocumentStorage, settings: Settings
) -> None:
    document_id = upload(db_client, text_pdf())
    stored = db_session.get(Document, document_id)
    assert stored is not None
    storage.delete(stored.storage_key)

    run_worker(db_session, storage, settings)

    assert db_client.get(f"{URL}/{document_id}").json()["error_code"] == "source_file_missing"


def test_queue_is_processed_oldest_first_and_empty_queue_is_noop(
    db_client: TestClient, db_session: Session, storage: LocalDocumentStorage, settings: Settings
) -> None:
    first = upload(db_client, text_pdf())
    second = upload(db_client, text_pdf())

    assert run_worker(db_session, storage, settings) == first
    assert run_worker(db_session, storage, settings) == second
    assert run_worker(db_session, storage, settings) is None


def test_expired_lease_is_reclaimed_and_retried_from_scratch(
    db_client: TestClient, db_session: Session, storage: LocalDocumentStorage, settings: Settings
) -> None:
    document_id = upload(db_client, text_pdf())
    document = db_session.get(Document, document_id)
    assert document is not None
    # Simulate a worker that crashed mid-way: processing, stale lease, a partial page.
    document.status = DocumentStatus.PROCESSING
    document.attempts = 1
    document.lease_expires_at = datetime.now(UTC) - timedelta(minutes=1)
    db_session.add(DocumentPage(document_id=document_id, page_number=1, method="none", text=""))
    db_session.commit()

    assert run_worker(db_session, storage, settings) == document_id

    result = db_client.get(f"{URL}/{document_id}").json()
    assert result["status"] == "completed"
    assert pages(db_client, document_id)[0]["method"] == "text"


def test_active_lease_is_not_stolen(
    db_client: TestClient, db_session: Session, storage: LocalDocumentStorage, settings: Settings
) -> None:
    document_id = upload(db_client, text_pdf())
    document = db_session.get(Document, document_id)
    assert document is not None
    document.status = DocumentStatus.PROCESSING
    document.lease_expires_at = datetime.now(UTC) + timedelta(minutes=10)
    db_session.commit()

    assert run_worker(db_session, storage, settings) is None


def test_gives_up_after_max_attempts(
    db_client: TestClient, db_session: Session, storage: LocalDocumentStorage, settings: Settings
) -> None:
    document_id = upload(db_client, text_pdf())
    document = db_session.get(Document, document_id)
    assert document is not None
    document.status = DocumentStatus.PROCESSING
    document.attempts = MAX_ATTEMPTS
    document.lease_expires_at = datetime.now(UTC) - timedelta(minutes=1)
    db_session.commit()

    assert run_worker(db_session, storage, settings) is None

    result = db_client.get(f"{URL}/{document_id}").json()
    assert result["status"] == "failed"
    assert result["error_code"] == "too_many_attempts"


def test_document_deleted_while_queued_is_skipped(
    db_client: TestClient, db_session: Session, storage: LocalDocumentStorage, settings: Settings
) -> None:
    document_id = upload(db_client, text_pdf())
    processor = DocumentProcessor(storage=storage, ocr=FakeOcrEngine(), settings=settings)
    claimed = processor.claim_next(db_session)
    assert claimed == document_id
    db_client.delete(f"{URL}/{document_id}")

    processor.process(db_session, document_id)  # must not raise

    assert db_session.get(Document, document_id) is None


def test_pages_endpoint_paginates_and_404s(
    db_client: TestClient, db_session: Session, storage: LocalDocumentStorage, settings: Settings
) -> None:
    document_id = upload(db_client, text_pdf([SAMPLE_QUESTION] * 5))
    run_worker(db_session, storage, settings)

    page = db_client.get(f"{URL}/{document_id}/pages", params={"limit": 2, "offset": 2}).json()
    assert page["total"] == 5
    assert [p["page_number"] for p in page["items"]] == [3, 4]
    assert db_client.get(f"{URL}/{uuid.uuid4()}/pages").status_code == 404
