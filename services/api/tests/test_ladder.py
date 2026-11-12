"""Challenge Ladder: the plan, the question checks, and whole rounds through the API with a fake
AI. Acceptance: round order, no repeats, every question solved or real, repeat counts unchanged."""

import random
import uuid
from datetime import UTC, datetime, timedelta
from itertools import count
from typing import Any

import pytest
from fastapi.testclient import TestClient
from sqlalchemy import func, select
from sqlalchemy.orm import Session

from app.domain import challenge_ladder as ladder
from app.domain.similarity import stem_similarity
from app.integrations.ai import AIProviderError, WebSearchHit
from app.models.ai import AIGeneration
from app.models.document import Document, DocumentStatus
from app.models.ladder import LadderSession, LadderStep
from app.models.plus import Subscription
from app.models.question import Question, QuestionPattern, Topic, TopicStatus
from app.models.user import User
from app.services.insights_service import InsightsService
from tests.conftest import make_user
from tests.fakes import FakeAIProvider
from tests.test_ai import AppFactory, ai, make_api
from tests.test_practice import document, make_question
from tests.test_rag import other_document

__all__ = ["ai", "document", "make_api"]  # fixtures re-used from other test modules

SESSIONS = "/api/v1/ladder/sessions"
EXAM = "SSC_CHSL"
CONTEXT = ladder.ExamContext(
    name="Sample Exam",
    stage=None,
    next_stage=None,
    formats=("single_correct",),
    options=4,
    marking=None,
    base_time_seconds=36,
)

# --- the plan --------------------------------------------------------------------------------


def models(n: int) -> list[ladder.PlanModel]:
    return [ladder.PlanModel(f"M{i}", papers=9 - i, questions=20 - i) for i in range(n)]


def names(plan: tuple[ladder.PlannedStep, ...]) -> list[str | None]:
    return [s.model.name if s.model else None for s in plan]


def test_round_one_climbs_in_the_fixed_order_through_three_or_more_types() -> None:
    plan = ladder.plan_round(models(4), 1)
    assert [s.difficulty for s in plan] == ["easy", "easy", "medium", "hard", "extreme_hard"]
    assert names(plan) == ["M0", "M1", "M2", "M3", "M0"]  # most repeated first, rarer later
    assert plan[4].second == models(4)[3]  # the last step combines two types
    assert len(set(names(ladder.plan_round(models(3), 1)))) == 3


def test_few_types_repeat_and_no_types_stay_topic_level() -> None:
    assert names(ladder.plan_round(models(2), 1)) == ["M0", "M1", "M0", "M1", "M0"]
    assert names(ladder.plan_round(models(1), 1)) == ["M0"] * 5
    assert ladder.plan_round(models(1), 1)[4].second is None
    assert names(ladder.plan_round([], 1)) == [None] * 5


def test_later_rounds_are_harder_and_start_from_what_was_missed() -> None:
    plan = ladder.plan_round(models(3), 2, {"M2": 2, "M1": 1})
    assert [s.difficulty for s in plan] == ["medium_hard", "medium_hard", "hard", "hard", "hard"]
    assert names(plan)[:3] == ["M2", "M1", "M0"]


def seed(id_: int, paper: str) -> ladder.Seed:
    return ladder.Seed(id=id_, stem=f"Q{id_}", options=(), paper_id=paper, paper=paper)


def test_seeds_prefer_worded_alike_questions_from_different_papers() -> None:
    seeds = [seed(1, "A"), seed(2, "A"), seed(3, "B"), seed(4, "C"), seed(5, "D")]
    assert [s.id for s in ladder.pick_seeds(seeds, {3, 4})] == [3, 4, 1]
    assert [s.id for s in ladder.pick_seeds(seeds[:2], set())] == [1, 2]  # same paper: still used


def test_a_ladder_is_climbed_only_up_to_the_first_miss() -> None:
    assert ladder.climbed([(1, True), (2, True), (3, False), (4, True)]) == 2
    assert ladder.climbed([(1, False), (2, True)]) == 0
    assert ladder.climbed([(2, True), (1, True), (3, None)]) == 2


# --- the checks ------------------------------------------------------------------------------


def written(
    stem: str = "A train runs 120 km in 2 hours. What is its speed?", **changes: Any
) -> dict[str, Any]:
    data: dict[str, Any] = {
        "step": 1,
        "difficulty": "easy",
        "model": "Any",
        "basis": "papers",
        "question": stem,
        "options": ["40 km/h", "60 km/h", "80 km/h", "100 km/h"],
        "answer_index": 1,
        "solution": "120 km in 2 hours\n120 / 2 = 60",
        "shortcut": "",
    }
    return data | changes


