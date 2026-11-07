"""Challenge Ladder for any exam: formats, option counts, times and marks come from the exam."""

import random
import re
from datetime import date
from pathlib import Path
from typing import Any

import pytest
from fastapi.testclient import TestClient
from sqlalchemy import func, select
from sqlalchemy.orm import Session

from app.domain import challenge_ladder as ladder
from app.domain.exam_format import SectionMarking
from app.integrations.ai import WebSearchHit
from app.models.exam import Exam
from app.models.ladder import LadderStep
from app.models.question import ExamFormat, FormatStatus, Question, Topic
from app.models.user import User
from tests.fakes import FakeAIProvider
from tests.test_ai import AppFactory, ai, make_api
from tests.test_ladder import SESSIONS, fresh_question, solved, topic
from tests.test_practice import document

__all__ = ["ai", "document", "make_api", "topic"]  # fixtures re-used from other test modules

MARKS = SectionMarking(marks_correct=4, marks_wrong=1, marks_unanswered=0, partial=None)


def context(*formats: str, **changes: Any) -> ladder.ExamContext:
    values: dict[str, Any] = {
        "name": "State Service Exam",
        "stage": "Prelims",
        "next_stage": "Mains",
        "formats": formats or ("single_correct",),
        "options": 5,
        "marking": MARKS,
        "base_time_seconds": 72,
    }
    return ladder.ExamContext(**(values | changes))


def prompt_for(exam: ladder.ExamContext) -> str:
    return ladder.generator_prompt(
        exam=exam,
        topic="Percentage",
        round_number=1,
        plan=ladder.plan_round([], 1),
        number=4,
        seeds=[],
        web=[],
        avoid=[],
        missed=[],
        language="en",
    )


def question(**fields: Any) -> dict[str, Any]:
    return {"question": "What is asked here?", "solution": "Work it out", "shortcut": ""} | fields


FIVE = ["a", "b", "c", "d", "e"]


# --- times ------------------------------------------------------------------------------------


def test_the_base_time_is_the_stage_duration_over_its_questions() -> None:
    assert ladder.base_time(120, 100) == 72
    assert ladder.base_time(None, 100) == ladder.base_time(60, None) == 36


@pytest.mark.parametrize(
    ("level", "seconds"),
    [("easy", 30), ("medium", 60), ("medium_hard", 75), ("hard", 90), ("extreme_hard", 145)],
)
def test_the_default_base_keeps_the_times_the_ladder_always_had(
    level: ladder.Difficulty, seconds: int
) -> None:
    assert ladder.time_target(level, 36) == seconds


def test_time_targets_stay_within_the_limits() -> None:
    assert ladder.time_target("easy", 1) == 15
    assert ladder.time_target("extreme_hard", 9999) == 600


# --- the prompt -------------------------------------------------------------------------------


def test_the_prompt_template_names_no_exam_or_stage() -> None:
    path = Path(ladder.__file__).parent / "prompts" / "challenge_ladder_generator.txt"
    pattern = r"\b(SSC|CGL|CHSL|Tier|mains|General Awareness)\b"
    assert re.search(pattern, path.read_text(encoding="utf-8"), re.IGNORECASE) is None


def test_the_prompt_states_the_exams_own_facts() -> None:
    prompt = prompt_for(context())
    assert "The toughest level in a State Service Exam Prelims paper" in prompt
    assert "the level of the Mains stage" in prompt
    assert "exactly 5 options with exactly one correct answer" in prompt
    assert "MARKING: +4 for a correct answer, -1 for a wrong one" in prompt
    assert "AVERAGE TIME PER QUESTION IN THIS STAGE: 72 seconds" in prompt
    assert "{{" not in prompt


def test_without_a_next_stage_the_top_level_is_multi_concept() -> None:
    prompt = prompt_for(context(next_stage=None, stage=None, marking=None))
    assert "multi-concept questions that still use syllabus methods" in prompt
    assert "MARKING: not stated" in prompt


def test_the_prompt_offers_only_the_allowed_formats() -> None:
    prompt = prompt_for(context("single_correct", "numeric"))
    assert "- numeric:" in prompt and "numeric_answer" in prompt
    assert "multiple_correct" not in prompt and "match_pairs" not in prompt


