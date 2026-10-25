"""AI assistance with a deterministic fake provider (no network, real PostgreSQL)."""

from collections.abc import Callable, Iterator
from typing import Any

import pytest
from fastapi.testclient import TestClient
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.core.config import Settings
from app.integrations.ai import AIProviderError
from app.integrations.storage import LocalDocumentStorage
from app.main import create_app
from app.models.ai import AIGeneration
from app.models.document import Document
from app.models.question import Question, Topic, VerificationStatus
from app.models.user import User
from tests.conftest import auth_headers, make_user
from tests.fakes import FakeAIProvider
from tests.test_practice import document, make_formats_ready, make_question

__all__ = ["document"]  # fixture re-used from test_practice

AppFactory = Callable[..., TestClient]


@pytest.fixture
def make_api(
    settings: Settings,
    db_engine: Any,
    db_session: Session,
    storage: LocalDocumentStorage,
    user: User,
) -> Iterator[AppFactory]:
    from app.database.session import get_session

    clients: list[TestClient] = []

    def build(provider: FakeAIProvider | None = None, **overrides: Any) -> TestClient:
        app = create_app(
            settings.model_copy(update=overrides),
            engine=db_engine,
            storage=storage,
            ai_provider=provider,
        )
        app.dependency_overrides[get_session] = lambda: db_session
        client = TestClient(app, raise_server_exceptions=False, headers=auth_headers(user))
        client.__enter__()
        clients.append(client)
        return client

    yield build
    for client in clients:
        client.__exit__(None, None, None)


@pytest.fixture
def ai() -> FakeAIProvider:
    return FakeAIProvider()


@pytest.fixture
def api(make_api: AppFactory, ai: FakeAIProvider) -> TestClient:
    return make_api(ai)


def generated(n: int, *, prefix: str = "Generated question", answer: int = 2) -> dict[str, Any]:
    return {
        "questions": [
            {
                "stem": f"{prefix} number {i}?",
                "options": [f"A{i}", f"B{i}", f"C{i}", f"D{i}"],
                "correct_option": answer,
                "explanation": f"Because B{i}.",
            }
            for i in range(1, n + 1)
        ]
    }


def generations(db: Session) -> list[AIGeneration]:
    return list(db.scalars(select(AIGeneration).order_by(AIGeneration.created_at)).all())


# --- status and switching off ------------------------------------------------------------


def test_status_reports_availability_without_secrets(make_api: AppFactory) -> None:
    off = make_api(None).get("/api/v1/ai/status").json()
    assert off == {"enabled": False, "provider": None, "model": None, "features": []}

    on = make_api(FakeAIProvider()).get("/api/v1/ai/status").json()
    assert on["enabled"] is True
    assert (on["provider"], on["model"]) == ("fake", "fake-model-1")
    assert set(on) == {"enabled", "provider", "model", "features"}


def test_without_a_provider_ai_actions_are_refused(
    make_api: AppFactory, db_session: Session, document: Document
) -> None:
    question = make_question(db_session, document, explanation=None)
    response = make_api(None).post(f"/api/v1/ai/questions/{question.id}/explanation")

    assert response.status_code == 503
    assert response.json()["error"]["code"] == "ai_disabled"


# --- explanations ------------------------------------------------------------------------