@pytest.mark.parametrize(
    "changes",
    [
        {"options": ["1", "2", "3"]},
        {"options": ["1", "2", "3", "3"]},
        {"options": ["1", "2", "3", " 3 "]},
        {"answer_index": 4},
        {"answer_index": -1},
        {"answer_index": True},
        {"solution": ""},
        {"solution": "  \n "},
        {"question": " "},
    ],
)
def test_structure_is_checked(changes: dict[str, Any]) -> None:
    assert ladder.validate_generated(written(**changes), CONTEXT, "easy") is None


def test_a_good_question_passes_and_its_time_comes_from_the_exam() -> None:
    question = ladder.validate_generated(written(time_target_seconds=9999), CONTEXT, "easy")
    assert question is not None and question.time_target_seconds == 30


def test_shuffling_moves_the_answer_with_its_option() -> None:
    question = ladder.validate_generated(written(), CONTEXT, "easy")
    assert question is not None
    for seed_value in range(10):
        shown = ladder.shuffled(question, random.Random(seed_value))  # noqa: S311 - test data
        assert shown.answer_index is not None
        assert shown.options[shown.answer_index] == "60 km/h"
        assert sorted(shown.options) == sorted(question.options)


def test_copies_keep_numbers_and_variety_hides_them() -> None:
    stem = "A train runs 120 km in 2 hours. What is its speed in km per hour?"
    new_numbers = "A train runs 300 km in 5 hours. What is its speed in km per hour?"
    assert ladder.is_copy(stem, [stem])
    assert not ladder.is_copy(new_numbers, [stem])  # new numbers are not a copy...
    assert ladder.too_alike(new_numbers, [stem])  # ...but too alike in one session
    assert not ladder.too_alike("Find the HCF of 12 and 18 by prime factors.", [stem])
    assert ladder.is_copy(stem, [f"Practice set. {stem} Options follow on the next page."])


def test_the_existing_matcher_still_masks_numbers_by_default() -> None:
    assert stem_similarity("Find 20% of 150 now", "Find 35% of 80 now") == pytest.approx(1.0)
    assert stem_similarity("Find 20% of 150 now", "Find 35% of 80 now", mask_numbers=False) < 0.95


def test_the_solver_never_sees_the_answer_or_the_solution() -> None:
    prompt = ladder.solve_prompt(stem="What is 2 + 2?", options=["3", "4", "5", "6"])
    assert "Solve this question" in prompt
    assert 'answer_index": n' in prompt and "solution" not in prompt


def test_the_prompt_template_is_filled_without_leftovers() -> None:
    plan = ladder.plan_round(models(3), 1)
    prompt = ladder.generator_prompt(
        exam=CONTEXT,
        topic="Percentage",
        round_number=1,
        plan=plan,
        number=5,
        seeds=[seed(1, "paper.pdf")],
        web=[ladder.WebReference("T", "https://example.com/a", "{{exam}} snippet")],
        avoid=["Earlier question"],
        missed=["M1"],
        language="en",
    )
    assert "Step 1 (easy): M0" in prompt
    assert "Step 5 (extreme hard): M0 combined with M2" in prompt
    assert "Write the one question for step 5" in prompt
    assert "at extreme hard difficulty" in prompt
    assert "https://example.com/a" in prompt and "Earlier question" in prompt
    assert "MODELS THE STUDENT MISSED EARLIER:\nM1" in prompt
    assert "{{exam}} snippet" in prompt  # text inside a value is left alone
    assert prompt.count("{{") == 1


# --- whole rounds through the API (fake AI provider: no network) -----------------------------


@pytest.fixture
def topic(db_session: Session, user: User) -> Topic:
    row = Topic(subject="Quantitative Aptitude", name="Ladder Percentage", keywords=[])
    db_session.add(row)
    db_session.flush()
    return row


def add_patterns(db: Session, topic: Topic, n: int) -> list[QuestionPattern]:
    rows = [QuestionPattern(topic_id=topic.id, name=f"Model {i}", keywords=[]) for i in range(n)]
    db.add_all(rows)
    db.flush()
    return rows