def test_the_web_search_names_the_stage() -> None:
    query = ladder.web_query(exam_name="X", stage="Prelims", topic="T", models=["M"])
    assert query == "X Prelims T M questions"
    assert ladder.web_query(exam_name="X", stage=None, topic="T", models=[]) == "X T questions"


def test_allowed_formats_come_from_the_stage_and_a_section_narrows_them() -> None:
    assert ladder.allowed_formats(["choice"]) == ("single_correct",)
    assert ladder.allowed_formats(["choice", "typed"]) == ("single_correct", "numeric")
    assert ladder.allowed_formats(["choice", "match"], ["statement"]) == ("statement",)
    assert ladder.allowed_formats(["ordering"]) == ()


# --- checking what was written ----------------------------------------------------------------


def test_a_format_the_exam_doesnt_allow_is_refused() -> None:
    written = question(format="numeric", numeric_answer="5", tolerance="0")
    assert ladder.validate_generated(written, context(), "easy") is None


def test_the_option_count_is_the_exams() -> None:
    written = question(format="single_correct", options=FIVE, answer_index=4)
    assert ladder.validate_generated(written, context(), "easy") is not None
    four = question(format="single_correct", options=FIVE[:4], answer_index=0)
    assert ladder.validate_generated(four, context(), "easy") is None


def test_statements_become_part_of_the_question() -> None:
    written = question(
        format="statement", statements=["First", "Second"], options=FIVE, answer_index=0
    )
    checked = ladder.validate_generated(written, context("statement"), "easy")
    assert checked is not None
    assert checked.stem == "What is asked here?\n1. First\n2. Second"
    lonely = question(format="statement", statements=["One"], options=FIVE, answer_index=0)
    assert ladder.validate_generated(lonely, context("statement"), "easy") is None


@pytest.mark.parametrize(
    "fields",
    [
        {"format": "multiple_correct", "options": FIVE, "correct_indices": []},
        {"format": "multiple_correct", "options": FIVE, "correct_indices": [5]},
        {"format": "multiple_correct", "options": FIVE, "correct_indices": [1, 1]},
        {"format": "multiple_correct", "options": FIVE, "correct_indices": [True]},
        {"format": "numeric", "numeric_answer": "many", "tolerance": "0"},
        {"format": "numeric", "numeric_answer": "5", "tolerance": "-1"},
        {"format": "numeric"},
        {"format": "match", "match_left": ["a"], "match_right": ["b"], "match_pairs": []},
        {"format": "match", "match_left": ["a"], "match_right": ["b"], "match_pairs": [[0, 3]]},
        {
            "format": "match",
            "match_left": ["a", "b"],
            "match_right": ["c", "d"],
            "match_pairs": [[0, 0], [0, 1]],
        },
    ],
)
def test_an_answer_that_doesnt_fit_its_format_is_refused(fields: dict[str, Any]) -> None:
    allowed = context("multiple_correct", "numeric", "match")
    assert ladder.validate_generated(question(**fields), allowed, "easy") is None


def several() -> ladder.GeneratedQuestion:
    written = question(format="multiple_correct", options=FIVE, correct_indices=[3, 0])
    checked = ladder.validate_generated(written, context("multiple_correct"), "easy")
    assert checked is not None
    return checked


def number() -> ladder.GeneratedQuestion:
    written = question(format="numeric", numeric_answer="2.5", tolerance="0.01")
    checked = ladder.validate_generated(written, context("numeric"), "easy")
    assert checked is not None
    return checked


def pairs() -> ladder.GeneratedQuestion:
    written = question(
        format="match",
        match_left=["Red", "Blue", "Green"],
        match_right=["Sky", "Grass", "Rose"],
        match_pairs=[[0, 2], [1, 0], [2, 1]],
    )
    checked = ladder.validate_generated(written, context("match"), "easy")
    assert checked is not None
    return checked


def test_the_solver_must_reach_the_same_set_of_options_in_any_order() -> None:
    assert ladder.solver_agrees({"correct_indices": [0, 3]}, several())
    assert ladder.solver_agrees({"correct_indices": [3, 0]}, several())
    assert not ladder.solver_agrees({"correct_indices": [0]}, several())
    assert not ladder.solver_agrees({"correct_indices": [0, 3, 4]}, several())
    assert not ladder.solver_agrees({"correct_indices": "0, 3"}, several())