def test_explanation_draft_review_and_labelled_use_in_practice(
    api: TestClient, ai: FakeAIProvider, db_session: Session, document: Document
) -> None:
    question = make_question(db_session, document, explanation=None, stem="What is 20% of 150?")
    ai.responses.append({"explanation": "20/100 × 150 = 30.", "confident": True})

    response = api.post(f"/api/v1/ai/questions/{question.id}/explanation")
    assert response.status_code == 201, response.text
    draft = response.json()
    assert (draft["status"], draft["provider"], draft["model"]) == ("draft", "fake", "fake-model-1")
    assert draft["prompt_version"] == "p9.5"

    # The prompt carries the question and its known answer; the system prompt forbids
    # presenting output as official.
    call = ai.calls[0]
    assert "What is 20% of 150?" in call.prompt
    assert "correct answer is option (1)" in call.prompt
    assert "English" in call.prompt
    assert "Never claim" in call.system

    read = api.get(f"/api/v1/questions/{question.id}").json()
    assert read["explanation"] is None  # source content is untouched
    assert read["ai_explanation"]["status"] == "draft"

    # A draft is never shown to learners.
    session = api.post("/api/v1/practice/sessions", json={"count": 1}).json()
    feedback = api.put(
        f"/api/v1/practice/sessions/{session['id']}/answers/1",
        json={"selected_position": 1, "client_seq": 1},
    ).json()["feedback"]
    assert (feedback["explanation"], feedback["explanation_origin"]) == (None, None)

    approved = api.patch(
        f"/api/v1/ai/explanations/{draft['id']}",
        json={"status": "approved", "text": "20% of 150 = 0.2 × 150 = 30."},
    ).json()
    assert (approved["status"], approved["edited"]) == ("approved", True)

    session = api.post("/api/v1/practice/sessions", json={"count": 1}).json()
    feedback = api.put(
        f"/api/v1/practice/sessions/{session['id']}/answers/1",
        json={"selected_position": 1, "client_seq": 1},
    ).json()["feedback"]
    assert feedback["explanation"] == "20% of 150 = 0.2 × 150 = 30."
    assert feedback["explanation_origin"] == "ai"

    [log] = generations(db_session)
    assert (log.task, log.outcome, log.items_created) == ("explanation", "ok", 1)
    assert (log.input_tokens, log.output_tokens) == (120, 80)


def test_explanations_only_for_verified_source_questions_without_one(
    api: TestClient, db_session: Session, document: Document
) -> None:
    has_one = make_question(db_session, document, explanation="From the key.")
    unverified = make_question(
        db_session, document, explanation=None, status=VerificationStatus.UNVERIFIED
    )

    conflict = api.post(f"/api/v1/ai/questions/{has_one.id}/explanation")
    assert conflict.status_code == 409
    assert conflict.json()["error"]["code"] == "explanation_exists"
    refused = api.post(f"/api/v1/ai/questions/{unverified.id}/explanation")
    assert refused.status_code == 422
    assert refused.json()["error"]["code"] == "not_eligible"


def test_source_explanations_are_labelled_as_source(
    api: TestClient, db_session: Session, document: Document
) -> None:
    make_question(db_session, document, explanation="From the key.")
    session = api.post("/api/v1/practice/sessions", json={"count": 1}).json()
    feedback = api.put(
        f"/api/v1/practice/sessions/{session['id']}/answers/1",
        json={"selected_position": 2, "client_seq": 1},
    ).json()["feedback"]
    assert (feedback["explanation"], feedback["explanation_origin"]) == ("From the key.", "source")


def test_provider_failures_are_retryable_errors_and_logged(
    api: TestClient, ai: FakeAIProvider, db_session: Session, document: Document
) -> None:
    question = make_question(db_session, document, explanation=None)
    ai.responses += [AIProviderError("timeout"), {"explanation": "", "confident": True}]

    failed = api.post(f"/api/v1/ai/questions/{question.id}/explanation")
    assert failed.status_code == 502
    assert failed.json()["error"]["code"] == "ai_unavailable"
    unusable = api.post(f"/api/v1/ai/questions/{question.id}/explanation")
    assert unusable.status_code == 502

    assert [(g.outcome, g.detail) for g in generations(db_session)] == [
        ("error", "timeout"),
        ("invalid", "bad_explanation"),
    ]


# --- generated questions -----------------------------------------------------------------