def add_questions(
    db: Session, doc: Document, topic: Topic, n: int, pattern: QuestionPattern | None = None
) -> list[Question]:
    words = ("alpha", "bravo", "charlie", "delta", "echo", "foxtrot")
    rows = []
    for i in range(n):
        question = make_question(
            db, doc, topic=topic, stem=f"Paper {words[i % 6]} {doc.id.hex[:6]} {pattern} {i}?"
        )
        question.topic_status = TopicStatus.CONFIRMED
        if pattern is not None:
            question.pattern_id = pattern.id
            question.pattern_status = TopicStatus.CONFIRMED
        rows.append(question)
    db.flush()
    return rows


_unique = count(1)


def fresh_question(**changes: Any) -> dict[str, Any]:
    """A question the checks accept, unlike any other (different words each time)."""
    n = next(_unique)
    # Letters, not digits: the variety check hides numbers.
    words = " ".join(f"{chr(97 + n % 26)}{chr(97 + n // 26 % 26)}{chr(97 + i)}" for i in range(8))
    return written(stem=f"Question {words} here?", **changes)


def solved(index: int = 1) -> dict[str, Any]:
    return {"answer_index": index, "working": "..."}


def script_round(ai: FakeAIProvider, steps: int = 5) -> None:
    for _ in range(steps):
        ai.responses += [fresh_question(), solved()]


def start(api: TestClient, topic: Topic) -> dict[str, Any]:
    response = api.post(SESSIONS, json={"exam_code": EXAM, "topic_id": str(topic.id)})
    assert response.status_code == 201, response.text
    data: dict[str, Any] = response.json()
    return data


def generate_all(api: TestClient, body: dict[str, Any]) -> list[dict[str, Any]]:
    base = f"{SESSIONS}/{body['session_id']}/rounds/{body['round_number']}/steps"
    steps = []
    for number in range(1, 6):
        response = api.post(f"{base}/{number}/generate")
        assert response.status_code == 200, response.text
        steps.append(response.json())
    return steps


def answer(api: TestClient, body: dict[str, Any], step: int, index: int) -> dict[str, Any]:
    response = api.post(
        f"{SESSIONS}/{body['session_id']}/rounds/{body['round_number']}/steps/{step}/answer",
        json={"selected_index": index, "time_spent_ms": 12000},
    )
    assert response.status_code == 200, response.text
    data: dict[str, Any] = response.json()
    return data


def test_a_round_from_start_to_answers_never_shows_the_key_early(
    make_api: AppFactory,
    ai: FakeAIProvider,
    db_session: Session,
    document: Document,
    topic: Topic,
) -> None:
    patterns = add_patterns(db_session, topic, 3)
    add_questions(db_session, document, topic, 3, patterns[0])
    ai.web_hits = [WebSearchHit("Guide", "https://example.com/g", "Percent basics")]
    script_round(ai)
    api = make_api(ai)

    body = start(api, topic)
    assert body["source_mix"] == "papers"
    assert [s["difficulty"] for s in body["steps"]] == list(ladder.FIRST_ROUND)
    assert not any(s["ready"] for s in body["steps"])
    assert ai.calls == []  # planning needs no AI

    steps = generate_all(api, body)
    assert all(s["ready"] and s["source"] == "ai" and s["result"] is None for s in steps)
    assert "answer_index" not in steps[0] and "solution" not in steps[0]
    assert len({s["stem"] for s in steps}) == 5
    assert steps[0]["basis_papers"] == 1 and steps[0]["basis_web"] is True
    assert len(ai.searches) == 1  # once per session
    assert "questions" in ai.searches[0] and "Ladder Percentage" in ai.searches[0]
    # Every question met an independent solve that saw neither its key nor its solution.
    solves = [c for c in ai.calls if c.system == ladder.SOLVE_SYSTEM]
    assert len(solves) == 5
    assert "120 / 2" not in solves[0].prompt

    row = db_session.get(LadderStep, (uuid.UUID(body["session_id"]), 1, 1))
    assert row is not None and row.options is not None and row.answer_index is not None
    assert row.options[row.answer_index] == "60 km/h"  # shuffled, and the key followed
    result = answer(api, body, 1, row.answer_index)["result"]
    assert result["correct"] is True and result["solution"] == ["120 km in 2 hours", "120 / 2 = 60"]
    wrong = (row.answer_index + 1) % 4
    assert answer(api, body, 1, wrong)["result"]["correct"] is True  # the first answer is final


