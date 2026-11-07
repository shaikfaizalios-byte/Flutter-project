"""The stricter ladder: working is recalculated, solves must all agree, hard levels stay off
until the benchmark passes, and a question nobody could check gives way to a reviewed one."""

import json
from pathlib import Path
from typing import Any

import pytest
from fastapi.testclient import TestClient
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.domain import challenge_ladder as ladder
from app.domain import ladder_rules, recompute
from app.domain.exam_format import SectionMarking
from app.domain.recompute import UnreadableError
from app.models.ai import AIGeneration
from app.models.exam import Exam
from app.models.ladder import GeneratedReview, LadderBenchmarkRun, LadderGate
from app.models.library import LibraryEntry
from app.models.question import ExamFormat, FormatStatus, Question, QuestionOption, Topic
from app.models.syllabus import SyllabusNode, SyllabusVersion
from app.models.user import User
from app.services.ladder_benchmark import BenchItem, read_items, run, subject_open
from app.services.ladder_exam import exam_context
from tests.conftest import auth_headers, make_user
from tests.fakes import FakeAIProvider
from tests.test_ai import AppFactory, ai, make_api
from tests.test_ladder import SESSIONS, fresh_question, solved
from tests.test_practice import document

__all__ = ["ai", "document", "make_api"]  # fixtures re-used from other test modules

EXAM = "NEET_UG"
SPEED = {
    "kind": "numeric",
    "given": [
        {"name": "d", "value": "100", "unit": "m"},
        {"name": "t", "value": "20", "unit": "s"},
    ],
    "formula": "speed = distance / time",
    "steps": ["Divide"],
    "expression": "d/t",
    "unit": "m/s",
}


def check(**changes: Any) -> recompute.Recheck:
    values: dict[str, Any] = {
        "format_name": "single_correct",
        "options": ["2 m/s", "5 m/s", "10 m/s", "20 m/s"],
        "answer_index": 1,
        "spec": None,
        "structured": SPEED,
        "tolerance": 0.005,
    }
    return recompute.recheck(**(values | changes))


# --- recalculating ----------------------------------------------------------------------------


def test_the_stated_working_gives_the_answer_in_the_stated_unit() -> None:
    assert recompute.recalculated(SPEED) == pytest.approx(5)
    assert recompute.recalculated(SPEED | {"unit": "km/h"}) == pytest.approx(18)


def test_units_that_cant_be_right_fail() -> None:
    with pytest.raises(UnreadableError):
        recompute.recalculated(SPEED | {"unit": "kg"})


def test_force_comes_out_in_newtons() -> None:
    structured = {
        "given": [
            {"name": "m", "value": "2", "unit": "kg"},
            {"name": "a", "value": "3", "unit": "m/s^2"},
        ],
        "expression": "m*a",
        "unit": "N",
    }
    assert recompute.recalculated(structured) == pytest.approx(6)


def test_angles_need_their_unit() -> None:
    structured = {
        "given": [{"name": "x", "value": "30", "unit": "deg"}],
        "expression": "sin(x)",
    }
    assert recompute.recalculated(structured) == pytest.approx(0.5)


@pytest.mark.parametrize(
    "expression",
    [
        "__import__('os').system('echo hi')",
        "().__class__",
        "open('secret')",
        "d.__class__",
        "lambda: 1",
        "[d for d in (1,)]",
        "unknown_name * 2",
        "2 ** 100000",
        "d" * 400,
    ],
)
def test_ai_text_is_never_run_as_code(expression: str) -> None:
    with pytest.raises(UnreadableError):
        recompute.recalculated(SPEED | {"expression": expression})


def test_a_key_the_working_doesnt_give_fails() -> None:
    assert check().problem is None
    assert check().recalculated is True
    assert check(answer_index=0).problem == "recalculated_differs"


def test_two_options_with_the_answer_fail() -> None:
    assert check(options=["5", "5.0", "10", "20"]).problem == "recalculated_differs"


def test_calling_a_sum_reasoning_avoids_nothing() -> None:
    assert check(structured={"kind": "reasoning"}).problem == "unreadable"