def test_the_solver_must_land_within_the_tolerance() -> None:
    assert ladder.solver_agrees({"numeric_answer": "2.51"}, number())
    assert ladder.solver_agrees({"numeric_answer": 2.49}, number())
    assert not ladder.solver_agrees({"numeric_answer": "2.52"}, number())
    assert not ladder.solver_agrees({"numeric_answer": "about 2.5"}, number())
    assert not ladder.solver_agrees({}, number())


def test_the_solver_must_make_exactly_the_same_pairs() -> None:
    assert ladder.solver_agrees({"match_pairs": [[2, 1], [0, 2], [1, 0]]}, pairs())
    assert not ladder.solver_agrees({"match_pairs": [[0, 2], [1, 0]]}, pairs())
    assert not ladder.solver_agrees({"match_pairs": [[0, 0], [1, 2], [2, 1]]}, pairs())
    assert not ladder.solver_agrees({"match_pairs": "none"}, pairs())


def test_the_solver_sees_no_key() -> None:
    prompt = ladder.solve_prompt(
        stem="Q", options=[], format_name="match", spec=pairs().answer_spec
    )
    assert "Red" in prompt and "Sky" in prompt and "[0, 2]" not in prompt
    assert "2.5" not in ladder.solve_prompt(stem="Q", options=[], format_name="numeric")


def test_each_format_asks_the_solver_only_for_its_own_answer() -> None:
    assert set(ladder.solve_schema("numeric")["properties"]) == {"numeric_answer", "working"}
    assert set(ladder.solve_schema("statement")["properties"]) == {"answer_index", "working"}


def test_shuffling_keeps_the_key_on_its_options() -> None:
    for seed in range(20):
        shown = ladder.shuffled(several(), random.Random(seed))  # noqa: S311 - test data
        assert shown.answer_spec is not None
        chosen = {shown.options[p - 1] for p in shown.answer_spec["correct_positions"]}
        assert chosen == {"a", "d"}


def test_shuffling_keeps_each_pair_together() -> None:
    for seed in range(20):
        spec = ladder.shuffled(pairs(), random.Random(seed)).answer_spec  # noqa: S311 - test data
        assert spec is not None
        found = {spec["left"][a]: spec["right"][b] for a, b in spec["pairs"]}
        assert found == {"Red": "Rose", "Blue": "Sky", "Green": "Grass"}


def test_a_number_has_nothing_to_shuffle() -> None:
    assert ladder.shuffled(number(), random.Random(1)) == number()  # noqa: S311 - test data


# --- marks ------------------------------------------------------------------------------------


def test_marks_follow_the_exam_with_a_penalty_for_a_wrong_answer() -> None:
    def scored(answer: int) -> tuple[bool, float | None]:
        return ladder.mark(
            format_name="single_correct",
            spec=None,
            answer_index=2,
            answer=answer,
            marking=(4.0, 1.0, None),
        )

    assert scored(2) == (True, 4.0)
    assert scored(1) == (False, -1.0)


def test_a_partly_right_answer_earns_marks_but_isnt_correct() -> None:
    def scored(positions: list[int]) -> tuple[bool, float | None]:
        return ladder.mark(
            format_name="multiple_correct",
            spec={"correct_positions": [1, 3, 4]},
            answer_index=None,
            answer={"positions": positions},
            marking=(4.0, 2.0, {"per_correct": "1"}),
        )

    assert scored([1, 3, 4]) == (True, 4.0)
    assert scored([1, 3]) == (False, 2.0)
    assert scored([1, 2]) == (False, -2.0)


def test_without_stated_marks_an_answer_is_only_right_or_wrong() -> None:
    result = ladder.mark(
        format_name="single_correct", spec=None, answer_index=0, answer=0, marking=None
    )
    assert result == (True, None)


def test_the_right_answer_is_put_in_words() -> None:
    assert ladder.answer_lines("multiple_correct", several().answer_spec, FIVE) == ["a", "d"]
    assert ladder.answer_lines("numeric", number().answer_spec, []) == ["2.5 ± 0.01"]
    exact = {"value": "7", "tolerance": "0"}
    assert ladder.answer_lines("numeric", exact, []) == ["7"]
    assert ladder.answer_lines("match", pairs().answer_spec, [])[0] == "Red → Rose"
    assert ladder.answer_lines("single_correct", None, FIVE) == []


# --- whole rounds through the API (fake AI provider: no network) -----------------------------