def test_a_wrong_key_regenerates_then_a_real_question_takes_the_step(
    make_api: AppFactory,
    ai: FakeAIProvider,
    db_session: Session,
    document: Document,
    topic: Topic,
) -> None:
    add_questions(db_session, document, topic, 3)
    ai.responses = [fresh_question(), solved(0), fresh_question(), solved(2)]
    ai.responses += [fresh_question(), solved(3)]
    api = make_api(ai)
    body = start(api, topic)

    step = api.post(f"{SESSIONS}/{body['session_id']}/rounds/1/steps/1/generate").json()

    assert step["source"] == "paper"
    assert step["paper_label"] == document.original_filename
    assert ai.responses == []  # three tries in all: the first and two regenerations
    assert step["stem"].startswith("Paper")


def test_a_key_that_holds_on_the_second_try_is_used(
    make_api: AppFactory,
    ai: FakeAIProvider,
    db_session: Session,
    document: Document,
    topic: Topic,
) -> None:
    add_questions(db_session, document, topic, 3)
    ai.responses = [fresh_question(), solved(0), fresh_question(), solved()]
    api = make_api(ai)
    body = start(api, topic)

    step = api.post(f"{SESSIONS}/{body['session_id']}/rounds/1/steps/1/generate").json()

    assert step["source"] == "ai"
    outcomes = db_session.scalars(
        select(AIGeneration.detail).where(AIGeneration.task == "ladder_solve")
    ).all()
    assert sorted(outcomes) == ["agrees", "key_disagrees"]


def test_invalid_output_is_retried_once_and_copies_are_rejected(
    make_api: AppFactory,
    ai: FakeAIProvider,
    db_session: Session,
    document: Document,
    topic: Topic,
) -> None:
    paper = add_questions(db_session, document, topic, 3)[0]
    ai.responses = [
        {"question": "broken"},
        written(stem=paper.stem),  # a copy of a paper question
        fresh_question(),
        solved(),
    ]
    api = make_api(ai)
    body = start(api, topic)

    step = api.post(f"{SESSIONS}/{body['session_id']}/rounds/1/steps/1/generate").json()

    assert step["source"] == "ai" and step["stem"] != paper.stem


def test_a_question_like_an_earlier_one_in_the_session_is_rejected(
    make_api: AppFactory,
    ai: FakeAIProvider,
    db_session: Session,
    document: Document,
    topic: Topic,
) -> None:
    add_questions(db_session, document, topic, 3)
    first = "A shop sells a pen for 120 rupees at a profit of 20 percent always."
    twin = "A shop sells a pen for 450 rupees at a profit of 15 percent always."
    ai.responses = [written(stem=first), solved(), written(stem=twin), fresh_question(), solved()]
    api = make_api(ai)
    body = start(api, topic)
    base = f"{SESSIONS}/{body['session_id']}/rounds/1/steps"

    api.post(f"{base}/1/generate")
    second = api.post(f"{base}/2/generate").json()

    assert second["stem"] != twin


def test_when_the_ai_fails_a_real_question_fills_the_step_and_is_not_reused(
    make_api: AppFactory,
    ai: FakeAIProvider,
    db_session: Session,
    document: Document,
    topic: Topic,
) -> None:
    add_questions(db_session, document, topic, 2)
    ai.responses = [AIProviderError("timeout"), AIProviderError("timeout")]
    ai.responses += [AIProviderError("timeout")]
    api = make_api(ai)
    body = start(api, topic)
    base = f"{SESSIONS}/{body['session_id']}/rounds/1/steps"

    one, two = api.post(f"{base}/1/generate").json(), api.post(f"{base}/2/generate").json()
    assert (one["source"], two["source"]) == ("paper", "paper")
    assert one["stem"] != two["stem"]
    assert api.post(f"{base}/3/generate").status_code == 502  # no real question left


def test_generating_a_ready_step_again_costs_nothing(
    make_api: AppFactory,
    ai: FakeAIProvider,
    db_session: Session,
    document: Document,
    topic: Topic,
) -> None:
    add_questions(db_session, document, topic, 3)
    script_round(ai, 1)
    api = make_api(ai)
    body = start(api, topic)
    url = f"{SESSIONS}/{body['session_id']}/rounds/1/steps/1/generate"

    first = api.post(url).json()
    calls = len(ai.calls)
    assert api.post(url).json() == first
    assert len(ai.calls) == calls