def test_a_question_of_words_has_nothing_to_recalculate() -> None:
    outcome = check(
        options=["Mitosis", "Meiosis", "Budding", "Fission"], structured={"kind": "fact_recall"}
    )
    assert outcome == recompute.Recheck(None, False)


def test_a_typed_answer_follows_the_rounding_rule() -> None:
    structured = SPEED | {"expression": "d/t/3", "unit": "m/s", "decimals": 2}
    spec = {"value": "1.67", "tolerance": "0"}
    outcome = check(
        format_name="numeric", options=[], answer_index=None, spec=spec, structured=structured
    )
    assert outcome.problem is None
    wrong = {"value": "1.66", "tolerance": "0"}
    outcome = check(
        format_name="numeric", options=[], answer_index=None, spec=wrong, structured=structured
    )
    assert outcome.problem == "recalculated_differs"


def test_formulas_are_compared_by_value() -> None:
    structured = {
        "kind": "symbolic",
        "symbols": ["m", "v"],
        "expression": "m*v^2/2",
        "option_expressions": ["m*v", "0.5*m*v*v", "m*v^2", "2*m*v"],
    }
    options = ["mv", "mv²/2", "mv²", "2mv"]
    assert check(options=options, answer_index=1, structured=structured).problem is None
    assert (
        check(options=options, answer_index=0, structured=structured).problem
        == "recalculated_differs"
    )


@pytest.mark.parametrize(
    ("text", "number"),
    [
        ("5 m/s", 5),
        ("$3 \\times 10^{8}$ m/s", 3e8),
        ("2.5\u00d710^-3 kg", 2.5e-3),
        ("1/2", 0.5),
        ("-4 J", -4),
        ("None of these", None),
    ],
)
def test_numbers_are_read_as_papers_print_them(text: str, number: float | None) -> None:
    assert recompute.number_in(text) == number


# --- rules ------------------------------------------------------------------------------------


def test_each_exam_has_its_own_formats_and_levels() -> None:
    main = ladder_rules.rules_for("JEE_MAIN")
    advanced = ladder_rules.rules_for("JEE_ADVANCED")
    neet = ladder_rules.rules_for("NEET_UG")
    assert main is not None and advanced is not None and neet is not None
    assert main.formats == ("single_correct", "numeric")
    assert advanced.formats == ("multiple_correct", "numeric", "match", "paragraph")
    assert neet.formats == ("single_correct", "assertion_reason", "statement")
    assert "JEE Advanced" in main.anchors["extreme_hard"]
    assert "inside the NEET syllabus" in neet.anchors["extreme_hard"]
    assert ladder_rules.rules_for("SSC_CHSL") is None


@pytest.mark.parametrize(
    ("level", "kind", "needed"),
    [
        ("easy", "numeric", 1),
        ("easy", "fact_recall", 2),
        ("medium", "numeric", 2),
        ("hard", "numeric", 3),
        ("extreme_hard", "fact_recall", 3),
    ],
)
def test_harder_questions_need_more_solves(level: str, kind: str, needed: int) -> None:
    assert ladder_rules.solves_needed(level, kind) == needed


def test_the_gate_needs_a_threshold_and_enough_accepted_items() -> None:
    assert ladder_rules.gate_open(100, 100, None) is False
    assert ladder_rules.gate_open(19, 19, 0.9) is False
    assert ladder_rules.gate_open(20, 17, 0.9) is False
    assert ladder_rules.gate_open(20, 18, 0.9) is True


# --- the prompt -------------------------------------------------------------------------------


def context(**changes: Any) -> ladder.ExamContext:
    values: dict[str, Any] = {
        "name": "Sample",
        "stage": None,
        "next_stage": None,
        "formats": ("single_correct",),
        "options": 4,
        "marking": None,
        "base_time_seconds": 60,
    }
    return ladder.ExamContext(**(values | changes))


