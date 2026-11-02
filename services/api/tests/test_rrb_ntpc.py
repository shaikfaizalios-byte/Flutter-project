"""RRB NTPC from CEN 06/2026 and 07/2026 (global Phase 10): the catalog facts and syllabus
topics of migration 0038, and the four draft formats in data/exam_formats."""

import json
from datetime import date
from pathlib import Path
from typing import Any

import pytest
from fastapi.testclient import TestClient
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.cli.exam_formats import import_format, publish
from app.models.document import Document
from app.models.practice import PracticeSession, SessionMode
from app.models.question import ExamFormat, Topic
from app.models.user import User
from app.services.practice_service import PracticeService
from app.services.taxonomy_service import subject_labels_by_topic
from tests.test_practice import document, make_question

__all__ = ["document"]  # fixture re-used from test_practice

FORMATS = Path(__file__).resolve().parents[1] / "data" / "exam_formats"
CODES = ["RRB_NTPC_G_2026_CBT1", "RRB_NTPC_G_2026_CBT2", "RRB_NTPC_UG_2026_CBT1"]
CODES.append("RRB_NTPC_UG_2026_CBT2")


def _file(code: str) -> dict[str, Any]:
    data: dict[str, Any] = json.loads((FORMATS / f"{code.lower()}.json").read_text("utf-8"))
    return data


def test_the_catalog_records_the_notice_facts(db_client: TestClient) -> None:
    exams = {e["code"]: e for e in db_client.get("/api/v1/exams").json()}
    ntpc = exams["RRB_NTPC"]
    assert ntpc["authority"] == "Railway Recruitment Boards (Ministry of Railways)"
    # English, Hindi and 13 regional languages (para 14.3 d); none guessed for Group D.
    assert ntpc["languages"][:2] == ["en", "hi"] and len(ntpc["languages"]) == 15
    assert {"kok", "mni", "ur"} <= set(ntpc["languages"])
    assert exams["RRB_GROUP_D"]["languages"] == []


def test_the_syllabus_topics_are_added_for_ntpc_only(db_session: Session) -> None:
    added = db_session.scalars(
        select(Topic).where(Topic.owner_id.is_(None), Topic.name == "Data Sufficiency")
    ).all()
    assert [t.exam_codes for t in added] == [["RRB_NTPC"]]
    assert added[0].subject == "General Intelligence"
    # Already-shared topics are not duplicated.
    assert (
        len(
            db_session.scalars(
                select(Topic).where(Topic.owner_id.is_(None), Topic.name == "Percentage")
            ).all()
        )
        == 1
    )


def test_mathematics_is_an_alias_of_quantitative_aptitude(db_session: Session) -> None:
    percentage = db_session.scalar(
        select(Topic).where(Topic.owner_id.is_(None), Topic.name == "Percentage")
    )
    assert percentage is not None
    labels = subject_labels_by_topic(db_session, [percentage.id])[percentage.id]
    assert {"Quantitative Aptitude", "Mathematics"} <= set(labels)


@pytest.mark.parametrize("code", CODES)
def test_each_draft_states_every_fact_and_can_be_published(db_session: Session, code: str) -> None:
    data = _file(code)
    draft, problems = import_format(db_session, data)
    assert problems == []
    assert draft.status == "draft"  # nothing is verified until a reviewer publishes it
    assert sum(s["questions"] for s in data["sections"]) == data["total_questions"]
    assert data["negative_marks_per_wrong"] == pytest.approx(1 / 3)
    assert data["section_counts_indicative"] is True
    published = publish(db_session, code, "A. Reviewer", date.today())
    assert published.status == "verified"


def test_a_published_ntpc_mock_says_its_split_is_indicative(
    db_client: TestClient, db_session: Session, document: Document, user: User
) -> None:
    import_format(db_session, _file("RRB_NTPC_G_2026_CBT1"))
    publish(db_session, "RRB_NTPC_G_2026_CBT1", "A. Reviewer", date.today())
    percentage = db_session.scalar(
        select(Topic).where(Topic.owner_id.is_(None), Topic.name == "Percentage")
    )
    question = make_question(db_session, document, topic=percentage)
    question.exam_code = "RRB_NTPC"
    db_session.flush()

    mocks = db_client.get("/api/v1/practice/mock-tests", params={"exam": "RRB_NTPC"}).json()
    mock = next(m for m in mocks if m["exam_format_code"] == "RRB_NTPC_G_2026_CBT1")
    assert mock["section_counts_indicative"] is True
    # A Quantitative Aptitude question counts toward the notice's "Mathematics" section.
    sections = {s["subject"]: s for s in mock["sections"]}
    assert sections["Mathematics"]["available"] == 1
    assert (mock["available"], mock["format_problems"]) == (False, [])  # 1 of 100 questions

    exam_format = db_session.scalar(
        select(ExamFormat).where(ExamFormat.code == "RRB_NTPC_G_2026_CBT1")
    )
    assert exam_format is not None
    note = PracticeService(db_session, owner_id=user.id)._marking_note(
        PracticeSession(mode=SessionMode.MOCK, exam_format_id=exam_format.id, selection={})
    )
    assert "Wrong answer: -0.33." in note
    assert "only indicative: real papers may vary" in note
    assert "CEN No. 06/2026 para 13.1" in note
