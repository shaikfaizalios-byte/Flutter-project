"""Any exam: the catalog, learners' own (private) exams, and their own topics and types."""

import uuid
from typing import Any

from fastapi.testclient import TestClient
from sqlalchemy.orm import Session

from app.domain.segmentation import PageText, segment
from app.models.document import Document, DocumentStatus
from app.models.question import Question, QuestionOption, QuestionOrigin, TopicStatus
from app.models.user import User
from tests.conftest import auth_headers, make_user


def _create_exam(client: TestClient, name: str = "Rajasthan Patwari") -> dict[str, Any]:
    response = client.post("/api/v1/me/exams", json={"name": name})
    assert response.status_code == 201, response.text
    data: dict[str, Any] = response.json()
    return data


def _topic(client: TestClient, exam: str, subject: str, name: str, **extra: Any) -> dict[str, Any]:
    response = client.post(
        "/api/v1/topics", json={"exam_code": exam, "subject": subject, "name": name, **extra}
    )
    assert response.status_code == 201, response.text
    data: dict[str, Any] = response.json()
    return data


def test_own_exams_are_private_and_listed_after_the_catalog(
    db_client: TestClient, db_session: Session
) -> None:
    exam = _create_exam(db_client)
    assert exam["code"].startswith("MY_") and exam["custom"] is True

    mine = db_client.get("/api/v1/me/exams").json()
    assert mine[0]["code"] == "SSC_CGL" and mine[-1]["code"] == exam["code"]
    assert exam["code"] not in [e["code"] for e in db_client.get("/api/v1/exams").json()]

    other = make_user(db_session, "other@example.com")
    theirs = db_client.get("/api/v1/me/exams", headers=auth_headers(other)).json()
    assert exam["code"] not in [e["code"] for e in theirs]
    # Another learner can't use, rename or list topics of it.
    assert (
        db_client.get(
            f"/api/v1/exams/{exam['code']}/topics", headers=auth_headers(other)
        ).status_code
        == 422
    )
    assert (
        db_client.patch(
            f"/api/v1/me/exams/{exam['code']}", json={"name": "x"}, headers=auth_headers(other)
        ).status_code
        == 404
    )

    renamed = db_client.patch(f"/api/v1/me/exams/{exam['code']}", json={"name": "Patwari 2026"})
    assert renamed.json()["name"] == "Patwari 2026"


def test_an_exam_in_use_cannot_be_deleted(
    db_client: TestClient, db_session: Session, user: User
) -> None:
    exam = _create_exam(db_client)
    _topic(db_client, exam["code"], "Rajasthan GK", "Rivers")
    db_session.add(
        Document(
            owner_id=user.id,
            exam_code=exam["code"],
            language="en",
            original_filename="p.pdf",
            size_bytes=1,
            sha256="0" * 64,
            storage_key=f"documents/{uuid.uuid4().hex}.pdf",
            page_count=1,
            status=DocumentStatus.COMPLETED,
        )
    )
    db_session.flush()
    response = db_client.delete(f"/api/v1/me/exams/{exam['code']}")
    assert response.status_code == 409
    assert response.json()["error"]["code"] == "exam_in_use"

    unused = _create_exam(db_client, "Spare")
    _topic(db_client, unused["code"], "Maths", "Algebra")
    assert db_client.delete(f"/api/v1/me/exams/{unused['code']}").status_code == 204
    assert unused["code"] not in [e["code"] for e in db_client.get("/api/v1/me/exams").json()]


def test_topics_per_exam_shared_and_own(db_client: TestClient) -> None:
    # The shared aptitude taxonomy applies to SSC/banking/railways, not to NEET.
    chsl = db_client.get("/api/v1/exams/SSC_CHSL/topics").json()
    assert any(t["name"] == "Venn Diagrams" and t["own"] is False for t in chsl)
    assert db_client.get("/api/v1/exams/NEET_UG/topics").json() == []

    cell = _topic(db_client, "NEET_UG", "Biology", "Cell Biology", keywords=["cell", "Cell"])
    assert cell["keywords"] == ["cell"]  # de-duplicated
    no_keywords = _topic(db_client, "NEET_UG", "Physics", "Optics")
    assert no_keywords["keywords"] == ["Optics"]  # the name, so suggestions still work

    dup = db_client.post(
        "/api/v1/topics",
        json={"exam_code": "NEET_UG", "subject": "biology", "name": "cell biology"},
    )
    assert dup.status_code == 409

    neet = db_client.get("/api/v1/exams/NEET_UG/topics").json()
    assert [t["name"] for t in neet] == ["Cell Biology", "Optics"]
    # The question-bank topic list can be limited to one exam.
    listed = db_client.get("/api/v1/topics", params={"exam": "NEET_UG"}).json()
    assert {t["name"] for t in listed} == {"Cell Biology", "Optics"}

    bulk = db_client.post(
        "/api/v1/topics/bulk",
        json={
            "exam_code": "NEET_UG",
            "topics": [
                {"exam_code": "NEET_UG", "subject": "Chemistry", "name": "Mole Concept"},
                {"exam_code": "NEET_UG", "subject": "Chemistry", "name": "mole concept"},
                {"exam_code": "NEET_UG", "subject": "Biology", "name": "Cell Biology"},
            ],
        },
    )
    assert bulk.status_code == 201
    assert [t["name"] for t in bulk.json()] == ["Mole Concept"]  # duplicates skipped