def prompt_for(exam: ladder.ExamContext) -> str:
    return ladder.generator_prompt(
        exam=exam,
        topic="Motion",
        round_number=1,
        plan=ladder.plan_round([], 1),
        number=1,
        seeds=[],
        web=[],
        avoid=[],
        missed=[],
        language="en",
    )


def test_the_ordinary_ladder_keeps_its_prompt() -> None:
    assert "STRUCTURED SOLUTION" not in prompt_for(context())


def test_a_strict_exam_states_its_levels_and_asks_for_working() -> None:
    prompt = prompt_for(context(strict=True, anchors={"hard": "The toughest level here."}))
    assert "- Hard: The toughest level here." in prompt
    assert "STRUCTURED SOLUTION" in prompt
    assert "{{" not in prompt


def written(**fields: Any) -> dict[str, Any]:
    return {
        "question": "What is the speed?",
        "options": ["2 m/s", "5 m/s", "10 m/s", "20 m/s"],
        "answer_index": 1,
        "solution": "Divide",
        "shortcut": "",
        "structured": SPEED,
    } | fields


def test_a_strict_question_needs_its_working() -> None:
    exam = context(strict=True)
    data = written()
    del data["structured"]
    assert ladder.validate_generated(data, exam, "easy") is None
    assert ladder.validate_generated(written(), exam, "easy") is not None


def test_a_paragraph_question_keeps_its_passage_in_the_text() -> None:
    exam = context(strict=True, formats=("paragraph",))
    assert ladder.validate_generated(written(format="paragraph"), exam, "easy") is None
    question = ladder.validate_generated(
        written(format="paragraph", passage="A train runs."), exam, "easy"
    )
    assert question is not None
    assert question.format == "single_correct"
    assert question.stem.startswith("A train runs.")


# --- a round ----------------------------------------------------------------------------------


@pytest.fixture
def topic(db_session: Session, user: User) -> Topic:
    row = Topic(subject="Physics", name="Strict motion", keywords=[], exam_codes=[EXAM])
    db_session.add(row)
    db_session.flush()
    return row


def begin(api: TestClient, topic: Topic) -> str:
    response = api.post(
        SESSIONS,
        json={"exam_code": EXAM, "topic_id": str(topic.id), "include_new_formats": True},
    )
    assert response.status_code == 201, response.text
    session_id: str = response.json()["session_id"]
    return session_id


def generate(api: TestClient, session_id: str, step: int) -> Any:
    return api.post(f"{SESSIONS}/{session_id}/rounds/1/steps/{step}/generate")


def strict_question(**changes: Any) -> dict[str, Any]:
    base = fresh_question()
    return base | written(question=base["question"]) | changes


def open_subject(db: Session) -> None:
    db.add(LadderGate(exam_code=EXAM, subject="Physics", threshold=0.9, set_by="Owner"))
    db.flush()
    run(
        db,
        FakeAIProvider(
            responses=[
                reply
                for _ in range(20)
                for reply in (
                    {"answer_index": 1, "solution": "Divide", "structured": SPEED},
                    solved(),
                    solved(),
                    solved(),
                )
            ]
        ),
        EXAM,
        [BENCH] * 20,
    )


BENCH = BenchItem(
    subject="Physics",
    format="single_correct",
    level="hard",
    stem="What is the speed?",
    options=("2 m/s", "5 m/s", "10 m/s", "20 m/s"),
    key={"answer_index": 1},
)


def library_question(db: Session, topic: Topic, level: str, **changes: Any) -> Question:
    owner = make_user(db, f"editor-{level}-{len(db.scalars(select(User)).all())}@example.com")
    question = Question(
        origin="library",
        owner_id=owner.id,
        exam_code=EXAM,
        stem="A reviewed library question?",
        language="en",
        subject=topic.subject,
        topic_id=topic.id,
        correct_option_position=2,
        verification_status="verified",
    )
    question.options = [
        QuestionOption(position=i, label=str(i), text=f"option {i}") for i in range(1, 5)
    ]
    db.add(question)
    db.flush()
    values: dict[str, Any] = {
        "question_id": question.id,
        "source_type": "original_expert",
        "rights_status": "owned",
        "author_id": owner.id,
        "author_name": owner.email,
        "status": "approved",
        "difficulty": level,
    }
    db.add(LibraryEntry(**(values | changes)))
    db.flush()
    return question


