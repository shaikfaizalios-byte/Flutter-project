"""The content-language reference list (global Phase 10): one list in code, the same rows in
the database, enforced by foreign keys and by the API schema."""

import pytest
from fastapi.testclient import TestClient
from sqlalchemy import select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from app.core.config import Settings
from app.domain import languages
from app.domain.ai_content import LANGUAGE_NAMES
from app.main import create_app
from app.models.document import Document
from app.models.language import LanguageRow
from app.models.user import User


def test_database_rows_match_the_reference_list(db_session: Session) -> None:
    rows = {
        r.code: (r.english_name, r.native_name, r.script, r.direction)
        for r in db_session.scalars(select(LanguageRow))
    }
    assert rows == {
        code: (lang.english_name, lang.native_name, lang.script, lang.direction)
        for code, lang in languages.LANGUAGES.items()
    }


def test_behaviour_reads_the_list() -> None:
    assert languages.CODES[:2] == ("en", "hi")
    assert languages.ocr_languages("en") == "eng"
    assert languages.ocr_languages("hi") == "hin+eng"
    assert LANGUAGE_NAMES["en"] == "English"
    assert LANGUAGE_NAMES["hi"] == "Hindi (Devanagari script)"
    assert not languages.language("en").review_ai_text
    assert languages.language("hi").review_ai_text
    with pytest.raises(KeyError):
        languages.language("fr")


def test_an_unknown_language_cannot_be_stored(db_session: Session, user: User) -> None:
    db_session.add(
        Document(
            owner_id=user.id,
            exam_code="SSC_CGL",
            original_filename="paper.pdf",
            size_bytes=1,
            sha256="0" * 64,
            storage_key="x",
            page_count=1,
            language="fr",
        )
    )
    with pytest.raises(IntegrityError):
        db_session.flush()


def test_the_api_lists_and_enforces_the_codes(settings: Settings) -> None:
    schema = create_app(settings).openapi()
    concept = schema["components"]["schemas"]["ConceptCreate"]["properties"]["language"]
    assert concept["enum"] == list(languages.CODES)


def test_requests_with_another_language_are_refused(db_client: TestClient) -> None:
    response = db_client.post(
        "/api/v1/ai/topic-lesson", json={"exam_code": "SSC_CGL", "topic": "Ratio", "language": "fr"}
    )
    assert response.status_code == 422
    assert "language must be one of: en, hi, as" in response.text
