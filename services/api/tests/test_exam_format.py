"""Exam formats: a mock is built only from stated facts, never from defaults."""

import uuid
from datetime import date
from typing import Any

import pytest
from fastapi.testclient import TestClient
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.domain.exam_format import format_problems
from app.models.question import ExamFormat

SECTIONS = [
    {"subject": "General Awareness", "questions": 25, "max_marks": 50},
    {"subject": "Quantitative Aptitude", "questions": 25, "max_marks": 50},
]


def problems(**changes: Any) -> list[str]:
    fields: dict[str, Any] = {
        "sections": SECTIONS,
        "total_questions": 50,
        "duration_minutes": 60,
        "negative_marks_per_wrong": 0.5,
    }
    fields.update(changes)
    return format_problems(**fields)


def test_a_complete_format_has_no_problems() -> None:
    assert problems() == []


def test_no_negative_marking_must_be_stated_as_zero() -> None:
    assert problems(negative_marks_per_wrong=0.0) == []
    assert problems(negative_marks_per_wrong=None) == [
        "The format does not state its negative marking (0 if there is none)."
    ]
    assert problems(negative_marks_per_wrong=-1.0) == [
        "Negative marks must be stated as a deduction of 0 or more."
    ]


@pytest.mark.parametrize(
    ("section", "expected"),
    [
        ({"subject": "Reasoning", "questions": 25}, "Reasoning has no maximum marks."),
        ({"subject": "Reasoning", "max_marks": 50}, "Reasoning has no question count."),
        ({"questions": 25, "max_marks": 50}, "Section 3 has no subject."),
        ({"subject": "Reasoning", "questions": True, "max_marks": 50}, None),
    ],
)
def test_every_section_states_its_count_and_marks(
    section: dict[str, Any], expected: str | None
) -> None:
    found = problems(sections=[*SECTIONS, section], total_questions=75)
    assert found
    if expected is not None:
        assert expected in found


def test_missing_totals_and_duration_are_problems() -> None:
    assert problems(sections=[]) == ["The format lists no sections."]
    assert "The format has no verified duration." in problems(duration_minutes=None)
    assert "The format has no total question count." in problems(total_questions=None)
    assert problems(total_questions=60) == [
        "The section question counts do not add up to the total."
    ]


def test_seeded_official_formats_are_complete(db_session: Session) -> None:
    formats = db_session.scalars(select(ExamFormat)).all()
    assert {f.code for f in formats} >= {"SSC_CHSL_2026_TIER1", "SSC_CGL_2026_TIER1"}
    for f in formats:
        assert (
            format_problems(
                sections=f.sections,
                total_questions=f.total_questions,
                duration_minutes=f.duration_minutes,
                negative_marks_per_wrong=f.negative_marks_per_wrong,
            )
            == []
        ), f.code


def test_an_incomplete_format_is_listed_but_cannot_start_a_mock(
    db_client: TestClient, db_session: Session
) -> None:
    db_session.add(
        ExamFormat(
            id=uuid.uuid4(),
            code="TEST_INCOMPLETE",
            exam_code="SSC_CHSL",
            stage="Tier-I",
            name="Incomplete test format",
            sections=[{"subject": "General Awareness", "questions": 1}],
            sections_in_fixed_order=False,
            total_questions=1,
            duration_minutes=10,
            negative_marks_per_wrong=None,
            source_title="Test",
            source_url="https://example.invalid",
            source_reference="Test",
            source_published_on=date(2026, 1, 1),
            verified_on=date(2026, 1, 1),
            status="verified",
            reviewed_by="Test",
        )
    )
    db_session.flush()

    listed = db_client.get("/api/v1/practice/mock-tests", params={"exam": "SSC_CHSL"}).json()
    response = db_client.post(
        "/api/v1/practice/mock-tests", json={"exam_format_code": "TEST_INCOMPLETE"}
    )

    incomplete = next(m for m in listed if m["exam_format_code"] == "TEST_INCOMPLETE")
    assert incomplete["available"] is False
    assert "General Awareness has no maximum marks." in incomplete["format_problems"]
    assert any("negative marking" in p for p in incomplete["format_problems"])
    official = next(m for m in listed if m["exam_format_code"] == "SSC_CHSL_2026_TIER1")
    assert official["format_problems"] == []
    assert response.status_code == 422
    assert response.json()["error"]["code"] == "format_incomplete"
