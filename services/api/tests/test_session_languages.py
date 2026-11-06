"""Bilingual questions in sessions: a translation travels with its question and is never asked."""

import uuid
from typing import Any

from fastapi.testclient import TestClient
from sqlalchemy.orm import Session

from app.domain import languages
from app.models.document import Document, DocumentStatus
from app.models.question import (
    Question,
    QuestionOption,
    QuestionOrigin,
    VerificationStatus,
)
from app.models.user import User

_numbers = iter(range(1, 100_000))


def _paper(db: Session, owner: User, language: str = "en") -> Document:
    document = Document(
        owner_id=owner.id,
        exam_code="SSC_CHSL",
        language=language,
        original_filename="p.pdf",
        size_bytes=1,
        sha256="0" * 64,
        storage_key=f"documents/{uuid.uuid4().hex}.pdf",
        page_count=1,
        status=DocumentStatus.COMPLETED,
    )
    db.add(document)
    db.flush()
    return document


def _question(
    db: Session, document: Document, stem: str, language: str, options: list[str], **fields: Any
) -> Question:
    question = Question(
        owner_id=document.owner_id,
        origin=QuestionOrigin.SOURCE,
        exam_code="SSC_CHSL",
        stem=stem,
        language=language,
        document_id=document.id,
        source_question_number=next(_numbers),
        source_pages=[1],
        correct_option_position=2,
        verification_status=VerificationStatus.VERIFIED,
        **fields,
    )
    question.options = [
        QuestionOption(position=i, label=str(i), text=text)
        for i, text in enumerate(options, start=1)
    ]
    db.add(question)
    db.flush()
    return question


def _pair(db: Session, owner: User) -> tuple[Question, Question]:
    paper = _paper(db, owner)
    english = _question(db, paper, "Capital of India?", "en", ["Mumbai", "Delhi"])
    hindi = _question(
        db, paper, "भारत की राजधानी?", "hi", ["मुंबई", "दिल्ली"], translation_of_id=english.id
    )
    return english, hindi


def _start(client: TestClient) -> dict[str, Any]:
    response = client.post("/api/v1/practice/sessions", json={"count": 10, "exam_code": "SSC_CHSL"})
    assert response.status_code == 201, response.text
    data: dict[str, Any] = response.json()
    return data


def test_a_translation_comes_with_its_question_and_is_not_asked_twice(
    db_client: TestClient, db_session: Session, user: User
) -> None:
    english, _ = _pair(db_session, user)
    session = _start(db_client)
    assert len(session["items"]) == 1
    item = session["items"][0]
    assert item["question_id"] == str(english.id)
    assert item["translations"] == [
        {"language": "hi", "stem": "भारत की राजधानी?", "options": ["मुंबई", "दिल्ली"]}
    ]


def test_a_translation_says_nothing_about_the_answer(
    db_client: TestClient, db_session: Session, user: User
) -> None:
    _pair(db_session, user)
    item = _start(db_client)["items"][0]
    assert set(item["translations"][0]) == {"language", "stem", "options"}
    assert item["feedback"] is None


def test_an_answer_is_marked_the_same_in_either_language(
    db_client: TestClient, db_session: Session, user: User
) -> None:
    _pair(db_session, user)
    session = _start(db_client)
    answered = db_client.put(
        f"/api/v1/practice/sessions/{session['id']}/answers/1",
        json={"client_seq": 1, "selected_position": 2},
    ).json()
    assert answered["feedback"]["is_correct"] is True


def test_a_question_without_translations_has_none(
    db_client: TestClient, db_session: Session, user: User
) -> None:
    _question(db_session, _paper(db_session, user), "Only English?", "en", ["a", "b"])
    assert _start(db_client)["items"][0]["translations"] == []


def test_the_offline_pack_leaves_translations_out(
    db_client: TestClient, db_session: Session, user: User
) -> None:
    english, _ = _pair(db_session, user)
    pack = db_client.get("/api/v1/practice/offline-pack", params={"exam": "SSC_CHSL"}).json()
    assert [q["id"] for q in pack["questions"]] == [str(english.id)]


def test_a_regional_paper_can_be_stored(db_session: Session, user: User) -> None:
    paper = _paper(db_session, user, "ta")
    question = _question(db_session, paper, "தமிழ் கேள்வி?", "ta", ["அ", "ஆ"])
    assert question.language == "ta"


def test_regional_languages_are_left_to_right_and_flag_ai_text() -> None:
    for code in ("as", "bn", "gu", "kn", "ml", "mr", "or", "pa", "ta", "te"):
        language = languages.language(code)
        assert language.direction == "ltr"
        assert language.review_ai_text is True


def test_each_regional_language_reads_with_english_too() -> None:
    assert languages.ocr_languages("ta") == "tam+eng"
    assert languages.ocr_languages("or") == "ori+eng"