def test_a_step_passes_with_its_working_and_enough_solves(
    make_api: AppFactory, ai: FakeAIProvider, topic: Topic, document: Any
) -> None:
    api = make_api(ai)
    session_id = begin(api, topic)
    ai.web_hits = [_hit()]
    ai.responses += [strict_question(), solved()]
    ok = generate(api, session_id, 1).json()  # easy: one solve
    assert ok["source"] == "ai"
    assert ok["checks"] == {"solves": 1, "recalculated": True}


def test_a_wrong_key_is_caught_before_any_solve(
    make_api: AppFactory,
    ai: FakeAIProvider,
    topic: Topic,
    db_session: Session,
) -> None:
    api = make_api(ai)
    session_id = begin(api, topic)
    library_question(db_session, topic, "easy")
    ai.web_hits = [_hit()]
    ai.responses += [strict_question(answer_index=0) for _ in range(3)]
    step = generate(api, session_id, 1).json()
    assert step["source"] == "library"
    assert ai.responses == []
    assert not any("You solve" in call.system for call in ai.calls)


def _hit() -> Any:
    from app.integrations.ai import WebSearchHit

    return WebSearchHit(title="Ref", url="https://example.com", snippet="Speed sums")


def test_a_gated_level_uses_the_library_with_no_ai_call(
    make_api: AppFactory,
    ai: FakeAIProvider,
    topic: Topic,
    db_session: Session,
) -> None:
    api = make_api(ai)
    session_id = begin(api, topic)
    question = library_question(db_session, topic, "hard")
    step = generate(api, session_id, 4).json()  # hard, and the subject isn't switched on
    assert step["source"] == "library"
    assert step["stem"] == question.stem
    assert ai.calls == []


def test_a_gated_level_without_a_library_question_says_so(
    make_api: AppFactory, ai: FakeAIProvider, topic: Topic
) -> None:
    api = make_api(ai)
    session_id = begin(api, topic)
    assert generate(api, session_id, 4).status_code == 502
    assert ai.calls == []


def test_hard_needs_three_solves_and_any_disagreement_discards(
    make_api: AppFactory,
    ai: FakeAIProvider,
    topic: Topic,
    db_session: Session,
) -> None:
    open_subject(db_session)
    assert subject_open(db_session, EXAM, "Physics") is True
    api = make_api(ai)
    session_id = begin(api, topic)
    library_question(db_session, topic, "hard")
    ai.web_hits = [_hit()]
    ai.responses += [
        strict_question(),
        solved(),
        solved(),
        solved(0),  # the third disagrees
        strict_question(),
        solved(0),
        strict_question(),
        solved(0),
    ]
    assert generate(api, session_id, 4).json()["source"] == "library"


def test_extreme_hard_shows_and_waits_for_a_person(
    make_api: AppFactory,
    ai: FakeAIProvider,
    topic: Topic,
    db_session: Session,
) -> None:
    open_subject(db_session)
    api = make_api(ai)
    session_id = begin(api, topic)
    ai.web_hits = [_hit()]
    ai.responses += [strict_question(), solved(), solved(), solved()]
    step = generate(api, session_id, 5).json()
    assert step["source"] == "ai"
    review = db_session.scalar(select(GeneratedReview))
    assert review is not None
    assert review.status == "pending"
    assert review.difficulty == "extreme_hard"
    assert db_session.scalar(select(LibraryEntry)) is None