def test_generated_questions_are_validated_stored_unverified_and_labelled(
    api: TestClient, ai: FakeAIProvider, db_session: Session, document: Document
) -> None:
    topic = Topic(subject="Quantitative Aptitude", name="AI Percentage", keywords=[])
    db_session.add(topic)
    db_session.flush()
    source = make_question(db_session, document, topic=topic, stem="What is 10% of 50?")
    batch = generated(3)
    batch["questions"][1]["correct_option"] = 7  # invalid answer
    batch["questions"].append(dict(batch["questions"][0], stem="What is 10% of 50?"))  # extra
    ai.responses.append(batch)

    response = api.post(
        "/api/v1/ai/questions/generate",
        json={
            "exam_code": "SSC_CHSL",
            "language": "en",
            "count": 3,
            "source_question_id": str(source.id),
        },
    )
    assert response.status_code == 201, response.text
    result = response.json()
    assert result["rejected"] == 1
    assert result["rejection_reasons"] == ["bad_answer"]
    created = result["created"]
    assert len(created) == 2
    first = created[0]
    assert first["origin"] == "ai"
    assert first["verification_status"] == "unverified"
    assert first["document_id"] is None and first["source_question_number"] is None
    assert first["ai"] == {
        "provider": "fake",
        "model": "fake-model-1",
        "prompt_version": "p9.5",
        "source_question_id": str(source.id),
        "source_note": None,
    }
    assert (first["topic"]["name"], first["topic_status"], first["topic_suggested_by"]) == (
        "AI Percentage",
        "suggested",
        "ai",
    )
    assert [o["text"] for o in first["options"]] == ["A1", "B1", "C1", "D1"]
    assert first["correct_option_position"] == 2
    assert first["answer_source"] == "ai"

    [log] = generations(db_session)
    assert (log.task, log.outcome, log.items_created, log.items_rejected) == (
        "questions",
        "partial",
        2,
        1,
    )
    assert log.detail == "bad_answer"

    listed = api.get("/api/v1/questions", params={"origin": "ai"}).json()
    assert listed["total"] == 2


def test_copies_of_the_source_and_duplicates_are_rejected(
    api: TestClient, ai: FakeAIProvider, db_session: Session, document: Document
) -> None:
    source = make_question(db_session, document, stem="Find the odd one out: 3, 5, 7, 9")
    batch = generated(2)
    batch["questions"][0]["stem"] = "  find the ODD one out: 3, 5, 7, 9 "
    batch["questions"][1]["options"] = ["x", "X", "y", "z"]
    ai.responses.append(batch)

    result = api.post(
        "/api/v1/ai/questions/generate",
        json={
            "exam_code": "SSC_CHSL",
            "language": "en",
            "count": 2,
            "source_question_id": str(source.id),
        },
    ).json()

    assert result["created"] == []
    assert result["rejection_reasons"] == ["copied_source", "duplicate_options"]
    assert generations(db_session)[0].outcome == "invalid"


def test_generation_needs_a_verified_basis(
    api: TestClient, db_session: Session, document: Document
) -> None:
    unverified = make_question(db_session, document, status=VerificationStatus.UNVERIFIED)
    refused = api.post(
        "/api/v1/ai/questions/generate",
        json={"exam_code": "SSC_CHSL", "language": "en", "source_question_id": str(unverified.id)},
    )
    assert refused.status_code == 422
    assert refused.json()["error"]["code"] == "not_eligible"

    both = api.post(
        "/api/v1/ai/questions/generate",
        json={
            "exam_code": "SSC_CHSL",
            "language": "en",
            "source_question_id": str(unverified.id),
            "concept": {"title": "x", "subject": "s", "topic": "t"},
        },
    )
    assert both.status_code == 422
    too_many = api.post(
        "/api/v1/ai/questions/generate",
        json={
            "exam_code": "SSC_CHSL",
            "language": "en",
            "count": 6,
            "source_question_id": str(unverified.id),
        },
    )
    assert too_many.status_code == 422


