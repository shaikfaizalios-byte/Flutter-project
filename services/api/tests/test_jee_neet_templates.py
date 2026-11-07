"""JEE Main, JEE Advanced and NEET UG templates: the data adds up and marks as the papers say."""

import json
from datetime import date
from decimal import Decimal
from typing import Any

import pytest
from fastapi.testclient import TestClient
from sqlalchemy.orm import Session

from app.cli.exam_formats import (
    FormatFile,
    TemplateFile,
    apply_template,
    import_format,
    publish,
    template_problems,
)
from app.domain import question_formats
from app.domain.exam_format import config_problems, format_problems, section_key, section_marking
from app.domain.exam_profile import FORMATS_DIR, TEMPLATES_DIR
from app.domain.scoring import ScoredItem, score_session
from app.models.question import FormatStatus
from app.services.exam_formats import publish_problems

OFFICIAL_HOSTS = ("https://cdnbbsr.s3waas.gov.in/", "https://jeeadv.ac.in/", "https://nta.ac.in/")
FORMATS = {
    "jee_main_2027_paper1": (75, 300),
    "jee_advanced_2026_paper1": (48, 180),
    "jee_advanced_2026_paper2": (54, 180),
    "neet_ug_2026": (180, 720),
    "neet_ug_2026_re": (180, 720),
}
TEMPLATES = ("jee_main", "jee_advanced", "neet_ug")


def fmt(name: str) -> dict[str, Any]:
    data: dict[str, Any] = json.loads((FORMATS_DIR / f"{name}.json").read_text(encoding="utf-8"))
    return data


def template(name: str) -> dict[str, Any]:
    data: dict[str, Any] = json.loads((TEMPLATES_DIR / f"{name}.json").read_text(encoding="utf-8"))
    return data


@pytest.mark.parametrize(("name", "totals"), FORMATS.items())
def test_each_format_adds_up_to_the_official_totals(name: str, totals: tuple[int, int]) -> None:
    data = fmt(name)
    FormatFile.model_validate(data)
    assert sum(s["questions"] for s in data["sections"]) == totals[0] == data["total_questions"]
    assert sum(s["max_marks"] for s in data["sections"]) == totals[1]


@pytest.mark.parametrize("name", FORMATS)
def test_every_scoring_fact_is_stated_and_cited_to_an_official_host(name: str) -> None:
    data = fmt(name)
    assert (
        format_problems(
            sections=data["sections"],
            total_questions=data["total_questions"],
            duration_minutes=data["duration_minutes"],
            negative_marks_per_wrong=data.get("negative_marks_per_wrong"),
            penalty_fraction=data.get("penalty_fraction"),
        )
        == []
    )
    assert data["source"]["url"].startswith(OFFICIAL_HOSTS)
    assert all(s["reference"] for s in data["sections"])
    assert set(data["conduct"]["references"]) >= {"mode", "languages", "duration"}


@pytest.mark.parametrize("name", TEMPLATES)
def test_templates_count_by_session_and_cite_official_sources(name: str) -> None:
    data = template(name)
    assert data["counting_unit"] == "session"
    assert data["status"] == "draft"  # a named reviewer publishes them
    assert template_problems(TemplateFile.model_validate(data)) == []
    assert all(s["url"].startswith(OFFICIAL_HOSTS) for s in data["sources"].values())
    assert {f.stem.upper() for f in FORMATS_DIR.glob("*.json")} >= set(data["formats"])


def test_no_third_party_copy_is_cited_any_more() -> None:
    for name in FORMATS:
        assert "karnatakahelp" not in json.dumps(fmt(name))
    assert "karnatakahelp" not in json.dumps(template("neet_ug"))


def marks_of(section: dict[str, Any], data: dict[str, Any]) -> tuple[float, float]:
    marking = section_marking(
        section,
        negative_marks_per_wrong=data.get("negative_marks_per_wrong"),
        penalty_fraction=data.get("penalty_fraction"),
    )
    return marking.marks_correct, marking.marks_wrong


def test_jee_main_marks_both_sections_plus_four_minus_one() -> None:
    data = fmt("jee_main_2027_paper1")
    assert {marks_of(s, data) for s in data["sections"]} == {(4, 1)}
    assert {s["formats"][0] for s in data["sections"]} == {"single_correct", "integer"}


def test_jee_main_lists_two_sessions_of_six_days_with_two_shifts() -> None:
    conduct = fmt("jee_main_2027_paper1")["conduct"]
    assert [len(s["dates"]) for s in conduct["sessions"]] == [6, 6]
    assert len(conduct["shifts"]) == 2 and conduct["mode"] == "cbt"
    assert len(conduct["languages"]) == 13


@pytest.mark.parametrize(
    ("paper", "part", "right", "wrong"),
    [
        (1, "Section 1", 3, 1),
        (1, "Section 2", 4, 1),
        (1, "Section 3", 4, 0),
        (1, "Section 4", 4, 1),
        (2, "Section 1", 3, 1),
        (2, "Section 2", 4, 1),
        (2, "Section 3", 4, 0),
        (2, "Section 4", 2, 0),
    ],
)
def test_jee_advanced_marks_each_section_as_its_paper_says(
    paper: int, part: str, right: float, wrong: float
) -> None:
    data = fmt(f"jee_advanced_2026_paper{paper}")
    rows = [s for s in data["sections"] if s["part"] == part]
    assert len(rows) == 3  # one per subject
    assert {marks_of(s, data) for s in rows} == {(right, wrong)}