def test_a_person_turns_a_generated_question_into_a_draft(
    make_api: AppFactory,
    ai: FakeAIProvider,
    topic: Topic,
    db_session: Session,
) -> None:
    db_session.add(
        GeneratedReview(
            exam_code=EXAM,
            subject="Physics",
            topic_id=topic.id,
            topic_name=topic.name,
            difficulty="extreme_hard",
            format="single_correct",
            stem="A generated question?",
            options=["a", "b", "c", "d"],
            answer_index=2,
            solution=["Because"],
        )
    )
    db_session.flush()
    api = make_api(ai)
    assert api.get("/api/v1/library/generated").status_code == 403
    editor = make_user(db_session, "editor@example.com")
    editor.content_role = "editor"
    db_session.flush()
    api.headers.update(auth_headers(editor))
    rows = api.get("/api/v1/library/generated").json()
    assert rows[0]["stem"] == "A generated question?"

    entry = api.post(f"/api/v1/library/generated/{rows[0]['id']}/accept")
    assert entry.status_code == 200, entry.text
    data = entry.json()
    assert data["status"] == "draft"
    assert data["rights_status"] == "pending"
    assert data["source_type"] == "original_ai_verified"
    assert data["difficulty"] == "hard"
    assert api.get("/api/v1/library/generated").json() == []
    question = db_session.get(Question, data["question_id"])
    assert question is not None
    assert question.correct_option_position == 3


def test_the_library_stand_in_comes_from_the_same_chapter_and_level(
    make_api: AppFactory,
    ai: FakeAIProvider,
    topic: Topic,
    db_session: Session,
) -> None:
    other = Topic(subject="Physics", name="Strict waves", keywords=[], exam_codes=[EXAM])
    sibling = Topic(subject="Physics", name="Strict speed", keywords=[], exam_codes=[EXAM])
    db_session.add_all([other, sibling])
    db_session.flush()
    version = SyllabusVersion(
        exam_code=EXAM, name="List", effective_year=2099, source_kind="manual"
    )
    db_session.add(version)
    db_session.flush()
    root = SyllabusNode(version_id=version.id, position=1, name="Physics")
    db_session.add(root)
    db_session.flush()
    for position, (unit, members) in enumerate(
        (("Kinematics", [topic, sibling]), ("Waves", [other]))
    ):
        node = SyllabusNode(version_id=version.id, parent_id=root.id, position=position, name=unit)
        db_session.add(node)
        db_session.flush()
        for i, member in enumerate(members):
            db_session.add(
                SyllabusNode(
                    version_id=version.id,
                    parent_id=node.id,
                    position=i,
                    name=member.name,
                    topic_id=member.id,
                )
            )
    db_session.flush()
    library_question(db_session, other, "hard")  # another chapter
    library_question(db_session, topic, "easy")  # another level
    wanted = library_question(db_session, sibling, "hard")
    library_question(db_session, topic, "hard", rights_status="pending")  # not shown to learners
    api = make_api(ai)
    session_id = begin(api, topic)
    step = generate(api, session_id, 4).json()
    assert step["source"] == "library"
    answered = api.post(
        f"{SESSIONS}/{session_id}/rounds/1/steps/4/answer", json={"selected_index": 1}
    ).json()
    assert answered["result"]["correct"] is True
    row = db_session.scalar(select(Question).where(Question.id == wanted.id))
    assert row is not None


def test_marks_follow_the_questions_format(
    db_session: Session,
    topic: Topic,
) -> None:
    code = EXAM
    sections = [
        {
            "part": "A",
            "subject": "Physics",
            "questions": 20,
            "max_marks": 80,
            "marks_wrong": 1,
            "formats": ["single_correct"],
        },
        {
            "part": "B",
            "subject": "Physics",
            "questions": 5,
            "max_marks": 20,
            "marks_wrong": 0,
            "formats": ["numeric"],
        },
    ]
    from datetime import date

    db_session.add(
        ExamFormat(
            code="STRICT_TEST",
            exam_code=code,
            stage="Paper",
            name="Paper",
            sections=sections,
            sections_in_fixed_order=False,
            total_questions=25,
            duration_minutes=60,
            negative_marks_per_wrong=1,
            question_types=["choice", "numeric"],
            source_title="Notice",
            source_url="https://example.com",
            source_reference="para 1",
            source_published_on=date(2026, 1, 1),
            verified_on=date(2026, 1, 2),
            reviewed_by="A. Reviewer",
            status=FormatStatus.VERIFIED,
        )
    )
    db_session.flush()
    exam = db_session.get(Exam, code)
    assert exam is not None
    built = exam_context(
        db_session,
        exam,
        subject="Physics",
        topic_id=topic.id,
        new_formats=True,
        today=date(2026, 6, 1),
    )
    assert built.strict is True
    choice = built.marking_for("single_correct")
    typed = built.marking_for("numeric")
    assert isinstance(choice, SectionMarking) and isinstance(typed, SectionMarking)
    assert (choice.marks_correct, choice.marks_wrong) == (4, 1)
    assert (typed.marks_correct, typed.marks_wrong) == (4, 0)