def test_generation_from_a_learners_concept_in_hindi(
    api: TestClient, ai: FakeAIProvider, db_session: Session
) -> None:
    ai.responses.append(generated(1, prefix="150 का 20% कितना है"))

    unknown = api.post(
        "/api/v1/ai/questions/generate",
        json={
            "exam_code": "NOPE",
            "language": "hi",
            "concept": {
                "title": "प्रतिशत",
                "subject": "Quantitative Aptitude",
                "topic": "Percentage",
            },
        },
    )
    assert unknown.status_code == 422
    assert unknown.json()["error"]["code"] == "invalid_reference"

    result = api.post(
        "/api/v1/ai/questions/generate",
        json={
            "exam_code": "SSC_CGL",
            "language": "hi",
            "count": 1,
            "concept": {
                "title": "प्रतिशत",
                "notes": "x% of y = y% of x",
                "subject": "Quantitative Aptitude",
                "topic": "Percentage",
            },
        },
    ).json()

    [question] = result["created"]
    assert (question["language"], question["exam_code"]) == ("hi", "SSC_CGL")
    assert question["ai"]["source_note"] == "Concept: प्रतिशत"
    assert [i["code"] for i in question["issues"]] == ["ai_language_review"]
    prompt = ai.calls[0].prompt
    assert "x% of y = y% of x" in prompt and "Hindi" in prompt
    # The learner's notes are sent to the provider but not stored anywhere.
    stored = db_session.scalars(select(Question).where(Question.origin == "ai")).all()
    assert all("x% of y" not in (q.ai_source_note or "") for q in stored)
    assert all("x% of y" not in g.detail for g in generations(db_session))


def test_ai_questions_stay_out_of_practice_unless_chosen_and_out_of_mocks(
    api: TestClient, ai: FakeAIProvider, db_session: Session, document: Document
) -> None:
    source = make_question(db_session, document)
    ai.responses.append(generated(1))
    [created] = api.post(
        "/api/v1/ai/questions/generate",
        json={
            "exam_code": "SSC_CHSL",
            "language": "en",
            "count": 1,
            "source_question_id": str(source.id),
        },
    ).json()["created"]

    # Unverified AI question: only with both opt-ins, and labelled.
    default = api.post("/api/v1/practice/sessions", json={"count": 10}).json()
    assert [i["origin"] for i in default["items"]] == ["source"]
    both = api.post(
        "/api/v1/practice/sessions",
        json={"count": 10, "include_ai": True, "include_unverified": True},
    ).json()
    assert sorted(i["origin"] for i in both["items"]) == ["ai", "source"]
    ai_item = next(i for i in both["items"] if i["origin"] == "ai")
    assert ai_item["verified"] is False

    # After review it can be used with the AI opt-in alone, still labelled.
    approve = api.patch(
        f"/api/v1/questions/{created['id']}", json={"verification_status": "verified"}
    )
    assert approve.status_code == 200, approve.text
    reviewed = api.post("/api/v1/practice/sessions", json={"count": 10, "include_ai": True}).json()
    assert sorted(i["origin"] for i in reviewed["items"]) == ["ai", "source"]

    # Mock tests use source questions only.
    make_formats_ready(db_session, document)
    mock = api.post("/api/v1/practice/mock-tests", json={"exam_format_code": "SSC_CHSL_2026_TIER1"})
    assert mock.status_code == 201, mock.text
    assert {i["origin"] for i in mock.json()["items"]} == {"source"}


# --- topics and reports --------------------------------------------------------------------


