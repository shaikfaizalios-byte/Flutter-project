"""End to end: upload a synthetic paper → worker extracts + segments → review via the API."""

import uuid
from typing import Any

import pytest
from fastapi.testclient import TestClient
from sqlalchemy.orm import Session

from app.core.config import Settings
from app.integrations.storage import LocalDocumentStorage
from app.models.document import Document, DocumentStatus
from app.services.processing_service import DocumentProcessor
from tests.fakes import FakeOcrEngine
from tests.pdf_factory import text_pdf

PAPER_PAGE_1 = [
    "General Intelligence",
    "Q.1 Select the figure that completes the pattern.",
    "(1) A (2) B (3) C (4) D",
    "Q.2 If CAT is coded as DBU, how is DOG coded?",
    "(1) EPH (2) EOH (3) DPH (4) FPH",
    "Quantitative Aptitude",
    "Directions (Questions 3 to 4): A shop sells pens at Rs 10 each.",
    "Q.3 What is 20 percent of 150?",
    "(a) 20 (b) 30 (c) 40 (d) 50",
]
PAPER_PAGE_2 = [
    "Q.4 How many pens can be bought for Rs 50?",
    "(1) 4 (2) 5 (3) 6",
    "Answer Key",
    "1-(2) 2-(1) 3-(b)",
]
QUESTIONS = "/api/v1/questions"
DOCUMENTS = "/api/v1/documents"


def upload_paper(client: TestClient, **form: str) -> uuid.UUID:
    response = client.post(
        DOCUMENTS,
        files={
            "file": ("chsl-sample.pdf", text_pdf([PAPER_PAGE_1, PAPER_PAGE_2]), "application/pdf")
        },
        data={"exam_code": "SSC_CHSL", "language": "en", **form},
    )
    assert response.status_code == 201, response.text
    return uuid.UUID(response.json()["id"])


@pytest.fixture
def paper(
    db_client: TestClient, db_session: Session, storage: LocalDocumentStorage, settings: Settings
) -> uuid.UUID:
    document_id = upload_paper(db_client, exam_format_code="SSC_CHSL_2026_TIER1")
    processor = DocumentProcessor(storage=storage, ocr=FakeOcrEngine(), settings=settings)
    assert processor.claim_next(db_session) == document_id
    processor.process(db_session, document_id)
    return document_id


def questions(client: TestClient, **params: Any) -> list[dict[str, Any]]:
    response = client.get(QUESTIONS, params={"limit": 100, **params})
    assert response.status_code == 200, response.text
    items: list[dict[str, Any]] = response.json()["items"]
    return items


def by_number(client: TestClient, document_id: uuid.UUID, number: int) -> dict[str, Any]:
    return next(
        q
        for q in questions(client, document_id=str(document_id))
        if q["source_question_number"] == number
    )


def test_exam_formats_are_listed_with_their_official_source(db_client: TestClient) -> None:
    [chsl] = db_client.get("/api/v1/exam-formats", params={"exam": "SSC_CHSL"}).json()

    assert chsl["code"] == "SSC_CHSL_2026_TIER1"
    assert chsl["total_questions"] == 100
    assert chsl["sections_in_fixed_order"] is False
    assert chsl["negative_marks_per_wrong"] == 0.5
    assert chsl["source_url"].startswith("https://ssc.gov.in/")
    assert "13.8" in chsl["source_reference"]
    # SSC CGL 2026 Tier-I: verified against its official notice, with the sectional timer
    # recorded per section.
    (cgl,) = db_client.get("/api/v1/exam-formats", params={"exam": "SSC_CGL"}).json()
    assert cgl["code"] == "SSC_CGL_2026_TIER1"
    assert cgl["total_questions"] == 100
    assert cgl["duration_minutes"] == 60
    assert cgl["negative_marks_per_wrong"] == 0.5
    assert [s["questions"] for s in cgl["sections"]] == [25, 25, 25, 25]
    assert {s["timer_minutes"] for s in cgl["sections"]} == {15}
    assert "HQ-C11018/1/2026-C-1" in cgl["source_reference"]


