"""Syllabus import (subjects and topics read from a PDF, nothing saved) and topics marked as
revised."""

from typing import Any

from fastapi.testclient import TestClient
from sqlalchemy.orm import Session

from app.domain.syllabus import GENERAL, MAX_TOPICS, parse_syllabus
from tests.conftest import auth_headers, make_user
from tests.pdf_factory import text_pdf

SYLLABUS = """Sample Exam Syllabus 2026
Exam Pattern: 120 minutes, 66 questions
VERBAL ABILITY AND READING COMPREHENSION
• Reading Comprehension
• Para Jumbles; Para Summary; Odd Sentence Out
Data Interpretation and Logical Reasoning:
Tables, Bar Graphs, Pie Charts, Caselets
1. Seating Arrangement
2. Blood Relations
Section 3 - Quantitative Ability
Number System
Profit and Loss
Time, Speed and Distance
Note: Calculators are allowed on screen.
"""


def topics_of(pages: list[str], **kwargs: Any) -> dict[str, list[str]]:
    return {s.name: s.topics for s in parse_syllabus(pages, **kwargs).subjects}


def test_headings_bullets_numbers_lists_and_lines_are_read() -> None:
    found = topics_of([SYLLABUS])
    assert found == {
        "Verbal Ability and Reading Comprehension": [
            "Reading Comprehension",
            "Para Jumbles",
            "Para Summary",
            "Odd Sentence Out",
        ],
        "Data Interpretation and Logical Reasoning": [
            "Tables",
            "Bar Graphs",
            "Pie Charts",
            "Caselets",
            "Seating Arrangement",
            "Blood Relations",
        ],
        # "Section 3 - ..." is a heading; "Time, Speed and Distance" stays one topic.
        "Quantitative Ability": ["Number System", "Profit and Loss", "Time, Speed and Distance"],
    }


def test_subject_lines_known_subjects_duplicates_and_noise() -> None:
    found = topics_of(
        [
            "English: Synonyms, Antonyms, Idioms\n"
            "Static GK\n"
            "Rivers of India\n"
            "Rivers of India\n"
            "Total marks 200\n"
            "Visit www.example.org for details\n"
        ],
        known_subjects=["Static GK"],
    )
    assert found == {
        "English": ["Synonyms", "Antonyms", "Idioms"],
        "Static GK": ["Rivers of India"],
    }
    # Topics before any heading go under "General".
    assert topics_of(["• Percentage\n• Averages"]) == {GENERAL: ["Percentage", "Averages"]}


def test_a_long_syllabus_is_capped() -> None:
    lines = "\n".join(f"• Topic number {i} alpha" for i in range(MAX_TOPICS + 20))
    draft = parse_syllabus(["Mathematics:\n" + lines])
    assert draft.topic_count == MAX_TOPICS and draft.truncated


def test_syllabus_pdf_gives_a_draft_and_saves_nothing(db_client: TestClient) -> None:
    pdf = text_pdf([SYLLABUS.splitlines()])
    response = db_client.post(
        "/api/v1/exams/SSC_CGL/syllabus",
        files={"file": ("syllabus.pdf", pdf, "application/pdf")},
        data={"language": "en"},
    )
    assert response.status_code == 200, response.text
    draft = response.json()
    assert draft["read_by"] == "text" and draft["pages"] == 1
    assert draft["topic_count"] == 13
    names = {s["name"] for s in draft["subjects"]}
    assert "Quantitative Ability" in names
    # Nothing was saved: the learner keeps what they want with /topics/bulk.
    mine = [t for t in db_client.get("/api/v1/exams/SSC_CGL/topics").json() if t["own"]]
    assert mine == []

    not_pdf = db_client.post(
        "/api/v1/exams/SSC_CGL/syllabus",
        files={"file": ("notes.txt", b"hello", "text/plain")},
    )
    assert not_pdf.status_code == 415
    unknown = db_client.post(
        "/api/v1/exams/NOPE/syllabus",
        files={"file": ("syllabus.pdf", pdf, "application/pdf")},
    )
    assert unknown.status_code == 422


def test_topics_are_marked_revised_per_learner(db_client: TestClient, db_session: Session) -> None:
    created = db_client.post(
        "/api/v1/topics/bulk",
        json={
            "exam_code": "SSC_CGL",
            "topics": [
                {"exam_code": "SSC_CGL", "subject": "Syllabus Maths", "name": "Mixtures"},
                {"exam_code": "SSC_CGL", "subject": "Syllabus Maths", "name": "Surds"},
            ],
        },
    ).json()
    mixtures = next(t for t in created if t["name"] == "Mixtures")
    assert mixtures["completed"] is False

    marked = db_client.put(f"/api/v1/topics/{mixtures['id']}/completion", json={"completed": True})
    assert marked.status_code == 200 and marked.json()["completed"] is True
    listed = {t["name"]: t for t in db_client.get("/api/v1/exams/SSC_CGL/topics").json()}
    assert listed["Mixtures"]["completed"] is True
    assert listed["Surds"]["completed"] is False

    # Shared topics can be marked too; the mark is the learner's own.
    shared = next(t for t in listed.values() if not t["own"])
    assert db_client.put(
        f"/api/v1/topics/{shared['id']}/completion", json={"completed": True}
    ).json()["completed"]
    other = make_user(db_session, "other@example.com")
    theirs = db_client.get("/api/v1/exams/SSC_CGL/topics", headers=auth_headers(other)).json()
    assert not any(t["completed"] for t in theirs)
    # Someone else's own topic can't be marked.
    assert (
        db_client.put(
            f"/api/v1/topics/{mixtures['id']}/completion",
            json={"completed": True},
            headers=auth_headers(other),
        ).status_code
        == 404
    )

    unmarked = db_client.put(
        f"/api/v1/topics/{mixtures['id']}/completion", json={"completed": False}
    )
    assert unmarked.json()["completed"] is False


