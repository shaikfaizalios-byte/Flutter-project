"""Q&A notes (questions with written answers, no options): reading both layouts, storing
them as written questions, reviewing them, and the bulk-verify safety for AI-read questions."""

import uuid
from typing import Any

from fastapi.testclient import TestClient
from sqlalchemy.orm import Session

from app.core.config import Settings
from app.domain.qa_notes import read_qa_notes
from app.domain.segmentation import PageText
from app.integrations.storage import LocalDocumentStorage
from app.models.question import Question, QuestionIssue
from app.services.processing_service import DocumentProcessor
from tests.fakes import FakeOcrEngine
from tests.pdf_factory import text_pdf
from tests.test_question_bank import DOCUMENTS, questions

# Layout A: unnumbered questions, "Answer:" lines, a name printed on every page.
NOTES_A = [
    [
        "Jane Doe",
        "Interview Preparation Blueprint",
        "Essential Topics You Should Know",
        "What is the difference between a struct and a class",
        "in Swift?",
        "Answer:",
        "A struct is a value type and is copied on assignment.",
        "A class is a reference type and supports inheritance.",
        "Explain optional binding.",
        "Answer: It unwraps an optional safely with if let or guard let.",
    ],
    [
        "Jane Doe",
        "How do you avoid retain cycles? Which keyword helps?",
        "Answer:",
        "Use weak or unowned references:",
        "1. Mark delegates weak.",
        "2. Capture self weakly in closures.",
    ],
    ["Jane Doe", "What is ARC?", "Answer: Automatic Reference Counting frees unused objects."],
]
# Layout B: numbered questions, the answer follows directly; a numbered list in an answer.
NOTES_B = [
    "Q.1 What are optionals in Swift? How do you handle them safely?",
    "Optionals hold a value or nil. Unwrap them with if let.",
    "Q.2 What is the difference between var and let?",
    "var can change. let cannot.",
    "1. let is a constant.",
    "2. var is a variable.",
    "Q.3 Name three iOS frameworks",
    "UIKit, SwiftUI and Combine.",
]


def pages(*texts: list[str]) -> list[PageText]:
    return [PageText(n, "\n".join(lines)) for n, lines in enumerate(texts, start=1)]


# --- reading -------------------------------------------------------------------------------


def test_notes_with_answer_lines_are_split_into_questions_and_answers() -> None:
    found = read_qa_notes(pages(*NOTES_A))
    assert [q.stem for q in found] == [
        "What is the difference between a struct and a class in Swift?",  # title lines dropped
        "Explain optional binding.",  # an instruction is a question too
        "How do you avoid retain cycles? Which keyword helps?",  # "Jane Doe" is page furniture
        "What is ARC?",
    ]
    assert found[0].answer.startswith("A struct is a value type")
    assert "inheritance." in found[0].answer and "Explain" not in found[0].answer
    assert found[1].answer == "It unwraps an optional safely with if let or guard let."
    assert found[2].answer.endswith("2. Capture self weakly in closures.")  # a list stays in
    assert [(q.number, q.numbered) for q in found] == [
        (1, False),
        (2, False),
        (3, False),
        (4, False),
    ]
    assert all(q.issues == [] for q in found)
    assert found[2].pages == [2]


def test_numbered_notes_keep_lists_in_answers_and_flag_unclear_ends() -> None:
    found = read_qa_notes(pages(NOTES_B))
    assert [(q.number, q.stem) for q in found] == [
        (1, "What are optionals in Swift? How do you handle them safely?"),
        (2, "What is the difference between var and let?"),
        (3, "Name three iOS frameworks"),
    ]
    assert (
        found[1].answer
        == "var can change. let cannot.\n1. let is a constant.\n2. var is a variable."
    )
    assert [i.code for i in found[2].issues] == ["ambiguous_boundary"]  # no "?": a guess
    assert found[0].numbered and found[0].issues == []