@pytest.mark.parametrize(
    ("correct", "chosen", "marks"),
    [
        ([1, 2, 3, 4], [1, 2, 3, 4], 4),  # full marks
        ([1, 3], [1, 3], 4),
        ([1, 2, 3, 4], [1, 2, 3], 3),  # all four correct, only three chosen
        ([1, 2, 3], [1, 2], 2),  # three or more correct, only two chosen
        ([1, 2, 3, 4], [2, 4], 2),
        ([1, 2], [2], 1),  # two or more correct, only one chosen
        ([1, 2, 3], [3], 1),
        ([1, 2], [1, 3], -1),  # all other cases
        ([1], [2], -1),
    ],
)
def test_the_stored_partial_rule_gives_the_papers_exact_marks(
    correct: list[int], chosen: list[int], marks: int
) -> None:
    section = next(
        s for s in fmt("jee_advanced_2026_paper1")["sections"] if s["part"] == "Section 2"
    )
    item = ScoredItem(
        position=1,
        section=None,
        topic_id=None,
        correct_position=None,
        marks_correct=Decimal(4),
        marks_wrong=Decimal(section["marks_wrong"]),
        format="multiple_correct",
        answer_spec={"correct_positions": correct},
        partial_rule=section["partial"],
    )
    result = score_session([item], {1: {"positions": chosen}})
    assert result.total.score == marks


def test_a_blank_multiple_correct_answer_scores_zero() -> None:
    item = ScoredItem(
        position=1,
        section=None,
        topic_id=None,
        correct_position=None,
        marks_correct=Decimal(4),
        marks_wrong=Decimal(1),
        format="multiple_correct",
        answer_spec={"correct_positions": [1]},
        partial_rule={"per_correct": "1"},
    )
    assert score_session([item], {}).total.score == 0


def test_formats_it_names_can_all_be_marked() -> None:
    for name in FORMATS:
        for section in fmt(name)["sections"]:
            assert set(section.get("formats", [])) <= set(question_formats.FORMATS)


def test_the_re_exam_keeps_its_own_year_mode_and_window() -> None:
    first, again = fmt("neet_ug_2026"), fmt("neet_ug_2026_re")
    assert (first["duration_minutes"], again["duration_minutes"]) == (180, 195)
    assert again["supersedes"] == "NEET_UG_2026"
    assert first["effective_to"] == "2026-05-03"
    assert again["conduct"]["mode"] == "pen_and_paper"
    assert again["conduct"]["shifts"][0] == {
        "name": "Single shift",
        "starts": "14:00",
        "ends": "17:15",
    }


def test_nothing_is_stored_for_a_year_with_no_official_source() -> None:
    assert not list(FORMATS_DIR.glob("neet_ug_2027*"))
    assert not list(FORMATS_DIR.glob("jee_advanced_2027*"))
    assert "2027" in template("neet_ug")["note"]


def test_what_the_sources_leave_open_is_written_down() -> None:
    for name in FORMATS:
        assert fmt(name)["conduct"]["not_stated"]


def test_two_sections_need_different_subjects_or_parts() -> None:
    section = {"subject": "Physics", "questions": 1, "max_marks": 4}
    problems = config_problems(
        sections=[section, section],
        duration_minutes=60,
        sections_in_fixed_order=False,
        sectional_timing=False,
        question_types=["choice"],
        effective_from=None,
        effective_to=None,
        source_title="t",
        source_url="https://example.com",
        source_reference="r",
    )
    assert problems == ["Two sections have the same subject and part."]
    parts = [section | {"part": "A"}, section | {"part": "B"}]
    assert section_key(parts[0], parts) == "Physics A"


def test_templates_apply_and_formats_import_as_drafts(db_session: Session) -> None:
    for name in TEMPLATES:
        apply_template(db_session, template(name), "A. Reviewer")
    db_session.flush()
    row, problems = import_format(db_session, fmt("jee_advanced_2026_paper1"))
    assert row.status == FormatStatus.DRAFT
    assert row.conduct is not None and row.conduct["mode"] == "cbt"
    assert not any("subject and part" in problem for problem in problems)
    assert publish_problems(row) == problems


def test_a_published_year_reaches_the_app_with_no_new_release(
    db_client: TestClient, db_session: Session
) -> None:
    apply_template(db_session, template("neet_ug"), "A. Reviewer")
    db_session.flush()
    import_format(db_session, fmt("neet_ug_2026"))
    row, problems = import_format(db_session, fmt("neet_ug_2026_re"))
    assert problems == []
    publish(db_session, row.code, "A. Reviewer", date(2026, 11, 7))
    db_session.flush()
    stages = db_client.get("/api/v1/me/exams/NEET_UG/stages").json()
    conduct = next(s for s in stages if s["conduct"])["conduct"]
    assert conduct["year"] == 2026 and conduct["mode"] == "pen_and_paper"