def test_ordinary_exams_keep_one_solve(
    make_api: AppFactory,
    ai: FakeAIProvider,
    db_session: Session,
    user: User,
) -> None:
    exam = db_session.get(Exam, "SSC_CHSL")
    assert exam is not None
    built = exam_context(
        db_session,
        exam,
        subject="Quantitative Aptitude",
        topic_id=None,
        new_formats=True,
        today=__import__("datetime").date(2026, 6, 1),
    )
    assert built.strict is False
    assert built.anchors is None


# --- the benchmark ----------------------------------------------------------------------------


def test_the_benchmark_keeps_totals_and_never_a_question(db_session: Session) -> None:
    provider = FakeAIProvider(
        responses=[
            {"answer_index": 1, "solution": "Divide", "structured": SPEED},
            solved(),
            solved(),
            solved(),
            # Accepted, but the known answer is another option.
            {"answer_index": 1, "solution": "Divide", "structured": SPEED},
            solved(),
            solved(),
            solved(),
            # The working gives another option: refused.
            {"answer_index": 0, "solution": "Divide", "structured": SPEED},
        ]
    )
    wrong_key = BenchItem(
        subject="Physics",
        format="single_correct",
        level="hard",
        stem="Another",
        options=BENCH.options,
        key={"answer_index": 3},
    )
    rows = run(db_session, provider, EXAM, [BENCH, wrong_key, BENCH])
    assert [(r.items, r.accepted, r.correct) for r in rows] == [(3, 2, 1)]
    stored = db_session.scalars(select(LadderBenchmarkRun)).all()
    assert [(r.subject, r.format, r.items) for r in stored] == [("Physics", "single_correct", 3)]
    columns = {c.name for c in LadderBenchmarkRun.__table__.columns}
    assert not columns & {"stem", "options", "answer", "question"}
    assert all(
        row.task in ("ladder_question", "ladder_solve")
        for row in db_session.scalars(select(AIGeneration))
    )


def test_the_benchmark_file_is_read_with_its_known_answers(tmp_path: Path) -> None:
    path = tmp_path / "bench.json"
    path.write_text(
        json.dumps(
            [
                {
                    "subject": "Physics",
                    "format": "numeric",
                    "stem": "How far?",
                    "numeric_answer": "5",
                }
            ]
        ),
        encoding="utf-8",
    )
    items = read_items(json.loads(path.read_text(encoding="utf-8")))
    assert items[0].level == "hard"
    assert items[0].key == {"numeric_answer": "5"}


def test_a_subject_stays_off_without_a_threshold_or_a_passing_run(db_session: Session) -> None:
    assert subject_open(db_session, EXAM, "Physics") is False
    db_session.add(LadderGate(exam_code=EXAM, subject="Physics", threshold=0.9, set_by="Owner"))
    db_session.flush()
    assert subject_open(db_session, EXAM, "Physics") is False
    open_subject_rows = LadderBenchmarkRun(
        run_id=__import__("uuid").uuid4(),
        exam_code=EXAM,
        subject="Physics",
        format="single_correct",
        items=30,
        accepted=25,
        correct=20,
        model="m",
    )
    db_session.add(open_subject_rows)
    db_session.flush()
    assert subject_open(db_session, EXAM, "Physics") is False  # 80 % is below 90 %