def test_a_typed_syllabus_gives_a_draft(db_client: TestClient) -> None:
    response = db_client.post(
        "/api/v1/exams/SSC_CGL/syllabus/text",
        json={"text": "Reasoning: Analogy, Coding-Decoding\nMathematics\n- Percentage\n- Ratio"},
    )
    assert response.status_code == 200, response.text
    draft = response.json()
    assert draft["read_by"] == "typed" and draft["pages"] == 0
    assert {s["name"]: s["topics"] for s in draft["subjects"]} == {
        "Reasoning": ["Analogy", "Coding-Decoding"],
        "Mathematics": ["Percentage", "Ratio"],
    }
    empty = db_client.post("/api/v1/exams/SSC_CGL/syllabus/text", json={"text": " "})
    assert empty.status_code == 422


def test_several_own_topics_are_removed_at_once(db_client: TestClient, db_session: Session) -> None:
    created = db_client.post(
        "/api/v1/topics/bulk",
        json={
            "exam_code": "SSC_CGL",
            "topics": [
                {"exam_code": "SSC_CGL", "subject": "Removal", "name": name}
                for name in ("Alpha", "Beta", "Gamma")
            ],
        },
    ).json()
    ids = [t["id"] for t in created]
    shared = next(t for t in db_client.get("/api/v1/exams/SSC_CGL/topics").json() if not t["own"])

    # Shared topics in the list are skipped; another learner can't remove these.
    other = make_user(db_session, "other@example.com")
    theirs = db_client.post(
        "/api/v1/topics/bulk-delete", json={"topic_ids": ids}, headers=auth_headers(other)
    )
    assert theirs.json() == {"deleted": 0}

    removed = db_client.post(
        "/api/v1/topics/bulk-delete", json={"topic_ids": [*ids[:2], shared["id"]]}
    )
    assert removed.json() == {"deleted": 2}
    left = {t["name"] for t in db_client.get("/api/v1/exams/SSC_CGL/topics").json() if t["own"]}
    assert left == {"Gamma"}
    assert any(
        t["id"] == shared["id"] for t in db_client.get("/api/v1/exams/SSC_CGL/topics").json()
    )


def test_a_syllabus_import_groups_its_topics_and_removes_them_together(
    db_client: TestClient, db_session: Session
) -> None:
    def save(names: list[str], source: dict[str, str] | None) -> list[dict[str, Any]]:
        body: dict[str, Any] = {
            "exam_code": "SSC_CGL",
            "topics": [{"exam_code": "SSC_CGL", "subject": "Imported", "name": n} for n in names],
        }
        if source:
            body["source"] = source
        response = db_client.post("/api/v1/topics/bulk", json=body)
        assert response.status_code == 201, response.text
        result: list[dict[str, Any]] = response.json()
        return result

    pdf = save(["Algebra", "Geometry"], {"name": "cgl-syllabus.pdf", "kind": "pdf"})
    typed = save(["Idioms"], {"name": "Typed syllabus", "kind": "typed"})
    save(["My Own Topic"], None)
    assert pdf[0]["syllabus_import_id"] == pdf[1]["syllabus_import_id"] is not None

    imports = db_client.get("/api/v1/exams/SSC_CGL/syllabus-imports").json()
    assert [(i["name"], i["kind"], i["topic_count"]) for i in imports] == [
        ("Typed syllabus", "typed", 1),
        ("cgl-syllabus.pdf", "pdf", 2),
    ]

    other = make_user(db_session, "other@example.com")
    import_id = pdf[0]["syllabus_import_id"]
    assert (
        db_client.delete(
            f"/api/v1/syllabus-imports/{import_id}", headers=auth_headers(other)
        ).status_code
        == 404
    )

    removed = db_client.delete(f"/api/v1/syllabus-imports/{import_id}")
    assert removed.json() == {"deleted": 2}
    own = {t["name"] for t in db_client.get("/api/v1/exams/SSC_CGL/topics").json() if t["own"]}
    assert own == {"Idioms", "My Own Topic"}
    assert [i["name"] for i in db_client.get("/api/v1/exams/SSC_CGL/syllabus-imports").json()] == [
        typed[0]["syllabus_import_id"] and "Typed syllabus"
    ]