def test_paper_is_segmented_after_extraction(db_client: TestClient, paper: uuid.UUID) -> None:
    document = db_client.get(f"{DOCUMENTS}/{paper}").json()
    assert document["status"] == "completed"
    assert document["segmentation_status"] == "completed"
    assert document["questions_found"] == 4

    summary = db_client.get(f"{DOCUMENTS}/{paper}/parse-summary").json()
    assert summary["sections"] == ["General Intelligence", "Quantitative Aptitude"]
    assert summary["exam_format"]["code"] == "SSC_CHSL_2026_TIER1"
    assert summary["missing_answers"] == 1  # Q.4 is not in the key
    assert summary["image_dependent"] == 1  # Q.1 refers to a figure
    assert summary["verified"] == 0
    doc_issue_codes = {i["code"] for i in summary["document_issues"]}
    # 4 questions found vs 100 in the verified format → reported, nothing invented.
    assert "count_mismatch" in doc_issue_codes


def test_question_provenance_options_answer_passage_and_topic(
    db_client: TestClient, paper: uuid.UUID
) -> None:
    q3 = by_number(db_client, paper, 3)

    assert q3["origin"] == "source"
    assert q3["document_filename"] == "chsl-sample.pdf"
    assert q3["source_pages"] == [1]
    assert q3["section"] == "Quantitative Aptitude"
    assert q3["subject"] == "Quantitative Aptitude"
    assert q3["stem"] == "What is 20 percent of 150?"
    assert [(o["label"], o["text"]) for o in q3["options"]] == [
        ("a", "20"),
        ("b", "30"),
        ("c", "40"),
        ("d", "50"),
    ]
    assert (q3["correct_option_position"], q3["answer_source"]) == (2, "answer_key")
    assert q3["passage"]["first_question"] == 3
    assert "pens at Rs 10" in q3["passage"]["text"]
    # Keyword match → a *suggestion*, never a confirmed topic.
    assert q3["topic"]["name"] == "Percentage"
    assert q3["topic_status"] == "suggested"
    assert q3["verification_status"] == "unverified"

    q4 = by_number(db_client, paper, 4)
    assert q4["source_pages"] == [2]
    assert q4["passage"]["id"] == q3["passage"]["id"]
    assert {i["code"] for i in q4["issues"]} >= {"missing_answer", "incomplete_options"}


def test_filters_and_search(db_client: TestClient, paper: uuid.UUID) -> None:
    assert len(questions(db_client, document_id=str(paper))) == 4
    assert [q["source_question_number"] for q in questions(db_client, q="coded")] == [2]
    assert {
        q["source_question_number"] for q in questions(db_client, section="General Intelligence")
    } == {1, 2}
    assert [q["source_question_number"] for q in questions(db_client, image_dependent=True)] == [1]
    with_issues = {q["source_question_number"] for q in questions(db_client, has_issues=True)}
    assert {1, 4} <= with_issues
    assert 2 not in with_issues
    assert questions(db_client, status="verified") == []
    assert questions(db_client, q="%") == []  # LIKE wildcards are literal


def test_fixing_and_verifying_a_question(db_client: TestClient, paper: uuid.UUID) -> None:
    q4 = by_number(db_client, paper, 4)
    url = f"{QUESTIONS}/{q4['id']}"

    blocked = db_client.patch(url, json={"verification_status": "verified"})
    assert blocked.status_code == 422
    assert blocked.json()["error"]["code"] == "cannot_verify"

    fixed = db_client.patch(
        url,
        json={
            "options": [
                {"label": "1", "text": "4"},
                {"label": "2", "text": "5"},
                {"label": "3", "text": "6"},
                {"label": "4", "text": "7"},
            ],
            "correct_option_position": 2,
        },
    ).json()
    open_codes = {i["code"] for i in fixed["issues"] if not i["resolved"]}
    assert "missing_answer" not in open_codes
    assert "incomplete_options" not in open_codes
    assert fixed["answer_source"] == "manual"

    verified = db_client.patch(url, json={"verification_status": "verified"}).json()
    assert verified["verification_status"] == "verified"
    assert verified["verified_at"] is not None
    assert verified["open_issue_count"] == 0

    # Editing a verified question sends it back for review.
    edited = db_client.patch(url, json={"stem": "How many pens for Rs 50?"}).json()
    assert edited["verification_status"] == "unverified"


def test_topic_assignment_and_rejection(db_client: TestClient, paper: uuid.UUID) -> None:
    q2 = by_number(db_client, paper, 2)
    topics = db_client.get("/api/v1/topics", params={"subject": "General Intelligence"}).json()
    coding = next(t for t in topics if t["name"] == "Coding-Decoding")

    assigned = db_client.patch(f"{QUESTIONS}/{q2['id']}", json={"topic_id": coding["id"]}).json()
    assert (assigned["topic"]["name"], assigned["topic_status"]) == ("Coding-Decoding", "confirmed")

    bad = db_client.patch(f"{QUESTIONS}/{q2['id']}", json={"topic_id": str(uuid.uuid4())})
    assert bad.status_code == 422
    assert bad.json()["error"]["code"] == "invalid_reference"

    rejected = db_client.patch(
        f"{QUESTIONS}/{q2['id']}", json={"verification_status": "rejected"}
    ).json()
    assert rejected["verification_status"] == "rejected"


