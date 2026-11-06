"""Exam profiles: values come from data, unset ones from the defaults, and the parser and AI
follow them. SSC CGL and CHSL must equal their templates and format files."""

import importlib.util
import json
import re
from pathlib import Path
from typing import Any

import pytest
from fastapi.testclient import TestClient
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.domain.exam_profile import FORMATS_DIR, TEMPLATES_DIR, VARIABLE_OPTIONS, resolve
from app.domain.segmentation import PageText, segment
from app.models.exam import Exam
from app.models.question import ExamFormat
from app.services.exam_profiles import profile_for

REPO = Path(__file__).resolve().parents[3]
EXAM_NAMES = re.compile(r"\b(SSC|CGL|CHSL|IBPS|UPSC|NEET|JEE|RRB|NTPC)\b|\b(SSC|RRB|IBPS)_", re.I)


def _template(name: str) -> dict[str, Any]:
    data: dict[str, Any] = json.loads((TEMPLATES_DIR / name).read_text(encoding="utf-8"))
    return data


def test_unset_values_come_from_the_defaults() -> None:
    profile = resolve()
    defaults = _template("defaults.json")
    assert profile.kind == defaults["kind"]
    assert profile.options_per_question == defaults["options_per_question"]
    assert profile.repeat_share == defaults["repeat_share"]
    assert profile.min_papers == defaults["min_papers"]
    assert profile.reliable_papers == defaults["reliable_papers"]
    assert profile.counting_unit == defaults["counting_unit"]


def test_an_exams_own_values_win_and_options_can_vary() -> None:
    assert resolve(options_per_question=5, min_papers=7).expected_options == 5
    assert resolve(min_papers=7).min_papers == 7
    varies = resolve(options_per_question=VARIABLE_OPTIONS)
    assert varies.options_per_question is None
    assert varies.expected_options == _template("defaults.json")["options_per_question"]


@pytest.mark.parametrize("file", ["ssc_cgl.json", "ssc_chsl.json"])
def test_ssc_templates_equal_the_migrated_exams(db_session: Session, file: str) -> None:
    template = _template(file)
    exam = db_session.get(Exam, template["code"])
    assert exam is not None
    for field in (
        "name",
        "short_name",
        "category",
        "featured",
        "sort_order",
        "kind",
        "options_per_question",
        "repeat_share",
        "min_papers",
        "reliable_papers",
        "counting_unit",
    ):
        assert getattr(exam, field) == template[field], field


@pytest.mark.parametrize("file", ["ssc_cgl_2026_tier1.json", "ssc_chsl_2026_tier1.json"])
def test_ssc_format_files_equal_the_migrated_formats(db_session: Session, file: str) -> None:
    data = json.loads((FORMATS_DIR / file).read_text(encoding="utf-8"))
    row = db_session.scalars(select(ExamFormat).where(ExamFormat.code == data["code"])).one()
    assert row.exam_code == data["exam_code"]
    assert row.stage == data["stage"]
    assert row.name == data["name"]
    assert row.sections == data["sections"]
    assert row.sections_in_fixed_order == data["sections_in_fixed_order"]
    assert row.total_questions == data["total_questions"]
    assert row.duration_minutes == data["duration_minutes"]
    assert row.negative_marks_per_wrong == data["negative_marks_per_wrong"]
    assert row.sectional_timing == data.get("sectional_timing", False)
    assert row.source_url == data["source"]["url"]


def test_exam_list_carries_the_profile(db_client: TestClient) -> None:
    exams = {e["code"]: e for e in db_client.get("/api/v1/me/exams").json()}
    assert exams["SSC_CHSL"]["profile"] == {
        "kind": "mcq",
        "options_per_question": 4,
        "repeat_share": 0.5,
        "min_papers": 3,
        "reliable_papers": 5,
        "counting_unit": "paper",
        "exam_dates": [],
    }


FIVE_OPTIONS = """1. Which of these is the largest number in the list?
(1) one
(2) two
(3) three
(4) four
(5) five
2. Which of these is the smallest number in the list?
(1) one
(2) two
(3) three
(4) four
(5) five"""


def test_the_parser_checks_papers_against_the_exams_option_count(db_session: Session) -> None:
    db_session.add(Exam(code="FIVE_EXAM", name="Five", options_per_question=5))
    db_session.flush()
    five = profile_for(db_session, "FIVE_EXAM").expected_options
    pages = [PageText(1, FIVE_OPTIONS)]
    as_five = segment(pages, expected_options=five)
    as_default = segment(pages, expected_options=profile_for(db_session, None).expected_options)
    assert [len(q.options) for q in as_five.questions] == [5, 5]
    assert not any(i.code == "incomplete_options" for q in as_five.questions for i in q.issues)
    assert any(i.code == "incomplete_options" for q in as_default.questions for i in q.issues)


def test_the_apps_copy_of_the_exam_data_is_up_to_date() -> None:
    spec = importlib.util.spec_from_file_location(
        "export_exam_data", REPO / "scripts" / "export_exam_data.py"
    )
    assert spec is not None and spec.loader is not None
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    assert module.TARGET.read_text(encoding="utf-8") == module.render()


def test_an_exam_whose_options_vary_accepts_any_count(db_session: Session) -> None:
    db_session.add(Exam(code="VARIES", name="Varies", options_per_question=VARIABLE_OPTIONS))
    db_session.flush()
    profile = profile_for(db_session, "VARIES")
    assert profile.parser_options is None
    three = "1. A question with three options here?\n(1) a\n(2) b\n(3) c"
    six = "2. A question with six options here?\n(1) a\n(2) b\n(3) c\n(4) d\n(5) e\n(6) f"
    read = segment([PageText(1, f"{three}\n{six}")], expected_options=profile.parser_options)
    assert [len(q.options) for q in read.questions] == [3, 6]
    assert not any(i.code == "incomplete_options" for q in read.questions for i in q.issues)


def test_exam_names_are_only_in_template_data() -> None:
    """Exam names and codes live in data/ and tests, never in app code."""
    roots = [(REPO / "services/api/app", "*.py"), (REPO / "services/api/app", "*.txt")]
    roots += [(REPO / "apps/mobile/lib", "*.dart")]
    found = []
    for root, pattern in roots:
        for path in root.rglob(pattern):
            if path.name.endswith(".g.dart") or "generated" in path.parts:
                continue
            for number, line in enumerate(path.read_text(encoding="utf-8").splitlines(), 1):
                if EXAM_NAMES.search(line):
                    found.append(f"{path.relative_to(REPO)}:{number}: {line.strip()[:70]}")
    assert found == []