def test_topic_suggestions_come_only_from_the_taxonomy(
    api: TestClient, ai: FakeAIProvider, db_session: Session, document: Document
) -> None:
    for name in ("AI Ratio", "AI Average"):
        db_session.add(Topic(subject="AI Subject", name=name, keywords=[]))
    db_session.flush()
    question = make_question(db_session, document, subject="AI Subject")
    other = make_question(db_session, document, subject="AI Subject")
    ai.responses += [{"topic": "ai average"}, {"topic": "Something invented"}]

    result = api.post(f"/api/v1/ai/questions/{question.id}/topic-suggestion").json()
    assert result["suggested"] is True
    read = result["question"]
    assert (read["topic"]["name"], read["topic_status"], read["topic_suggested_by"]) == (
        "AI Average",
        "suggested",
        "ai",
    )
    assert "- AI Ratio" in ai.calls[0].prompt

    invented = api.post(f"/api/v1/ai/questions/{other.id}/topic-suggestion").json()
    assert invented["suggested"] is False
    assert invented["question"]["topic"] is None

    again = api.post(f"/api/v1/ai/questions/{question.id}/topic-suggestion")
    assert again.status_code == 409
    assert again.json()["error"]["code"] == "topic_already_set"


def test_paper_topics_are_suggested_in_batches_from_the_taxonomy_only(
    api: TestClient, ai: FakeAIProvider, db_session: Session, document: Document
) -> None:
    unsectioned = make_question(db_session, document, status=VerificationStatus.UNVERIFIED)
    unsectioned.section = unsectioned.subject = None
    english = make_question(db_session, document, subject="English Language")
    invented = make_question(db_session, document, subject="English Language")
    rejected = make_question(db_session, document, status=VerificationStatus.REJECTED)
    db_session.flush()
    ai.responses.append(
        {
            "answers": [
                # Sent in section order (questions without a section last).
                # A topic of another subject than the question's section: dropped.
                {"number": 1, "topic": "Quantitative Aptitude > Percentage"},
                {"number": 2, "topic": "English Language > Invented Topic"},
                {"number": 3, "topic": "General Awareness > Polity"},
            ]
        }
    )

    response = api.post(f"/api/v1/ai/documents/{document.id}/topic-suggestions")

    assert response.status_code == 200, response.text
    assert response.json() == {"considered": 3, "suggested": 1, "no_match": 2, "remaining": 0}
    prompt = ai.calls[0].prompt
    assert "- English Language > Para Jumbles" in prompt
    assert "(subject: English Language)" in prompt
    assert rejected.stem not in prompt  # rejected questions are not sent
    read = api.get(f"/api/v1/questions/{unsectioned.id}").json()
    assert (read["topic"]["name"], read["topic_suggested_by"], read["subject"]) == (
        "Polity",
        "ai",
        "General Awareness",
    )
    assert read["topic_suggestion_reason"] == "AI suggestion (fake-model-1)"
    for question in (english, invented):
        assert api.get(f"/api/v1/questions/{question.id}").json()["topic"] is None

    # Questions the AI could not place are not sent again.
    again = api.post(f"/api/v1/ai/documents/{document.id}/topic-suggestions").json()
    assert again == {"considered": 0, "suggested": 0, "no_match": 0, "remaining": 0}
    assert len(ai.calls) == 1
    [generation] = db_session.scalars(select(AIGeneration)).all()
    assert (generation.task, generation.items_created, generation.items_rejected) == (
        "topic",
        1,
        2,
    )
    summary = api.get(f"/api/v1/documents/{document.id}/parse-summary").json()
    assert summary["topics_ai_pending"] == 0


def test_reporting_sends_a_question_back_to_review(
    api: TestClient, db_session: Session, document: Document
) -> None:
    question = make_question(db_session, document)

    response = api.post(
        f"/api/v1/questions/{question.id}/report",
        json={"reason": "wrong_answer", "note": "Answer should be 3"},
    )
    assert response.status_code == 200, response.text
    read = response.json()
    assert read["verification_status"] == "unverified"
    assert [(i["code"], i["detail"]) for i in read["issues"]] == [
        ("learner_report", "wrong_answer: Answer should be 3")
    ]
    empty = api.post("/api/v1/practice/sessions", json={"count": 1})
    assert empty.status_code == 422  # no verified question left

    reverified = api.patch(
        f"/api/v1/questions/{question.id}", json={"verification_status": "verified"}
    )
    assert reverified.json()["open_issue_count"] == 0


