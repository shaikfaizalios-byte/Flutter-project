"""Reading papers with AI: the pure checks, a full read of a generated PDF with the fake
provider (no network), and the endpoint that queues it."""

import uuid
from typing import Any

from sqlalchemy import select
from sqlalchemy.orm import Session

from app.core.config import Settings
from app.domain.ai_reading import (
    AI_READ_UNCHECKED,
    AI_TEXT_MISMATCH,
    check_against_page,
    validate_read,
)
from app.integrations.ai import AIProviderError
from app.integrations.storage import LocalDocumentStorage
from app.models.ai import AIGeneration
from app.models.document import Document, DocumentPage, DocumentStatus
from app.models.question import Question, VerificationStatus
from app.models.user import User
from app.services.ai_paper_reader import AiPaperReader, batches
from tests.conftest import make_user
from tests.fakes import FakeAIProvider
from tests.pdf_factory import text_pdf
from tests.test_ai import AppFactory, ai, make_api

__all__ = ["ai", "make_api"]  # fixtures re-used from test_ai


def q(number: int, page: int, stem: str, **extra: Any) -> dict[str, Any]:
    return {
        "number": number,
        "page": page,
        "section": extra.get("section"),
        "passage": extra.get("passage"),
        "stem": stem,
        "options": extra.get(
            "options",
            [{"label": "(a)", "text": "10"}, {"label": "(b)", "text": "20"},
             {"label": "(c)", "text": "30"}, {"label": "(d)", "text": "40"}],
        ),
        "answer_label": extra.get("answer_label", "b"),
        "has_figure": extra.get("has_figure", False),
    }  # fmt: skip


# --- pure checks -----------------------------------------------------------------------------


def test_validation_keeps_good_questions_and_says_why_others_were_dropped() -> None:
    data = {
        "questions": [
            q(1, 1, "What is 10% of 200?"),  # answer "b" → option 2
            q(2, 4, "Starts on a context page"),  # read by the next request
            q(1, 1, "Same number again"),
            q(3, 1, "  "),
            q(4, 1, "One option only", options=[{"label": "a", "text": "x"}]),
            q(5, 2, "No answer printed", answer_label=None),
            q(6, 2, "Answer not an option", answer_label="e"),
            q(7, 2, "Look at the figure", has_figure=True),
        ]
    }
    kept, dropped = validate_read(data, main_pages=[1, 2, 3])
    assert [k.number for k in kept] == [1, 5, 6, 7]
    assert sorted(dropped) == ["bad_options", "bad_stem", "duplicate_number"]
    assert kept[0].answer_position == 2 and not kept[0].issues
    assert [i.code for i in kept[1].issues] == ["missing_answer"]
    assert [i.code for i in kept[2].issues] == ["unrecognised_answer"]
    assert kept[3].has_figure and [i.code for i in kept[3].issues] == ["image_dependent"]
    assert validate_read({}, [1]) == ([], ["no_question_list"])


def test_ai_text_is_compared_with_the_page_never_trusted_blindly() -> None:
    (copied,), _ = validate_read({"questions": [q(1, 1, "What is 10% of 200?")]}, [1])
    check_against_page(copied, "Q1. What is 10% of 200? (a) 10 (b) 20 (c) 30 (d) 40")
    assert copied.issues == []

    (reworded,), _ = validate_read(
        {"questions": [q(1, 1, "Compute ten percent of two hundred please")]}, [1]
    )
    check_against_page(reworded, "Q1. What is 10% of 200? (a) 10 (b) 20 (c) 30 (d) 40")
    assert [i.code for i in reworded.issues] == [AI_TEXT_MISMATCH]

    (scanned,), _ = validate_read({"questions": [q(1, 1, "What is 10% of 200?")]}, [1])
    check_against_page(scanned, "", "Next page text")  # a scan: nothing on its own page
    assert [i.code for i in scanned.issues] == [AI_READ_UNCHECKED]
    assert batches([1, 2, 3, 4, 5, 6, 7]) == [[1, 2, 3], [4, 5, 6], [7]]


# --- a full read -----------------------------------------------------------------------------

PAGE_1 = "1. What is 10% of 200? (a) 10 (b) 20 (c) 30 (d) 40"
PAGE_2 = "2. Which is a prime number? (a) 10 (b) 20 (c) 30 (d) 40"


def paper(db: Session, storage: LocalDocumentStorage, owner: User, pages: list[str]) -> Document:
    key = f"documents/{uuid.uuid4().hex}.pdf"
    path = storage.path_for(key)
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(text_pdf([[t] for t in pages]))
    doc = Document(
        owner_id=owner.id, exam_code="SSC_CHSL", language="en", original_filename="new.pdf",
        size_bytes=path.stat().st_size, sha256="0" * 64, storage_key=key,
        page_count=len(pages), status=DocumentStatus.COMPLETED, segmentation_status="completed",
    )  # fmt: skip
    db.add(doc)
    db.flush()
    for number, text in enumerate(pages, start=1):
        db.add(DocumentPage(document_id=doc.id, page_number=number, method="text", text=text,
                            char_count=len(text)))  # fmt: skip
    db.flush()
    return doc