def test_multiple_choice_papers_and_plain_text_are_not_qa_notes() -> None:
    assert read_qa_notes(pages(["Q.1 What is 2+2?", "(a) 3 (b) 4 (c) 5 (d) 6"])) == []
    assert read_qa_notes(pages(["Just a paragraph of notes.", "Another line."])) == []


# --- through the pipeline ------------------------------------------------------------------


def process(client: TestClient, session: Session, storage: LocalDocumentStorage, settings: Settings,
            page_lines: list[list[str]]) -> uuid.UUID:  # fmt: skip
    response = client.post(
        DOCUMENTS,
        files={"file": ("ios-notes.pdf", text_pdf(page_lines), "application/pdf")},
        data={"exam_code": "SSC_CHSL", "language": "en"},
    )
    assert response.status_code == 201, response.text
    document_id = uuid.UUID(response.json()["id"])
    processor = DocumentProcessor(storage=storage, ocr=FakeOcrEngine(), settings=settings)
    assert processor.claim_next(session) == document_id
    processor.process(session, document_id)
    return document_id


def test_qa_notes_become_written_questions_that_can_be_reviewed(
    db_client: TestClient, db_session: Session, storage: LocalDocumentStorage, settings: Settings
) -> None:
    document_id = process(db_client, db_session, storage, settings, NOTES_A)

    found = questions(db_client, document_id=str(document_id))
    assert len(found) == 4
    first = next(q for q in found if q["source_question_number"] == 1)
    assert (first["answer_type"], first["options"]) == ("written", [])
    assert first["model_answer"].startswith("A struct is a value type")
    assert first["open_issue_count"] == 0  # no "options incomplete" / "answer not found"

    verified = db_client.post(f"{DOCUMENTS}/{document_id}/questions/verify-clean").json()
    assert verified["verified"] == 4

    url = f"/api/v1/questions/{first['id']}"
    edited = db_client.patch(url, json={"model_answer": "Structs are copied; classes are shared."})
    assert edited.json()["model_answer"] == "Structs are copied; classes are shared."
    assert edited.json()["verification_status"] == "unverified"  # edited: check again
    cleared = db_client.patch(url, json={"model_answer": None})
    assert [i["code"] for i in cleared.json()["issues"] if not i["resolved"]] == ["missing_answer"]
    to_choice = db_client.patch(url, json={"answer_type": "choice"}).json()
    assert to_choice["answer_type"] == "choice" and to_choice["model_answer"] is None
    bad = db_client.patch(url, json={"model_answer": "x"})
    assert bad.status_code == 422  # only written questions have a written answer


def test_written_questions_never_enter_practice(
    db_client: TestClient, db_session: Session, storage: LocalDocumentStorage, settings: Settings
) -> None:
    document_id = process(db_client, db_session, storage, settings, NOTES_A)
    db_client.post(f"{DOCUMENTS}/{document_id}/questions/verify-clean")
    session = db_client.post("/api/v1/practice/sessions", json={"exam_code": "SSC_CHSL"})
    assert session.status_code in (409, 422)  # nothing practisable: written ones are flashcards


def test_bulk_verify_skips_questions_ai_read_without_page_confirmation(
    db_client: TestClient, db_session: Session, storage: LocalDocumentStorage, settings: Settings
) -> None:
    document_id = process(db_client, db_session, storage, settings, NOTES_A)
    flagged: Any = (
        db_session.query(Question)
        .filter_by(document_id=document_id, source_question_number=1)
        .one()
    )
    flagged.extracted_by = "ai"
    flagged.issues.append(
        QuestionIssue(document_id=document_id, code="ai_text_mismatch", detail="80%")
    )
    db_session.commit()

    result = db_client.post(f"{DOCUMENTS}/{document_id}/questions/verify-clean").json()
    assert (result["verified"], result["left_for_review"]) == (
        3,
        1,
    )  # a person must look at the AI one
    single = db_client.patch(
        f"/api/v1/questions/{flagged.id}", json={"verification_status": "verified"}
    )
    assert single.json()["verification_status"] == "verified"  # after looking, one by one