def add_exam(db: Session, types: list[str], **sections: Any) -> Exam:
    """A catalog exam with five options, 2 minutes a question and a quarter-mark penalty."""
    exam = Exam(code="STATE_PSC", name="State Service Exam", options_per_question=5)
    db.add(exam)
    db.flush()
    subject = {"subject": "Quantitative Aptitude", "questions": 50, "max_marks": 100}
    db.add(
        ExamFormat(
            code="STATE_PSC_2026",
            exam_code=exam.code,
            stage="Prelims",
            name="State Service Prelims",
            sections=[subject | sections],
            sections_in_fixed_order=False,
            total_questions=50,
            duration_minutes=100,
            penalty_fraction=0.25,
            question_types=types,
            source_title="Notice",
            source_url="https://example.com/notice",
            source_reference="para 1",
            source_published_on=date(2026, 1, 1),
            verified_on=date(2026, 1, 2),
            reviewed_by="A. Reviewer",
            status=FormatStatus.VERIFIED,
        )
    )
    db.flush()
    return exam


def begin(api: TestClient, code: str, topic: Topic, new_formats: bool = True) -> dict[str, Any]:
    response = api.post(
        SESSIONS,
        json={"exam_code": code, "topic_id": str(topic.id), "include_new_formats": new_formats},
    )
    assert response.status_code == 201, response.text
    data: dict[str, Any] = response.json()
    return data


def step_url(body: dict[str, Any], number: int) -> str:
    return f"{SESSIONS}/{body['session_id']}/rounds/{body['round_number']}/steps/{number}"


def generated(api: TestClient, body: dict[str, Any], number: int = 1) -> dict[str, Any]:
    response = api.post(f"{step_url(body, number)}/generate")
    assert response.status_code == 200, response.text
    data: dict[str, Any] = response.json()
    return data


def answered(
    api: TestClient, body: dict[str, Any], answer: dict[str, Any], number: int = 1
) -> dict[str, Any]:
    response = api.post(f"{step_url(body, number)}/answer", json=answer)
    assert response.status_code == 200, response.text
    result: dict[str, Any] = response.json()["result"]
    return result


def five_options(**changes: Any) -> dict[str, Any]:
    return fresh_question(options=["7", "8", "9", "10", "11"], answer_index=1, **changes)


def test_a_five_option_exam_with_a_penalty_works_end_to_end(
    make_api: AppFactory, ai: FakeAIProvider, db_session: Session, topic: Topic
) -> None:
    add_exam(db_session, ["choice"])
    ai.web_hits = [WebSearchHit("Guide", "https://example.com/g", "Percent basics")]
    ai.responses += [five_options(), solved()]
    api = make_api(ai)
    body = begin(api, "STATE_PSC", topic)

    step = generated(api, body)
    assert len(step["options"]) == 5
    assert step["time_target_seconds"] == 95  # 120 s a question x 0.8, to the nearest 5
    assert "State Service Exam Prelims" in ai.searches[0]
    assert "MARKING: +2 for a correct answer, -0.5 for a wrong one" in ai.calls[0].prompt

    row = db_session.scalars(select(LadderStep).where(LadderStep.source == "ai")).one()
    assert row.options is not None and row.answer_index is not None
    assert (row.marks_correct, row.marks_wrong) == (2.0, 0.5)
    wrong = (row.answer_index + 1) % 5
    result = answered(api, body, {"selected_index": wrong})
    assert result["correct"] is False
    assert (result["marks"], result["marks_possible"]) == (-0.5, 2.0)


def test_a_numeric_question_is_typed_marked_within_tolerance_and_keeps_its_key_hidden(
    make_api: AppFactory, ai: FakeAIProvider, db_session: Session, topic: Topic
) -> None:
    add_exam(db_session, ["choice", "numeric"])
    ai.web_hits = [WebSearchHit("Guide", "https://example.com/g", "Percent basics")]
    written = fresh_question(format="numeric", numeric_answer="12.5", tolerance="0.1")
    ai.responses += [written, {"numeric_answer": "12.45", "working": "..."}]
    api = make_api(ai)
    body = begin(api, "STATE_PSC", topic)

    step = generated(api, body)
    assert step["format"] == "numeric" and step["options"] == []
    assert "12.5" not in str(step)
    assert "OPTIONS" not in ai.calls[-1].prompt.upper().split("QUESTION:")[0]

    result = answered(api, body, {"typed_answer": "12.42"})
    assert result["correct"] is True and result["marks"] == 2.0
    assert result["answer_lines"] == ["12.5 ± 0.1"]
    assert result["selected_index"] is None and result["response"] == {"text": "12.42"}


