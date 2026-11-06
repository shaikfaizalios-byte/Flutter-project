"""The any-exam brief's acceptance chain, through the API: a learner's own exam, with no SSC wording
anywhere, from syllabus to paper to review to counts to practice."""

import re
from typing import Any

from fastapi.testclient import TestClient
from sqlalchemy import func, select
from sqlalchemy.orm import Session

from app.core.config import Settings
from app.integrations.ai import WebSearchHit
from app.integrations.storage import LocalDocumentStorage
from app.models.question import Question
from app.services.processing_service import DocumentProcessor
from tests.fakes import FakeAIProvider, FakeOcrEngine
from tests.pdf_factory import text_pdf
from tests.test_ai import AppFactory, ai, make_api
from tests.test_descriptive import marked, written
from tests.test_ladder import fresh_question, solved

__all__ = ["ai", "make_api"]  # fixtures re-used from other test modules

NOT_THIS_EXAM = re.compile(r"\b(SSC|CGL|CHSL|Tier)\b")
STAGE = {
    "name": "Written test",
    "duration_minutes": 100,
    "sections": [{"name": "Forestry", "question_count": 50}],
    "marking_scheme": {"marks_correct": 2, "marks_wrong": 0.5, "marks_unanswered": 0},
}
PAPER = [
    "Forestry",
    "Q.1 Which tree sheds its leaves in winter?",
    "(1) Pine (2) Oak (3) Fir (4) Spruce (5) Cedar",
    "Q.2 Which soil holds the most water?",
    "(1) Sand (2) Silt (3) Clay (4) Gravel (5) Chalk",
]


def own_exam(api: TestClient, **body: Any) -> str:
    response = api.post("/api/v1/me/exams", json={"name": "State Forest Exam", **body})
    assert response.status_code == 201, response.text
    code: str = response.json()["code"]
    return code


def own_topic(api: TestClient, code: str) -> str:
    response = api.post(
        "/api/v1/topics/bulk",
        json={
            "exam_code": code,
            "topics": [{"exam_code": code, "subject": "Forestry", "name": "Trees"}],
        },
    )
    assert response.status_code == 201, response.text
    topic: str = response.json()[0]["id"]
    return topic


def test_a_five_option_exam_of_their_own_works_from_syllabus_to_ladder(
    make_api: AppFactory,
    ai: FakeAIProvider,
    db_session: Session,
    storage: LocalDocumentStorage,
    settings: Settings,
) -> None:
    api = make_api(ai)
    code = own_exam(api, options_per_question=5, stages=[STAGE])
    topic = own_topic(api, code)

    uploaded = api.post(
        "/api/v1/documents",
        files={"file": ("forest-2025.pdf", text_pdf([PAPER]), "application/pdf")},
        data={"exam_code": code, "language": "en"},
    )
    assert uploaded.status_code == 201, uploaded.text
    processor = DocumentProcessor(storage=storage, ocr=FakeOcrEngine(), settings=settings)
    document = processor.claim_next(db_session)
    assert document is not None
    processor.process(db_session, document)

    listed = api.get("/api/v1/questions", params={"limit": 100, "document_id": str(document)})
    items = listed.json()["items"]
    assert len(items) == 2
    assert all(len(q["options"]) == 5 for q in items)
    assert not any(i["code"] == "option_count" for q in items for i in q.get("issues", []))
    for item in items:
        reviewed = api.patch(
            f"/api/v1/questions/{item['id']}",
            json={
                "topic_id": topic,
                "correct_option_position": 2,
                "verification_status": "verified",
            },
        )
        assert reviewed.status_code == 200, reviewed.text

    def counted() -> Any:
        report = api.get("/api/v1/insights/repeats", params={"exam": code}).json()
        return next(t for t in report["topics"] if t["topic_id"] == topic)["confirmed"]

    before = counted()
    assert (before["papers"], before["questions"]) == (1, 2)
    questions = db_session.scalar(select(func.count()).select_from(Question))

    ai.web_hits = [WebSearchHit("Guide", "https://example.com/g", "Tree basics")]
    ai.responses += [
        fresh_question(options=["7", "8", "9", "10", "11"], answer_index=1),
        solved(),
    ]
    started = api.post(
        "/api/v1/ladder/sessions",
        json={"exam_code": code, "topic_id": topic, "include_new_formats": True},
    )
    assert started.status_code == 201, started.text
    url = f"/api/v1/ladder/sessions/{started.json()['session_id']}/rounds/1/steps/1"
    step = api.post(f"{url}/generate").json()
    assert len(step["options"]) == 5
    answered = api.post(f"{url}/answer", json={"selected_index": 0}).json()["result"]
    assert answered["marks_possible"] == 2

    assert NOT_THIS_EXAM.search(" ".join(c.prompt + c.system for c in ai.calls)) is None
    assert NOT_THIS_EXAM.search(" ".join(ai.searches)) is None
    # Generated questions never reach the counts.
    assert counted() == before
    assert db_session.scalar(select(func.count()).select_from(Question)) == questions


def test_a_descriptive_exam_of_their_own_works_from_syllabus_to_estimated_marks(
    make_api: AppFactory, ai: FakeAIProvider
) -> None:
    api = make_api(ai)
    stage = STAGE | {"marking_scheme": {"marks_correct": 20, "marks_wrong": 0}}
    code = own_exam(api, kind="descriptive", stages=[stage])
    topic = own_topic(api, code)
    assert api.get("/api/v1/ladder/overview", params={"exam": code}).json()["available"] is False

    started = api.post("/api/v1/descriptive/sessions", json={"exam_code": code, "topic_id": topic})
    assert started.status_code == 201, started.text
    body = started.json()
    assert [s["marks"] for s in body["steps"]] == [4, 8, 12, 16, 20]

    ai.responses += [written(4), marked(3, 1), marked(2, 1), marked(2, 1)]
    url = f"/api/v1/descriptive/sessions/{body['session_id']}/steps/1"
    assert api.post(f"{url}/generate").status_code == 200
    result = api.post(f"{url}/answer", json={"text": "My answer"}).json()["result"]
    assert (result["marks"], result["marks_possible"]) == (3, 4)
    assert NOT_THIS_EXAM.search(" ".join(c.prompt + c.system for c in ai.calls)) is None