def test_resegmenting_keeps_reviewed_questions(db_client: TestClient, paper: uuid.UUID) -> None:
    q1 = by_number(db_client, paper, 1)
    q3 = by_number(db_client, paper, 3)
    db_client.patch(
        f"{QUESTIONS}/{q3['id']}",
        json={"stem": "Reviewed: what is 20% of 150?", "verification_status": "verified"},
    )
    db_client.patch(f"{QUESTIONS}/{q1['id']}", json={"verification_status": "rejected"})

    summary = db_client.post(f"{DOCUMENTS}/{paper}/segment").json()

    assert summary["questions_found"] == 4
    assert summary["verified"] == 1
    assert summary["rejected"] == 1
    kept = db_client.get(f"{QUESTIONS}/{q3['id']}").json()
    assert kept["stem"] == "Reviewed: what is 20% of 150?"
    assert kept["verification_status"] == "verified"
    assert db_client.get(f"{QUESTIONS}/{q1['id']}").json()["verification_status"] == "rejected"
    numbers = sorted(
        q["source_question_number"] for q in questions(db_client, document_id=str(paper))
    )
    assert numbers == [1, 2, 3, 4]  # no duplicates of reviewed questions


def test_setting_the_format_and_validation(db_client: TestClient, paper: uuid.UUID) -> None:
    url = f"{DOCUMENTS}/{paper}/exam-format"
    cleared = db_client.put(url, json={"exam_format_code": None})
    assert cleared.status_code == 200
    assert cleared.json()["exam_format_id"] is None
    summary = db_client.post(f"{DOCUMENTS}/{paper}/segment").json()
    assert "count_mismatch" not in {i["code"] for i in summary["document_issues"]}

    unknown = db_client.put(url, json={"exam_format_code": "NOPE"})
    assert unknown.status_code == 422


def test_format_must_belong_to_the_documents_exam(db_client: TestClient) -> None:
    response = db_client.post(
        DOCUMENTS,
        files={"file": ("x.pdf", text_pdf(), "application/pdf")},
        data={"exam_code": "SSC_CGL", "language": "en", "exam_format_code": "SSC_CHSL_2026_TIER1"},
    )

    assert response.status_code == 422
    assert response.json()["error"]["code"] == "invalid_reference"


def test_segmenting_before_extraction_is_rejected(db_client: TestClient) -> None:
    document_id = upload_paper(db_client)

    response = db_client.post(f"{DOCUMENTS}/{document_id}/segment")

    assert response.status_code == 409
    assert response.json()["error"]["code"] == "document_not_ready"


def test_deleting_a_document_removes_its_questions(db_client: TestClient, paper: uuid.UUID) -> None:
    q1 = by_number(db_client, paper, 1)

    assert db_client.delete(f"{DOCUMENTS}/{paper}").status_code == 204

    assert db_client.get(f"{QUESTIONS}/{q1['id']}").status_code == 404
    assert questions(db_client, document_id=str(paper)) == []


def test_segmentation_failure_does_not_fail_the_document(
    db_client: TestClient,
    db_session: Session,
    storage: LocalDocumentStorage,
    settings: Settings,
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    from app.services import segmentation_service

    def boom(*_: object, **__: object) -> None:
        raise RuntimeError("parser bug")

    monkeypatch.setattr(segmentation_service, "segment", boom)
    document_id = upload_paper(db_client)
    processor = DocumentProcessor(storage=storage, ocr=FakeOcrEngine(), settings=settings)
    processor.claim_next(db_session)
    processor.process(db_session, document_id)

    document = db_session.get(Document, document_id)
    assert document is not None
    assert document.status == DocumentStatus.COMPLETED
    assert document.segmentation_status == "failed"


def test_question_404_and_validation(db_client: TestClient) -> None:
    assert db_client.get(f"{QUESTIONS}/{uuid.uuid4()}").status_code == 404
    assert db_client.patch(f"{QUESTIONS}/{uuid.uuid4()}", json={"stem": "x"}).status_code == 404
    assert db_client.get(QUESTIONS, params={"limit": 0}).status_code == 422