def test_several_correct_options_earn_partial_marks_from_the_exams_rule(
    make_api: AppFactory, ai: FakeAIProvider, db_session: Session, topic: Topic
) -> None:
    add_exam(db_session, ["multiple_correct"], partial={"per_correct": "1"})
    ai.web_hits = [WebSearchHit("Guide", "https://example.com/g", "Percent basics")]
    written = fresh_question(
        format="multiple_correct", options=FIVE, answer_index=None, correct_indices=[0, 2]
    )
    ai.responses += [written, {"correct_indices": [2, 0], "working": "..."}]
    api = make_api(ai)
    body = begin(api, "STATE_PSC", topic)
    assert generated(api, body)["format"] == "multiple_correct"

    row = db_session.scalars(select(LadderStep).where(LadderStep.source == "ai")).one()
    assert row.answer_spec is not None and row.answer_index is None
    first = row.answer_spec["correct_positions"][0]
    result = answered(api, body, {"response": {"positions": [first]}})
    assert result["correct"] is False and result["partly_right"] is True
    assert result["marks"] == 1.0


def test_a_match_question_shows_its_lists_and_never_its_pairs(
    make_api: AppFactory, ai: FakeAIProvider, db_session: Session, topic: Topic
) -> None:
    add_exam(db_session, ["match"])
    ai.web_hits = [WebSearchHit("Guide", "https://example.com/g", "Percent basics")]
    pairing = [[0, 1], [1, 0]]
    written = fresh_question(
        format="match", match_left=["L1", "L2"], match_right=["R1", "R2"], match_pairs=pairing
    )
    ai.responses += [written, {"match_pairs": pairing, "working": "..."}]
    api = make_api(ai)
    body = begin(api, "STATE_PSC", topic)

    step = generated(api, body)
    assert set(step["format_data"]) == {"left", "right"} and "pairs" not in str(step)
    row = db_session.scalars(select(LadderStep).where(LadderStep.source == "ai")).one()
    assert row.answer_spec is not None
    assert answered(api, body, {"response": {"pairs": row.answer_spec["pairs"]}})["correct"]


def test_a_disagreeing_solve_sends_the_question_back(
    make_api: AppFactory, ai: FakeAIProvider, db_session: Session, topic: Topic
) -> None:
    add_exam(db_session, ["numeric"])
    ai.web_hits = [WebSearchHit("Guide", "https://example.com/g", "Percent basics")]
    first = fresh_question(format="numeric", numeric_answer="10", tolerance="0")
    second = fresh_question(format="numeric", numeric_answer="20", tolerance="0")
    ai.responses += [
        first,
        {"numeric_answer": "11", "working": "..."},
        second,
        {"numeric_answer": "20", "working": "..."},
    ]
    api = make_api(ai)
    generated(api, begin(api, "STATE_PSC", topic))
    row = db_session.scalars(select(LadderStep).where(LadderStep.source == "ai")).one()
    assert row.answer_spec == {"value": "20", "tolerance": "0"}


def test_an_answer_of_the_wrong_kind_is_refused(
    make_api: AppFactory, ai: FakeAIProvider, db_session: Session, topic: Topic
) -> None:
    add_exam(db_session, ["numeric"])
    ai.web_hits = [WebSearchHit("Guide", "https://example.com/g", "Percent basics")]
    written = fresh_question(format="numeric", numeric_answer="10", tolerance="0")
    ai.responses += [written, {"numeric_answer": "10", "working": "..."}]
    api = make_api(ai)
    body = begin(api, "STATE_PSC", topic)
    generated(api, body)
    url = f"{step_url(body, 1)}/answer"
    assert api.post(url, json={"selected_index": 0}).status_code == 422
    assert api.post(url, json={"selected_index": 0, "typed_answer": "1"}).status_code == 422
    assert api.post(url, json={}).status_code == 422