def test_shared_topics_are_read_only(db_client: TestClient) -> None:
    venn = next(
        t
        for t in db_client.get("/api/v1/exams/SSC_CHSL/topics").json()
        if t["name"] == "Venn Diagrams"
    )
    assert db_client.patch(f"/api/v1/topics/{venn['id']}", json={"name": "x"}).status_code == 404
    assert db_client.delete(f"/api/v1/topics/{venn['id']}").status_code == 404


def _paper_question(db: Session, user: User, exam: str, topic_id: str | None) -> Question:
    doc = Document(
        owner_id=user.id,
        exam_code=exam,
        language="en",
        original_filename="p.pdf",
        size_bytes=1,
        sha256="0" * 64,
        storage_key=f"documents/{uuid.uuid4().hex}.pdf",
        page_count=1,
        status=DocumentStatus.COMPLETED,
    )
    db.add(doc)
    db.flush()
    q = Question(
        owner_id=user.id,
        origin=QuestionOrigin.SOURCE,
        exam_code=exam,
        subject="Biology" if topic_id else None,
        topic_id=uuid.UUID(topic_id) if topic_id else None,
        topic_status=TopicStatus.CONFIRMED if topic_id else TopicStatus.UNASSIGNED,
        stem="Which organelle is called the powerhouse of the cell?",
        language="en",
        document_id=doc.id,
        source_question_number=1,
        source_pages=[1],
        verification_status="unverified",
    )
    q.options = [QuestionOption(position=i, label=str(i), text=f"o{i}") for i in range(1, 5)]
    db.add(q)
    db.flush()
    return q


def test_topic_edits_reach_questions_and_deletion_unassigns(
    db_client: TestClient, db_session: Session, user: User
) -> None:
    cell = _topic(db_client, "NEET_UG", "Biology", "Cell Biology")
    q = _paper_question(db_session, user, "NEET_UG", cell["id"])

    pattern = db_client.post(
        "/api/v1/patterns", json={"topic_id": cell["id"], "name": "Organelle functions"}
    )
    assert pattern.status_code == 201
    db_client.patch(f"/api/v1/questions/{q.id}", json={"pattern_id": pattern.json()["id"]})

    db_client.patch(f"/api/v1/topics/{cell['id']}", json={"subject": "Botany"})
    assert db_client.get(f"/api/v1/questions/{q.id}").json()["subject"] == "Botany"

    assert db_client.delete(f"/api/v1/topics/{cell['id']}").status_code == 204
    body = db_client.get(f"/api/v1/questions/{q.id}").json()
    assert body["topic"] is None and body["topic_status"] == "unassigned"
    assert body["pattern"] is None and body["pattern_status"] == "unassigned"


def test_a_question_only_takes_topics_of_its_exam(
    db_client: TestClient, db_session: Session, user: User
) -> None:
    cell = _topic(db_client, "NEET_UG", "Biology", "Cell Biology")
    chsl_q = _paper_question(db_session, user, "SSC_CHSL", None)
    response = db_client.patch(f"/api/v1/questions/{chsl_q.id}", json={"topic_id": cell["id"]})
    assert response.status_code == 422


def test_someone_elses_own_topic_and_exam_are_invisible(
    db_client: TestClient, db_session: Session
) -> None:
    exam = _create_exam(db_client)
    topic = _topic(db_client, exam["code"], "GK", "Forts")
    other = make_user(db_session, "other@example.com")
    headers = auth_headers(other)
    assert (
        db_client.patch(
            f"/api/v1/topics/{topic['id']}", json={"name": "x"}, headers=headers
        ).status_code
        == 404
    )
    listed = db_client.get("/api/v1/topics", headers=headers).json()
    assert topic["id"] not in [t["id"] for t in listed]
    upload = db_client.post(
        "/api/v1/documents",
        files={"file": ("p.pdf", b"%PDF-1.4", "application/pdf")},
        data={"exam_code": exam["code"], "language": "en"},
        headers=headers,
    )
    assert upload.status_code == 422


def test_an_exams_own_subjects_are_recognised_as_section_headings() -> None:
    text = (
        "Biology\nQ.1 Which organelle makes ATP?\n"
        "(1) Nucleus (2) Mitochondria (3) Ribosome (4) Golgi"
    )
    plain = segment([PageText(1, text)])
    assert plain.questions[0].section is None
    with_exam = segment([PageText(1, text)], extra_headings=["Biology", "Physics"])
    assert with_exam.questions[0].section == "Biology"