def test_ai_calls_are_rate_limited(
    make_api: AppFactory, db_session: Session, document: Document
) -> None:
    provider = FakeAIProvider(responses=[{"topic": None}, {"topic": None}])
    client = make_api(provider, ai_rate_limit=2)
    question = make_question(db_session, document, subject="Nothing")
    db_session.add(Topic(subject="Nothing", name="Only", keywords=[]))
    db_session.flush()

    for _ in range(2):
        assert (
            client.post(f"/api/v1/ai/questions/{question.id}/topic-suggestion").status_code == 200
        )
    limited = client.post(f"/api/v1/ai/questions/{question.id}/topic-suggestion")

    assert limited.status_code == 429
    assert limited.json()["error"]["code"] == "rate_limited"
    assert int(limited.headers["Retry-After"]) >= 1
    assert len(provider.calls) == 2


def test_ai_works_only_on_the_learners_own_questions(
    api: TestClient, ai: FakeAIProvider, db_session: Session, document: Document
) -> None:
    question = make_question(db_session, document, explanation=None)
    other = auth_headers(make_user(db_session, "other@example.com"))

    for response in (
        api.post(f"/api/v1/ai/questions/{question.id}/explanation", headers=other),
        api.post(f"/api/v1/ai/questions/{question.id}/topic-suggestion", headers=other),
        api.post(
            "/api/v1/ai/questions/generate",
            json={
                "exam_code": "SSC_CHSL",
                "language": "en",
                "source_question_id": str(question.id),
            },
            headers=other,
        ),
    ):
        assert response.status_code == 404
    assert ai.calls == []  # nothing was sent to the provider


def test_quick_answer_for_a_search_is_returned_and_logged_without_text(
    api: TestClient, ai: FakeAIProvider, db_session: Session
) -> None:
    ai.responses = [
        {"answer": "  Optional binding unwraps a value with if let.  ", "confident": True}
    ]
    response = api.post(
        "/api/v1/ai/quick-answer",
        json={"text": "swift optional binding", "exam_code": "SSC_CHSL"},
    )

    assert response.status_code == 200, response.text
    body = response.json()
    assert body["answer"] == "Optional binding unwraps a value with if let."
    assert body["confident"] is True
    assert (body["model"], body["prompt_version"]) == ("fake-model-1", "p9.5")
    call = ai.calls[0]
    assert "swift optional binding" in call.prompt
    assert "Combined Higher Secondary" in call.prompt and "English" in call.prompt
    assert "job interviews" in call.system
    log = db_session.scalars(select(AIGeneration).where(AIGeneration.task == "quick_answer")).one()
    assert (log.outcome, log.detail) == ("ok", "")  # the search text is not stored


def test_quick_answer_in_hindi_without_exam_and_its_failures(
    make_api: AppFactory, ai: FakeAIProvider
) -> None:
    api = make_api(ai)
    ai.responses = [
        {"answer": "उत्तर", "confident": False},
        {"answer": "   ", "confident": True},
    ]
    hindi = api.post("/api/v1/ai/quick-answer", json={"text": "प्रतिशत क्या है"})
    assert hindi.status_code == 200
    assert hindi.json()["confident"] is False
    assert "Hindi" in ai.calls[0].prompt and "preparing for an exam" in ai.calls[0].prompt

    assert api.post("/api/v1/ai/quick-answer", json={"text": "blank answer"}).status_code == 502
    unknown = api.post("/api/v1/ai/quick-answer", json={"text": "swift", "exam_code": "NOPE"})
    assert unknown.status_code == 422
    assert api.post("/api/v1/ai/quick-answer", json={"text": "x"}).status_code == 422
    off = make_api(None).post("/api/v1/ai/quick-answer", json={"text": "swift"})
    assert off.status_code == 503
