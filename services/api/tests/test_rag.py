"""RAG: the pure parts (query words, snippets, prompt, citation check) and retrieval against
real PostgreSQL (ranking, account and exam isolation, which questions may be sources)."""

import uuid

from sqlalchemy import select
from sqlalchemy.orm import Session

from app.domain.rag import (
    RagSource,
    best_window,
    query_terms,
    rag_prompt,
    ts_query,
    validate_rag,
)
from app.models.ai import AIGeneration
from app.models.document import Document, DocumentPage, DocumentStatus
from app.models.question import QuestionOrigin, VerificationStatus
from app.models.sync import SyncItem
from app.models.user import User
from app.services.rag_service import RagRetriever
from tests.conftest import make_user
from tests.fakes import FakeAIProvider
from tests.test_ai import AppFactory, ai, make_api
from tests.test_practice import document, make_question

__all__ = ["ai", "document", "make_api"]  # fixtures re-used from other test modules

# --- pure parts ------------------------------------------------------------------------------


def test_query_terms_drop_stop_words_and_keep_hindi() -> None:
    assert query_terms("What is the Swift optional binding?") == ["swift", "optional", "binding"]
    assert query_terms("swift SWIFT, swift!") == ["swift"]
    assert query_terms("प्रतिशत क्या है") == ["प्रतिशत", "क्या", "है"]  # matras kept in words
    assert query_terms("the") == ["the"]  # only stop words: keep them
    assert query_terms("swift & class | it's") == ["swift", "class"]  # no tsquery syntax
    assert ts_query(["swift", "optional"]) == "swift:* | optional:*"


def test_best_window_picks_the_densest_part() -> None:
    text = "filler " * 300 + "optional binding unwraps an optional value " + "more " * 100
    window = best_window(text, ["optional", "binding"], size=200)
    assert "optional binding unwraps" in window and len(window) <= 200
    assert best_window("short text", ["x"]) == "short text"


def source(key: str, *, verified: bool = True) -> RagSource:
    return RagSource(key=key, kind="page", label=f"notes.pdf, page {key[1:]}", text="...",
                     verified=verified, rank=1.0)  # fmt: skip


def test_prompt_numbers_sources_and_flags_unchecked_ones() -> None:
    prompt = rag_prompt(
        query="प्रतिशत", exam_name="SSC CGL", sources=[source("S1"), source("S2", verified=False)]
    )
    assert "[S1] notes.pdf, page 1\n" in prompt
    assert "[S2] notes.pdf, page 2 (not checked by a reviewer)" in prompt
    assert "Hindi" in prompt and "SSC CGL" in prompt


def test_citations_must_name_sources_that_were_sent() -> None:
    keys = ["S1", "S2"]
    ok = validate_rag(
        {"found": True, "answer": "Structs are copied [S1]. [S2]", "cited": ["S2"],
         "confident": True}, keys,
    )  # fmt: skip
    assert ok is not None and ok.cited == ("S1", "S2")
    simple = validate_rag(
        {"found": True, "answer": "Copied [S1].", "simple": " Like a photocopy. ", "cited": [],
         "confident": True}, keys,
    )  # fmt: skip
    assert simple is not None and simple.simple == "Like a photocopy."
    assert ok.simple is None  # no simple part: the answer from the material still counts
    not_found = validate_rag({"found": False, "answer": "", "cited": [], "confident": True}, keys)
    assert not_found is not None and not_found.found is False
    invented = {"found": True, "answer": "Yes [S9].", "cited": ["S9"], "confident": True}
    assert validate_rag(invented, keys) is None  # cites something we never sent
    listed_only = {"found": True, "answer": "Yes.", "cited": ["S1"], "confident": True}
    assert validate_rag(listed_only, keys) is None  # no marker in the text
    blank = {"found": True, "answer": "  ", "cited": ["S1"], "confident": True}
    assert validate_rag(blank, keys) is None


