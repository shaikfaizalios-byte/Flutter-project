from pathlib import Path
from typing import Any

import pytest
from fastapi.testclient import TestClient
from sqlalchemy import Engine

from app.core.config import Settings
from app.integrations.storage import LocalDocumentStorage
from app.main import create_app
from app.services.document_service import sanitize_filename
from tests.pdf_factory import CORRUPT_PDF, PNG_BYTES, blank_pages_pdf, text_pdf

URL = "/api/v1/documents"


def upload(
    client: TestClient,
    content: bytes,
    *,
    filename: str = "paper.pdf",
    exam_code: str = "SSC_CGL",
    language: str = "en",
) -> Any:
    return client.post(
        URL,
        files={"file": (filename, content, "application/pdf")},
        data={"exam_code": exam_code, "language": language},
    )


def stored_files(settings: Settings) -> list[Path]:
    return sorted((settings.upload_dir / "documents").glob("*"))


def test_valid_pdf_is_stored_and_queued(db_client: TestClient, settings: Settings) -> None:
    response = upload(db_client, text_pdf([["page one"], ["page two"]]))

    assert response.status_code == 201, response.text
    body = response.json()
    assert body["status"] == "queued"
    assert body["page_count"] == 2
    assert body["pages_processed"] == 0
    assert body["original_filename"] == "paper.pdf"
    assert len(body["sha256"]) == 64
    assert "storage_key" not in body
    files = stored_files(settings)
    assert len(files) == 1
    # Stored under a generated name, never the user's filename.
    assert files[0].name != "paper.pdf"
    assert files[0].suffix == ".pdf"


def test_path_like_filename_is_metadata_only(db_client: TestClient, settings: Settings) -> None:
    response = upload(db_client, text_pdf(), filename="..\\..\\etc/passwd.pdf")

    assert response.status_code == 201
    assert response.json()["original_filename"] == "passwd.pdf"
    for path in stored_files(settings):
        assert path.parent == (settings.upload_dir / "documents").resolve()


@pytest.mark.parametrize(
    ("raw", "expected"),
    [
        ("paper.pdf", "paper.pdf"),
        ("C:\\Users\\me\\SSC CGL 2023.pdf", "SSC CGL 2023.pdf"),
        ("../../secret.pdf", "secret.pdf"),
        ("a<b>c:d|e?.pdf", "abcde.pdf"),
        ("bad\x00name\x1f.pdf", "badname.pdf"),
        ("", "document.pdf"),
        (None, "document.pdf"),
        ("...", "document.pdf"),
        ("प्रश्न पत्र.pdf", "प्रश्न पत्र.pdf"),
    ],
)
def test_sanitize_filename(raw: str | None, expected: str) -> None:
    assert sanitize_filename(raw) == expected


def test_long_filename_keeps_extension() -> None:
    name = sanitize_filename("x" * 400 + ".pdf")
    assert len(name) <= 255
    assert name.endswith(".pdf")


def test_non_pdf_content_is_rejected_even_with_pdf_name(
    db_client: TestClient, settings: Settings
) -> None:
    response = upload(db_client, PNG_BYTES, filename="looks-like.pdf")

    assert response.status_code == 415
    assert response.json()["error"]["code"] == "unsupported_file_type"
    assert stored_files(settings) == []


@pytest.mark.parametrize(
    ("content", "code"),
    [
        (b"", "empty_file"),
        (CORRUPT_PDF, "invalid_pdf"),
        (text_pdf(password="user-pass"), "encrypted_pdf"),  # noqa: S106 - test fixture
    ],
)
def test_bad_pdfs_are_rejected_without_storing(
    db_client: TestClient, settings: Settings, content: bytes, code: str
) -> None:
    response = upload(db_client, content)

    assert response.status_code == 422
    assert response.json()["error"]["code"] == code
    assert stored_files(settings) == []
    assert list((settings.upload_dir / "tmp").glob("*")) == []


def test_too_many_pages(
    settings: Settings, db_engine: Engine, db_client: TestClient, storage: LocalDocumentStorage
) -> None:
    settings.max_pdf_pages = 3

    response = upload(db_client, blank_pages_pdf(4))

    assert response.status_code == 422
    assert response.json()["error"]["code"] == "too_many_pages"


def test_oversize_file_is_rejected(settings: Settings, db_client: TestClient) -> None:
    settings.max_upload_bytes = 2048

    response = upload(db_client, text_pdf([["x" * 80] * 30] * 5))

    assert response.status_code == 413
    assert response.json()["error"]["code"] == "file_too_large"
    assert stored_files(settings) == []


def test_unknown_exam_and_bad_language(db_client: TestClient) -> None:
    unknown = upload(db_client, text_pdf(), exam_code="UPSC_CSE")
    assert unknown.status_code == 422
    assert unknown.json()["error"]["code"] == "invalid_reference"

    bad_language = upload(db_client, text_pdf(), language="fr")
    assert bad_language.status_code == 422
    assert bad_language.json()["error"]["code"] == "validation_error"


def test_missing_file_field(db_client: TestClient) -> None:
    response = db_client.post(URL, data={"exam_code": "SSC_CGL", "language": "en"})

    assert response.status_code == 422
    assert "body.file" in [d["field"] for d in response.json()["error"]["details"]]


def test_uploads_are_rate_limited(
    settings: Settings, db_engine: Engine, db_session: object, storage: LocalDocumentStorage
) -> None:
    from app.database.session import get_session

    settings.upload_rate_limit = 2
    app = create_app(settings, engine=db_engine, storage=storage)
    app.dependency_overrides[get_session] = lambda: db_session
    with TestClient(app) as client:
        assert upload(client, text_pdf()).status_code == 201
        assert upload(client, text_pdf()).status_code == 201
        limited = upload(client, text_pdf())

    assert limited.status_code == 429
    assert limited.json()["error"]["code"] == "rate_limited"
    assert int(limited.headers["Retry-After"]) > 0


def test_list_get_and_delete(db_client: TestClient, settings: Settings) -> None:
    first = upload(db_client, text_pdf(), filename="a.pdf").json()
    upload(db_client, text_pdf(), filename="b.pdf")

    listing = db_client.get(URL).json()
    assert listing["total"] == 2
    assert {d["original_filename"] for d in listing["items"]} == {"a.pdf", "b.pdf"}
    assert db_client.get(URL, params={"status": "completed"}).json()["total"] == 0
    assert db_client.get(f"{URL}/{first['id']}").json()["id"] == first["id"]

    assert db_client.delete(f"{URL}/{first['id']}").status_code == 204
    assert db_client.get(f"{URL}/{first['id']}").status_code == 404
    assert db_client.delete(f"{URL}/{first['id']}").status_code == 404
    assert len(stored_files(settings)) == 1  # original file removed too


def test_documents_require_database(client: TestClient) -> None:
    assert client.get(URL).status_code == 503