def test_a_topic_with_no_papers_uses_the_web_and_a_failed_search_stops_it(
    make_api: AppFactory, ai: FakeAIProvider, db_session: Session, user: User, topic: Topic
) -> None:
    ai.web_hits = [WebSearchHit("Guide", "https://example.com/g", "Percent basics")]
    script_round(ai, 1)
    api = make_api(ai)
    body = start(api, topic)
    assert body["source_mix"] == "web_only"
    step = api.post(f"{SESSIONS}/{body['session_id']}/rounds/1/steps/1/generate").json()
    assert (step["basis_papers"], step["basis_web"]) == (0, True)
    assert "no papers on this topic" in ai.calls[0].prompt

    ai.web_hits = AIProviderError("connection")
    body = start(api, topic)
    response = api.post(f"{SESSIONS}/{body['session_id']}/rounds/1/steps/1/generate")
    assert response.status_code == 502


def test_a_failed_search_continues_with_papers_only(
    make_api: AppFactory,
    ai: FakeAIProvider,
    db_session: Session,
    document: Document,
    topic: Topic,
) -> None:
    add_questions(db_session, document, topic, 3)
    ai.web_hits = AIProviderError("connection")
    script_round(ai, 1)
    api = make_api(ai)
    body = start(api, topic)

    step = api.post(f"{SESSIONS}/{body['session_id']}/rounds/1/steps/1/generate").json()

    assert step["source"] == "ai" and step["basis_web"] is False


def finish_round(api: TestClient, db: Session, body: dict[str, Any], *, right: bool) -> None:
    session_id = uuid.UUID(body["session_id"])
    for number in range(1, 6):
        row = db.get(LadderStep, (session_id, body["round_number"], number))
        assert row is not None and row.answer_index is not None
        answer(api, body, number, row.answer_index if right else (row.answer_index + 1) % 4)


def test_test_me_more_is_harder_never_repeats_and_targets_misses(
    make_api: AppFactory,
    ai: FakeAIProvider,
    db_session: Session,
    document: Document,
    topic: Topic,
) -> None:
    patterns = add_patterns(db_session, topic, 3)
    add_questions(db_session, document, topic, 3, patterns[0])
    script_round(ai)
    api = make_api(ai)
    body = start(api, topic)
    first = generate_all(api, body)

    too_soon = api.post(f"{SESSIONS}/{body['session_id']}/rounds")
    assert too_soon.status_code == 409
    finish_round(api, db_session, body, right=False)

    script_round(ai)
    response = api.post(f"{SESSIONS}/{body['session_id']}/rounds")
    assert response.status_code == 201, response.text
    second_body = response.json()
    assert second_body["round_number"] == 2
    assert [s["difficulty"] for s in second_body["steps"]] == list(ladder.LATER_ROUND)
    second = generate_all(api, second_body)
    assert not {s["stem"] for s in first} & {s["stem"] for s in second}
    # Round 1's stems are on the list the generator must avoid, and the misses are named.
    last_prompt = ai.calls[-2].prompt
    assert first[0]["stem"] in last_prompt
    assert "MODELS THE STUDENT MISSED EARLIER:\nModel 0" in last_prompt


def test_best_climb_and_topics_come_from_the_learners_own_data(
    make_api: AppFactory,
    ai: FakeAIProvider,
    db_session: Session,
    document: Document,
    topic: Topic,
) -> None:
    add_questions(db_session, document, topic, 3)
    script_round(ai)
    api = make_api(ai)
    before = api.get("/api/v1/ladder/overview", params={"exam": EXAM}).json()
    assert before["best"] is None
    assert before["topics"][0]["name"] == "Ladder Percentage"  # repeated topics come first
    assert before["topics"][0]["papers"] == 1
    assert any(t["papers"] == 0 for t in before["topics"])  # the rest of the syllabus follows

    body = start(api, topic)
    generate_all(api, body)
    finish_round(api, db_session, body, right=True)

    best = api.get("/api/v1/ladder/overview", params={"exam": EXAM}).json()["best"]
    assert best == {"step": 5, "topic_name": "Ladder Percentage"}


def test_generated_questions_never_reach_the_repeat_counts(
    make_api: AppFactory,
    ai: FakeAIProvider,
    db_session: Session,
    user: User,
    document: Document,
    topic: Topic,
) -> None:
    add_questions(db_session, document, topic, 3)
    questions_before = db_session.scalar(select(func.count()).select_from(Question))
    report_before = InsightsService(db_session, user.id).repeats(EXAM).model_dump()
    script_round(ai)
    api = make_api(ai)
    body = start(api, topic)
    generate_all(api, body)
    finish_round(api, db_session, body, right=False)

    assert db_session.scalar(select(func.count()).select_from(Question)) == questions_before
    assert InsightsService(db_session, user.id).repeats(EXAM).model_dump() == report_before