# --- retrieval -------------------------------------------------------------------------------


def add_page(db: Session, doc: Document, number: int, text: str) -> None:
    db.add(DocumentPage(document_id=doc.id, page_number=number, method="text", text=text,
                        char_count=len(text)))  # fmt: skip
    db.flush()


def other_document(db: Session, owner: User, exam: str = "SSC_CHSL") -> Document:
    doc = Document(
        owner_id=owner.id, exam_code=exam, language="en", original_filename="other.pdf",
        size_bytes=1, sha256="1" * 64, storage_key=f"documents/{uuid.uuid4().hex}.pdf",
        page_count=1, status=DocumentStatus.COMPLETED,
    )  # fmt: skip
    db.add(doc)
    db.flush()
    return doc


def test_pages_rank_by_matches_and_stay_in_the_account_and_exam(
    db_session: Session, user: User, document: Document
) -> None:
    add_page(db_session, document, 1, "Swift structs are value types; classes are references.")
    add_page(db_session, document, 2, "A struct is copied on assignment. Struct value semantics.")
    add_page(db_session, document, 3, "Percentage and profit questions.")
    stranger = make_user(db_session, "stranger@example.com")
    add_page(db_session, other_document(db_session, stranger), 1, "struct value struct value")
    add_page(db_session, other_document(db_session, user, "SSC_CGL"), 1, "struct value types")

    found = RagRetriever(db_session, user.id).retrieve(["struct", "value"], "SSC_CHSL")

    assert [(s.kind, s.page_number) for s in found] == [("page", 2), ("page", 1)]
    assert [s.key for s in found] == ["S1", "S2"]
    assert found[0].label == "sample.pdf, page 2" and found[0].verified is False


def test_questions_and_concepts_are_sources_but_never_ai_or_rejected_questions(
    db_session: Session, user: User, document: Document
) -> None:
    verified = make_question(db_session, document, stem="Which keyword declares a Swift struct?")
    make_question(db_session, document, stem="Swift struct rejected copy",
                  status=VerificationStatus.REJECTED)  # fmt: skip
    ai_made = make_question(db_session, document, stem="Swift struct AI question")
    ai_made.origin = QuestionOrigin.AI
    ai_made.document_id = None
    ai_made.source_question_number = None
    ai_made.ai_provider, ai_made.ai_model, ai_made.ai_prompt_version = "fake", "m", "p"
    ai_made.ai_source_note = "concept"
    db_session.add(
        SyncItem(owner_id=user.id, entity="concept", item_id="c1", deleted=False,
                 data={"exam_code": "SSC_CHSL", "title": "Struct vs class",
                       "notes": "Structs are value types.", "subject": "Swift",
                       "topic": "Types", "archived_at": None})
    )  # fmt: skip
    db_session.flush()

    found = RagRetriever(db_session, user.id).retrieve(["swift", "struct"], "SSC_CHSL")

    kinds = {(s.kind, s.question_id or s.concept_id) for s in found}
    assert ("question", str(verified.id)) in kinds
    assert ("concept", "c1") in kinds
    assert len(found) == 2  # rejected and AI-made questions are not sources
    question = next(s for s in found if s.kind == "question")
    assert question.verified and "Answer: (1) opt 1" in question.text
    assert question.label.startswith("Q.") and "sample.pdf" in question.label


def test_concepts_saved_from_an_ai_lesson_are_unchecked_sources(
    db_session: Session, user: User
) -> None:
    for item_id, tags in (("own", ["maths"]), ("ai", ["ai-generated"])):
        db_session.add(
            SyncItem(owner_id=user.id, entity="concept", item_id=item_id, deleted=False,
                     data={"exam_code": "SSC_CHSL", "title": f"Percentage {item_id}",
                           "notes": "Percentage means per hundred.", "subject": "Maths",
                           "topic": "Percentage", "tags": tags, "archived_at": None})
        )  # fmt: skip
    db_session.flush()

    found = RagRetriever(db_session, user.id).retrieve(["percentage"], "SSC_CHSL")

    assert {s.concept_id: s.verified for s in found} == {"own": True, "ai": False}


