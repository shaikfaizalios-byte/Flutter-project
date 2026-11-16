"""Snap a question: a photo read with OCR, matched against the learner's own material, nothing
stored."""

import io
from typing import Any

from fastapi.testclient import TestClient
from PIL import Image
from sqlalchemy import func, select
from sqlalchemy.orm import Session

from app.models.ai import AIGeneration
from app.models.document import Document
from app.models.question import Question
from app.models.user import User
from tests.conftest import auth_headers, make_user
from tests.fakes import FakeOcrEngine
from tests.test_practice import make_question
from tests.test_shared_bank import make_document

PHOTO = "/api/v1/search/photo"
MATCH = "/api/v1/search/match"


def photo(fmt: str = "JPEG", size: tuple[int, int] = (800, 600)) -> bytes:
    buffer = io.BytesIO()
    Image.new("RGB", size, "white").save(buffer, format=fmt)
    return buffer.getvalue()


def send(api: TestClient, data: bytes, name: str = "q.jpg", **form: str) -> Any:
    return api.post(
        PHOTO,
        files={"photo": (name, data, "image/jpeg")},
        data={"exam_code": "SSC_CHSL", **form},
    )


def use_ocr(api: TestClient, ocr: FakeOcrEngine) -> None:
    api.app.state.ocr_engine = ocr  # type: ignore[attr-defined]


def own_question(db: Session, user: User, stem: str) -> Question:
    document = make_document(db, user)
    question = make_question(db, document, stem=stem)
    db.flush()
    return question


def test_a_photo_finds_the_learners_question_and_nothing_is_stored(
    db_client: TestClient, db_session: Session, user: User
) -> None:
    question = own_question(
        db_session, user, "A train covers 360 km in 4 hours. Find its average speed."
    )
    own_question(db_session, user, "Choose the synonym of RAPID.")
    ocr = FakeOcrEngine(text="A train covers 360 km in 4 hours.\nFind its average speed.")
    use_ocr(db_client, ocr)
    documents = db_session.scalar(select(func.count()).select_from(Document))

    response = send(db_client, photo(), language="hi")
    assert response.status_code == 200, response.text
    body = response.json()
    assert body["text"].startswith("A train covers 360 km")
    assert body["low_confidence"] is False
    assert body["matches"][0]["kind"] == "question"
    assert body["matches"][0]["question_id"] == str(question.id)
    assert ocr.calls[0][1] == "hin+eng"
    # Nothing kept: no paper, no AI call.
    assert db_session.scalar(select(func.count()).select_from(Document)) == documents
    assert db_session.scalar(select(func.count()).select_from(AIGeneration)) == 0

    again = db_client.post(MATCH, json={"exam_code": "SSC_CHSL", "text": "synonym of rapid"})
    assert again.status_code == 200
    assert "RAPID" in again.json()[0]["snippet"]


def test_an_unsure_reading_says_so_and_bad_files_are_refused(
    db_client: TestClient, db_session: Session
) -> None:
    use_ocr(db_client, FakeOcrEngine(text="x y", confidence=40.0))
    unsure = send(db_client, photo("PNG"), name="q.png").json()
    assert unsure["low_confidence"] is True and unsure["matches"] == []

    not_photo = send(db_client, b"%PDF-1.7 not a photo")
    assert not_photo.status_code == 422
    assert not_photo.json()["error"]["code"] == "photo_unreadable"
    gif = io.BytesIO()
    Image.new("RGB", (10, 10)).save(gif, format="GIF")
    assert send(db_client, gif.getvalue()).status_code == 422

    use_ocr(db_client, FakeOcrEngine(mode="unavailable"))
    assert send(db_client, photo()).status_code == 503
    use_ocr(db_client, FakeOcrEngine(text="   "))
    assert send(db_client, photo()).status_code == 422
    unknown = send(db_client, photo(), exam_code="NOPE")
    assert unknown.status_code == 422


def test_another_learners_questions_are_never_matched(
    db_client: TestClient, db_session: Session
) -> None:
    other = make_user(db_session, "other@example.com")
    own_question(db_session, other, "A train covers 360 km in 4 hours. Find its average speed.")
    use_ocr(db_client, FakeOcrEngine(text="A train covers 360 km in 4 hours."))
    assert send(db_client, photo()).json()["matches"] == []
    db_client.headers.update(auth_headers(other))
    assert len(send(db_client, photo()).json()["matches"]) == 1