def test_an_older_app_gets_one_correct_option_whatever_the_exam_allows(
    make_api: AppFactory, ai: FakeAIProvider, db_session: Session, topic: Topic
) -> None:
    add_exam(db_session, ["numeric"])
    ai.web_hits = [WebSearchHit("Guide", "https://example.com/g", "Percent basics")]
    ai.responses += [five_options(), solved()]
    api = make_api(ai)
    step = generated(api, begin(api, "STATE_PSC", topic, new_formats=False))
    assert step["format"] == "single_correct"
    assert "- numeric:" not in ai.calls[0].prompt


def test_an_exam_whose_formats_cant_be_written_is_refused_at_the_start(
    make_api: AppFactory, ai: FakeAIProvider, db_session: Session, topic: Topic
) -> None:
    add_exam(db_session, ["ordering"])
    api = make_api(ai)
    response = api.post(
        SESSIONS,
        json={"exam_code": "STATE_PSC", "topic_id": str(topic.id), "include_new_formats": True},
    )
    assert response.status_code == 409
    assert response.json()["error"]["code"] == "ladder_no_format"


def test_a_descriptive_exam_has_no_ladder(
    make_api: AppFactory, ai: FakeAIProvider, db_session: Session, topic: Topic
) -> None:
    db_session.add(Exam(code="ESSAYS", name="Essay Exam", kind="descriptive"))
    db_session.flush()
    api = make_api(ai)
    overview = api.get("/api/v1/ladder/overview", params={"exam": "ESSAYS"}).json()
    assert overview["available"] is False and overview["topics"] == []
    response = api.post(SESSIONS, json={"exam_code": "ESSAYS", "topic_id": str(topic.id)})
    assert response.status_code == 409


def test_an_own_exam_uses_the_stage_the_learner_entered_with_no_other_exams_wording(
    make_api: AppFactory, ai: FakeAIProvider, db_session: Session, user: User, topic: Topic
) -> None:
    stage = {
        "name": "Final",
        "duration_minutes": 90,
        "sections": [{"name": "All", "question_count": 45}],
        "marking_scheme": {"marks_correct": 3, "marks_wrong": 1, "marks_unanswered": 0},
    }
    db_session.add(
        Exam(
            code="MY_CLASS_TEST",
            name="Class Test",
            owner_id=user.id,
            custom_stages=[stage],
            options_per_question=3,
        )
    )
    db_session.flush()
    ai.web_hits = [WebSearchHit("Guide", "https://example.com/g", "Percent basics")]
    ai.responses += [fresh_question(options=["1", "2", "3"], answer_index=1), solved()]
    api = make_api(ai)
    body = begin(api, "MY_CLASS_TEST", topic)
    step = generated(api, body)

    assert len(step["options"]) == 3
    assert step["time_target_seconds"] == 95  # 120 s a question x 0.8
    prompt = ai.calls[0].prompt
    assert "The toughest level in a Class Test Final paper" in prompt
    assert re.search(r"\b(SSC|Tier|CGL|CHSL)\b", prompt) is None
    row = db_session.scalars(select(LadderStep).where(LadderStep.source == "ai")).one()
    assert row.answer_index is not None
    assert answered(api, body, {"selected_index": row.answer_index})["marks"] == 3.0


def test_an_exam_with_no_stage_states_no_marks(
    make_api: AppFactory, ai: FakeAIProvider, db_session: Session, topic: Topic
) -> None:
    db_session.add(Exam(code="NO_STAGE", name="No Stage Exam"))
    db_session.flush()
    ai.web_hits = [WebSearchHit("Guide", "https://example.com/g", "Percent basics")]
    ai.responses += [fresh_question(), solved()]
    api = make_api(ai)
    body = begin(api, "NO_STAGE", topic)
    step = generated(api, body)
    assert step["time_target_seconds"] == 30
    result = answered(api, body, {"selected_index": 0})
    assert result["marks"] is None and result["marks_possible"] is None


def test_written_questions_of_any_format_never_reach_the_question_bank(
    make_api: AppFactory, ai: FakeAIProvider, db_session: Session, topic: Topic
) -> None:
    add_exam(db_session, ["numeric"])
    ai.web_hits = [WebSearchHit("Guide", "https://example.com/g", "Percent basics")]
    written = fresh_question(format="numeric", numeric_answer="10", tolerance="0")
    ai.responses += [written, {"numeric_answer": "10", "working": "..."}]
    before = db_session.scalar(select(func.count()).select_from(Question))
    api = make_api(ai)
    generated(api, begin(api, "STATE_PSC", topic))
    assert db_session.scalar(select(func.count()).select_from(Question)) == before