def test_nothing_matching_means_no_sources(db_session: Session, user: User) -> None:
    retriever = RagRetriever(db_session, user.id)
    assert retriever.retrieve(["kotlin"], "SSC_CHSL") == []
    assert retriever.retrieve([], "SSC_CHSL") == []


# --- the whole loop through the API (fake AI provider: no network) ---------------------------


def test_search_answer_cites_the_learners_own_pages(
    make_api: AppFactory, ai: FakeAIProvider, db_session: Session, user: User, document: Document
) -> None:
    add_page(db_session, document, 4, "Structs are value types and are copied on assignment.")
    stranger = make_user(db_session, "stranger@example.com")
    add_page(db_session, other_document(db_session, stranger), 1, "SECRET struct value notes")
    ai.responses = [
        {"found": True, "answer": "Structs are copied on assignment [S1].", "cited": ["S1"],
         "confident": True}
    ]  # fmt: skip

    response = make_api(ai).post(
        "/api/v1/ai/search-answer", json={"text": "struct value", "exam_code": "SSC_CHSL"}
    )

    assert response.status_code == 200, response.text
    body = response.json()
    assert body["found"] is True and body["answer"].endswith("[S1].")
    assert body["sources"][0]["label"] == "sample.pdf, page 4"
    assert body["sources"][0]["cited"] is True and body["sources"][0]["verified"] is False
    assert body["sources"][0]["document_id"] == str(document.id)
    prompt = ai.calls[0].prompt
    assert "copied on assignment" in prompt and "SECRET" not in prompt  # never other accounts
    assert "using ONLY the sources" in ai.calls[0].system
    log = db_session.scalars(select(AIGeneration).where(AIGeneration.task == "rag_answer")).one()
    assert (log.outcome, log.detail) == ("ok", "1 sources, 1 cited")  # no text stored


def test_no_matching_material_is_answered_without_an_ai_call(
    make_api: AppFactory, ai: FakeAIProvider, document: Document
) -> None:
    response = make_api(ai).post(
        "/api/v1/ai/search-answer", json={"text": "kotlin coroutines", "exam_code": "SSC_CHSL"}
    )
    assert response.json() == {
        "found": False, "answer": None, "simple": None, "confident": True, "sources": [],
        "model": None,
        "prompt_version": "p9.5",
    }  # fmt: skip
    assert ai.calls == []  # nothing spent


def test_invented_citations_are_rejected_and_logged(
    make_api: AppFactory, ai: FakeAIProvider, db_session: Session, document: Document
) -> None:
    add_page(db_session, document, 1, "Struct notes.")
    ai.responses = [{"found": True, "answer": "Yes [S7].", "cited": ["S7"], "confident": True}]
    api = make_api(ai)
    bad = api.post("/api/v1/ai/search-answer", json={"text": "struct", "exam_code": "SSC_CHSL"})
    assert bad.status_code == 502
    log = db_session.scalars(select(AIGeneration).where(AIGeneration.task == "rag_answer")).one()
    assert log.outcome == "invalid"

    ai.responses = [{"found": False, "answer": "", "cited": [], "confident": False}]
    honest = api.post("/api/v1/ai/search-answer", json={"text": "struct", "exam_code": "SSC_CHSL"})
    assert honest.json()["found"] is False and honest.json()["sources"][0]["cited"] is False

    unknown = api.post("/api/v1/ai/search-answer", json={"text": "struct", "exam_code": "NOPE"})
    assert unknown.status_code == 422
    off = make_api(None).post(
        "/api/v1/ai/search-answer", json={"text": "struct", "exam_code": "SSC_CHSL"}
    )
    assert off.status_code == 503
