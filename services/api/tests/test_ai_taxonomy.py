"""AI topic drafts for any exam: bounded, de-duplicated, never saved by themselves."""

import uuid
from typing import Any

from fastapi.testclient import TestClient
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.domain import ai_content
from app.models.ai import AIGeneration
from app.models.document import Document, DocumentStatus
from app.models.question import Question, QuestionOption, QuestionOrigin, Topic
from app.models.user import User
from tests.fakes import FakeAIProvider
from tests.test_ai import ai, api, make_api  # noqa: F401 - fixtures

DRAFT = {
    "subjects": [
        {
            "name": "Biology",
            "topics": [
                {"name": "Cell Biology", "keywords": ["cell", "organelle", "Cell", " "]},
                {"name": "Genetics", "keywords": ["gene", "allele"]},
                {"name": "cell biology", "keywords": []},  # duplicate
                {"name": "x", "keywords": []},  # too short
            ],
        },
        {"name": "Physics", "topics": [{"name": "Optics", "keywords": ["lens", "mirror"]}]},
        {"name": 42, "topics": []},  # malformed
    ]
}


def test_validate_taxonomy_bounds_and_drops_existing() -> None:
    drafted = ai_content.validate_taxonomy(DRAFT, existing=["Physics > Optics"])
    assert [(d.subject, d.name, d.keywords) for d in drafted] == [
        ("Biology", "Cell Biology", ("cell", "organelle")),
        ("Biology", "Genetics", ("gene", "allele")),
    ]
    assert ai_content.validate_taxonomy({"subjects": "nope"}, existing=[]) == []


def test_taxonomy_prompt_names_the_exam_and_forbids_inventing_patterns() -> None:
    prompt = ai_content.taxonomy_prompt(
        "NEET UG", ["Which organelle makes ATP?"], ["Biology > Cell"]
    )
    assert "NEET UG" in prompt and "do not invent exam patterns" in prompt
    assert "- Biology > Cell" in prompt and "Which organelle makes ATP?" in prompt


def _neet_questions(db: Session, user: User, n: int) -> None:
    doc = Document(
        owner_id=user.id,
        exam_code="NEET_UG",
        language="en",
        original_filename="neet.pdf",
        size_bytes=1,
        sha256="0" * 64,
        storage_key=f"documents/{uuid.uuid4().hex}.pdf",
        page_count=1,
        status=DocumentStatus.COMPLETED,
    )
    db.add(doc)
    db.flush()
    for i in range(1, n + 1):
        q = Question(
            owner_id=user.id,
            origin=QuestionOrigin.SOURCE,
            exam_code="NEET_UG",
            stem=f"Question {i}: which organelle is described?",
            language="en",
            document_id=doc.id,
            source_question_number=i,
            source_pages=[1],
            verification_status="unverified",
        )
        q.options = [QuestionOption(position=1, label="1", text="a")]
        db.add(q)
    db.flush()


def test_draft_from_own_questions_is_returned_not_saved(
    api: TestClient,  # noqa: F811
    ai: FakeAIProvider,  # noqa: F811
    db_session: Session,
    user: User,
) -> None:
    _neet_questions(db_session, user, 8)
    ai.responses.append(DRAFT)

    response = api.post("/api/v1/ai/exams/NEET_UG/topic-draft")
    assert response.status_code == 200, response.text
    body: dict[str, Any] = response.json()
    assert body["questions_considered"] == 8 and body["model"] == "fake-model-1"
    assert [s["name"] for s in body["subjects"]] == ["Biology", "Physics"]
    assert body["subjects"][0]["topics"][0] == {
        "name": "Cell Biology",
        "keywords": ["cell", "organelle"],
    }
    assert "NEET UG" in ai.calls[0].prompt
    # Nothing saved; the call is logged without text.
    assert db_session.scalars(select(Topic).where(Topic.owner_id == user.id)).all() == []
    log = db_session.scalars(select(AIGeneration).where(AIGeneration.task == "taxonomy")).one()
    assert log.outcome == "ok" and log.detail == "8 questions"


def test_draft_needs_imported_questions_and_a_visible_exam(
    api: TestClient,  # noqa: F811
    ai: FakeAIProvider,  # noqa: F811
    db_session: Session,
    user: User,
) -> None:
    assert api.post("/api/v1/ai/exams/NEET_UG/topic-draft").status_code == 422
    assert api.post("/api/v1/ai/exams/MY_NOT_MINE/topic-draft").status_code == 422
    assert ai.calls == []


def test_draft_is_unavailable_without_ai(
    make_api: Any,  # noqa: F811
    db_session: Session,
    user: User,
) -> None:
    _neet_questions(db_session, user, 8)
    client = make_api(None)
    response = client.post("/api/v1/ai/exams/NEET_UG/topic-draft")
    assert response.status_code == 503