def test_another_accounts_ladder_and_papers_stay_out_of_reach(
    make_api: AppFactory,
    ai: FakeAIProvider,
    db_session: Session,
    document: Document,
    topic: Topic,
) -> None:
    stranger = make_user(db_session, "stranger@example.com")
    theirs = other_document(db_session, stranger)
    theirs.status = DocumentStatus.COMPLETED
    add_questions(db_session, theirs, topic, 3)
    add_questions(db_session, document, topic, 3)
    script_round(ai, 1)
    api = make_api(ai)
    body = start(api, topic)
    api.post(f"{SESSIONS}/{body['session_id']}/rounds/1/steps/1/generate")
    assert theirs.id.hex[:6] not in ai.calls[0].prompt  # never another account's questions

    assert api.get(f"{SESSIONS}/{uuid.uuid4()}/rounds/1").status_code == 404


def test_ai_off_says_so(make_api: AppFactory, db_session: Session, topic: Topic) -> None:
    response = make_api(None).post(SESSIONS, json={"exam_code": EXAM, "topic_id": str(topic.id)})
    assert response.status_code == 503
    assert response.json()["error"]["code"] == "ai_disabled"


# --- the free daily ladder ---------------------------------------------------------------------


def test_without_plus_one_free_ladder_a_day_of_one_round(
    make_api: AppFactory,
    ai: FakeAIProvider,
    db_session: Session,
    document: Document,
    topic: Topic,
    user: User,
) -> None:
    add_questions(db_session, document, topic, 3)
    script_round(ai)
    api = make_api(ai, plus_required_for_ai=True)
    overview = api.get("/api/v1/ladder/overview", params={"exam": EXAM}).json()
    assert overview["free_per_day"] == 1 and overview["free_left_today"] == 1

    body = start(api, topic)
    assert len(generate_all(api, body)) == 5  # the whole first round, without Plus
    left = api.get("/api/v1/ladder/overview", params={"exam": EXAM}).json()["free_left_today"]
    assert left == 0
    # A second ladder today, and a second round of the free one, need Plus.
    again = api.post(SESSIONS, json={"exam_code": EXAM, "topic_id": str(topic.id)})
    assert again.status_code == 403 and again.json()["error"]["code"] == "plus_required"
    more = api.post(f"{SESSIONS}/{body['session_id']}/rounds")
    assert more.status_code == 403 and more.json()["error"]["code"] == "plus_required"
    # Other AI features stay Plus-only.
    asked = api.post("/api/v1/ai/quick-answer", json={"query": "What is a ratio?"})
    assert asked.status_code == 403

    # Yesterday's free ladder doesn't count today.
    row = db_session.get(LadderSession, uuid.UUID(body["session_id"]))
    assert row is not None and row.free is True
    row.created_at = datetime.now(UTC) - timedelta(days=1, minutes=1)
    db_session.flush()
    assert start(api, topic)["round_number"] == 1


def test_free_ladders_can_be_switched_off_and_plus_needs_none(
    make_api: AppFactory,
    ai: FakeAIProvider,
    db_session: Session,
    document: Document,
    topic: Topic,
    user: User,
) -> None:
    add_questions(db_session, document, topic, 3)
    off = make_api(ai, plus_required_for_ai=True, ladder_free_per_day=0)
    refused = off.post(SESSIONS, json={"exam_code": EXAM, "topic_id": str(topic.id)})
    assert refused.status_code == 403
    assert off.get("/api/v1/ladder/overview", params={"exam": EXAM}).json()["free_left_today"] == 0

    db_session.add(
        Subscription(
            owner_id=user.id,
            plan="plus",
            source="operator",
            active_until=datetime.now(UTC) + timedelta(days=5),
        )
    )
    db_session.flush()
    api = make_api(ai, plus_required_for_ai=True)
    assert (
        api.get("/api/v1/ladder/overview", params={"exam": EXAM}).json()["free_left_today"] is None
    )
    first, second = start(api, topic), start(api, topic)  # Plus: not counted as free
    rows = db_session.scalars(select(LadderSession)).all()
    assert len(rows) == 2 and not any(r.free for r in rows)
    assert first["session_id"] != second["session_id"]