def test_a_paper_is_read_page_by_page_and_reviewed_questions_are_kept(
    db_session: Session, storage: LocalDocumentStorage, settings: Settings, user: User
) -> None:
    doc = paper(db_session, storage, user, [PAGE_1, PAGE_2, "", "4. Last page question"])
    reviewed = Question(
        origin="source", owner_id=user.id, exam_code="SSC_CHSL", stem="Kept as reviewed",
        language="en", document_id=doc.id, source_question_number=2, source_pages=[2],
        verification_status=VerificationStatus.VERIFIED,
    )  # fmt: skip
    rules_made = Question(
        origin="source", owner_id=user.id, exam_code="SSC_CHSL", stem="Rules' garbled split",
        language="en", document_id=doc.id, source_question_number=9, source_pages=[1],
    )  # fmt: skip
    db_session.add_all([reviewed, rules_made])
    doc.ai_read_status = "queued"
    db_session.commit()
    provider = FakeAIProvider(
        responses=[
            {"questions": [q(1, 1, "What is 10% of 200?"),
                           q(2, 2, "Which is a prime number?"),
                           q(3, 3, "A question on a scanned page")]},
            {"questions": [q(4, 4, "Last page question", answer_label=None, options=[])]},
        ]
    )  # fmt: skip
    reader = AiPaperReader(provider, storage, settings)

    claimed = reader.claim_next(db_session)
    assert claimed == doc.id
    reader.read(db_session, doc.id)

    db_session.refresh(doc)
    assert (doc.ai_read_status, doc.ai_read_pages_done, doc.ai_read_error) == ("completed", 4, None)
    # Two requests: pages 1-3 (+ page 4 as context) and page 4; one image per page shown.
    assert [c.images for c in provider.calls] == [4, 1]
    assert "Page 4 (context only" in provider.calls[0].prompt
    assert "Copy the text EXACTLY" in provider.calls[0].system
    questions = {
        (x.source_question_number or 0): x
        for x in db_session.scalars(select(Question).where(Question.document_id == doc.id))
    }
    assert sorted(questions) == [1, 2, 3, 4]  # the rules' unreviewed Q9 was replaced
    assert questions[2].stem == "Kept as reviewed"  # a reviewer's decision is never overwritten
    assert questions[1].extracted_by == "ai" and questions[1].origin == "source"
    assert questions[1].correct_option_position == 2 and questions[1].issues == []
    assert [i.code for i in questions[3].issues] == [AI_READ_UNCHECKED]  # no text on page 3
    assert questions[4].options == [] and questions[4].issues == []  # no options, no answer
    assert doc.questions_found == 4
    logs = db_session.scalars(select(AIGeneration).where(AIGeneration.task == "paper_read")).all()
    assert [log.detail for log in logs] == ["pages 1-3", "pages 4-4"]  # no paper text stored


def test_provider_failures_end_the_job_with_a_reason(
    db_session: Session, storage: LocalDocumentStorage, settings: Settings, user: User
) -> None:
    doc = paper(db_session, storage, user, [PAGE_1])
    doc.ai_read_status = "queued"
    db_session.commit()
    provider = FakeAIProvider(responses=[AIProviderError("refused", retryable=False)])
    reader = AiPaperReader(provider, storage, settings)
    reader.read(db_session, reader.claim_next(db_session) or doc.id)
    db_session.refresh(doc)
    assert (doc.ai_read_status, doc.ai_read_error) == ("failed", "ai_refused")

    doc.ai_read_status = "queued"
    db_session.commit()
    AiPaperReader(None, storage, settings).read(db_session, doc.id)
    db_session.refresh(doc)
    assert doc.ai_read_error == "ai_disabled"
    assert AiPaperReader(None, storage, settings).claim_next(db_session) is None  # nothing queued


# --- the endpoint ----------------------------------------------------------------------------


def test_the_learner_queues_a_reading_of_their_own_processed_paper(
    make_api: AppFactory,
    ai: FakeAIProvider,
    db_session: Session,
    storage: LocalDocumentStorage,
    user: User,
) -> None:
    doc = paper(db_session, storage, user, [PAGE_1])
    api = make_api(ai)

    queued = api.post(f"/api/v1/ai/documents/{doc.id}/read")
    assert queued.status_code == 202, queued.text
    assert queued.json()["ai_read_status"] == "queued"
    again = api.post(f"/api/v1/ai/documents/{doc.id}/read")
    assert again.json()["error"]["code"] == "ai_read_in_progress"
    assert ai.calls == []  # the worker does the reading, not the request

    stranger = paper(db_session, storage, make_user(db_session, "x@example.com"), [PAGE_1])
    assert api.post(f"/api/v1/ai/documents/{stranger.id}/read").status_code == 404
    doc.ai_read_status, doc.status = "none", DocumentStatus.PROCESSING
    db_session.flush()
    assert api.post(f"/api/v1/ai/documents/{doc.id}/read").json()["error"]["code"] == (
        "not_processed"
    )
    assert make_api(None).post(f"/api/v1/ai/documents/{doc.id}/read").status_code == 503


def test_the_review_summary_shows_the_reading_and_ai_read_questions(
    make_api: AppFactory,
    ai: FakeAIProvider,
    db_session: Session,
    storage: LocalDocumentStorage,
    settings: Settings,
    user: User,
) -> None:
    doc = paper(db_session, storage, user, [PAGE_1])
    api = make_api(ai)
    api.post(f"/api/v1/ai/documents/{doc.id}/read")
    summary = api.get(f"/api/v1/documents/{doc.id}/parse-summary").json()
    assert (summary["ai_read_status"], summary["page_count"]) == ("queued", 1)

    ai.responses = [{"questions": [q(1, 1, "What is 10% of 200?")]}]
    reader = AiPaperReader(ai, storage, settings)
    reader.read(db_session, reader.claim_next(db_session) or doc.id)
    summary = api.get(f"/api/v1/documents/{doc.id}/parse-summary").json()
    assert (summary["ai_read_status"], summary["read_by_ai"]) == ("completed", 1)
    question = api.get(f"/api/v1/questions?document_id={doc.id}").json()["items"][0]
    assert question["extracted_by"] == "ai"
