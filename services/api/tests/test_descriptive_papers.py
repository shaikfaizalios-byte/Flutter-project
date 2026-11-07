"""Rubric marking for real written questions from the learner's own reviewed papers."""

import uuid
from itertools import count
from typing import Any

from fastapi.testclient import TestClient
from sqlalchemy import func, select
from sqlalchemy.orm import Session

from app.domain import descriptive
from app.models.descriptive import DescriptiveStep
from app.models.document import Document, DocumentStatus
from app.models.exam import Exam
from app.models.question import (
    Question,
    QuestionOrigin,
    Topic,
    VerificationStatus,
)
from app.models.user import User
from tests.conftest import make_user
from tests.fakes import FakeAIProvider
from tests.test_ai import AppFactory, ai, make_api
from tests.test_descriptive import SESSIONS, generate, marked, submit
from tests.test_ladder import topic

__all__ = ["ai", "make_api", "topic"]  # fixtures re-used from other test modules

EXAM = "UNI_LAW"
_numbers = count(1)


def rubric(marks: float = 10, **changes: Any) -> dict[str, Any]:
    data = {
        "rubric": [{"point": "First", "marks": marks - 1}, {"point": "Second", "marks": 1}],
        "model_answer": "The AI's model answer.",
    }
    return data | changes


def full(marks: float = 10) -> dict[str, Any]:
    return marked(marks - 1, 1)


def add_exam(db: Session) -> None:
    db.add(Exam(code=EXAM, name="University Law Exam", kind="descriptive"))
    db.flush()


def paper(db: Session, owner: User, **fields: Any) -> Document:
    document = Document(
        owner_id=owner.id,
        exam_code=EXAM,
        language="en",
        original_filename="law-2024.pdf",
        size_bytes=1,
        sha256="0" * 64,
        storage_key=f"documents/{uuid.uuid4().hex}.pdf",
        page_count=1,
        status=DocumentStatus.COMPLETED,
        **fields,
    )
    db.add(document)
    db.flush()
    return document


def question(db: Session, document: Document, topic: Topic, **fields: Any) -> Question:
    number = next(_numbers)
    values: dict[str, Any] = {
        "owner_id": document.owner_id,
        "origin": QuestionOrigin.SOURCE,
        "exam_code": EXAM,
        "stem": f"Explain the rule in case number {number}.",
        "language": "en",
        "document_id": document.id,
        "source_question_number": number,
        "source_pages": [1],
        "answer_type": "written",
        "topic_id": topic.id,
        "verification_status": VerificationStatus.VERIFIED,
    }
    row = Question(**(values | fields))
    db.add(row)
    db.flush()
    return row


def begin(api: TestClient, topic: Topic) -> dict[str, Any]:
    response = api.post(
        SESSIONS, json={"exam_code": EXAM, "topic_id": str(topic.id), "source": "papers"}
    )
    assert response.status_code == 201, response.text
    data: dict[str, Any] = response.json()
    return data


# --- the rubric -------------------------------------------------------------------------------


def test_the_prompt_gives_the_papers_answer_when_there_is_one() -> None:
    with_answer = descriptive.rubric_prompt(
        stem="Q", marks=5, words=100, paper_answer="Printed answer", language="en"
    )
    assert "Printed answer" in with_answer and "Base the rubric on this answer" in with_answer
    without = descriptive.rubric_prompt(
        stem="Q", marks=5, words=100, paper_answer=None, language="en"
    )
    assert "The paper gives no answer" in without


def test_the_question_stays_as_printed_and_the_papers_answer_wins() -> None:
    drafted = descriptive.validate_rubric(rubric(5), "Printed?", 5, "Printed answer")
    assert drafted is not None
    assert (drafted.stem, drafted.model_answer) == ("Printed?", "Printed answer")


def test_without_a_papers_answer_a_model_answer_is_needed() -> None:
    assert descriptive.validate_rubric(rubric(5, model_answer=" "), "Q", 5, None) is None


def test_the_rubric_must_add_up() -> None:
    assert descriptive.validate_rubric(rubric(4), "Q", 5, None) is None


# --- through the API (fake AI provider: no network) -------------------------------------------


def test_a_real_question_is_marked_against_its_rubric_and_labelled_as_from_the_paper(
    make_api: AppFactory, ai: FakeAIProvider, db_session: Session, user: User, topic: Topic
) -> None:
    add_exam(db_session)
    real = question(db_session, paper(db_session, user), topic)
    ai.responses += [rubric(), full(), marked(8, 1), full()]
    api = make_api(ai)

    body = begin(api, topic)
    assert len(body["steps"]) == 1
    planned = body["steps"][0]
    assert planned["source"] == "paper" and planned["paper_label"] == "law-2024.pdf"
    assert planned["stem"] == real.stem and planned["ready"] is False
    assert ai.calls == []

    step = generate(api, body)
    assert step["ready"] is True and step["stem"] == real.stem
    assert "First" not in str(step)  # the rubric stays hidden until marked

    result = submit(api, body)["result"]
    assert result["marks"] == 9.5 and result["marks_possible"] == 10
    assert result["model_answer"] == "The AI's model answer."
    assert result["model_answer_from_paper"] is False


def test_the_papers_own_answer_is_used_and_shown(
    make_api: AppFactory, ai: FakeAIProvider, db_session: Session, user: User, topic: Topic
) -> None:
    add_exam(db_session)
    question(db_session, paper(db_session, user), topic, model_answer="As printed in the paper.")
    ai.responses += [rubric(), full(), full(), full()]
    api = make_api(ai)
    body = begin(api, topic)
    generate(api, body)
    assert "As printed in the paper." in ai.calls[0].prompt
    assert "As printed in the paper." in ai.calls[1].prompt  # the check marks the paper's answer
    result = submit(api, body)["result"]
    assert result["model_answer"] == "As printed in the paper."
    assert result["model_answer_from_paper"] is True


def test_marks_printed_on_the_question_come_first(
    make_api: AppFactory, ai: FakeAIProvider, db_session: Session, user: User, topic: Topic
) -> None:
    add_exam(db_session)
    question(db_session, paper(db_session, user), topic, marks=6)
    assert begin(make_api(ai), topic)["steps"][0]["marks"] == 6


def test_a_second_attempt_reuses_the_rubric_with_no_ai_call(
    make_api: AppFactory, ai: FakeAIProvider, db_session: Session, user: User, topic: Topic
) -> None:
    add_exam(db_session)
    question(db_session, paper(db_session, user), topic)
    ai.responses += [rubric(), full()]
    api = make_api(ai)
    generate(api, begin(api, topic))
    calls = len(ai.calls)
    step = generate(api, begin(api, topic))
    assert step["ready"] is True and len(ai.calls) == calls


def test_a_rubric_is_drafted_again_when_the_question_was_corrected(
    make_api: AppFactory, ai: FakeAIProvider, db_session: Session, user: User, topic: Topic
) -> None:
    add_exam(db_session)
    real = question(db_session, paper(db_session, user), topic)
    ai.responses += [rubric(), full(), rubric(), full()]
    api = make_api(ai)
    generate(api, begin(api, topic))
    real.stem = "Explain the corrected rule."
    db_session.flush()
    generate(api, begin(api, topic))
    assert ai.responses == []


def test_a_rubric_is_drafted_again_when_the_papers_answer_was_added(
    make_api: AppFactory, ai: FakeAIProvider, db_session: Session, user: User, topic: Topic
) -> None:
    add_exam(db_session)
    real = question(db_session, paper(db_session, user), topic)
    ai.responses += [rubric(), full(), rubric(), full()]
    api = make_api(ai)
    generate(api, begin(api, topic))
    real.model_answer = "Now we have it."
    db_session.flush()
    generate(api, begin(api, topic))
    assert ai.responses == []


def test_a_rubric_its_own_answer_fails_is_drafted_again(
    make_api: AppFactory, ai: FakeAIProvider, db_session: Session, user: User, topic: Topic
) -> None:
    add_exam(db_session)
    question(db_session, paper(db_session, user), topic)
    ai.responses += [rubric(), marked(1, 0), rubric(), full()]
    api = make_api(ai)
    assert generate(api, begin(api, topic))["ready"] is True
    assert ai.responses == []


def test_a_rubric_that_keeps_failing_is_an_error_and_saves_nothing(
    make_api: AppFactory, ai: FakeAIProvider, db_session: Session, user: User, topic: Topic
) -> None:
    add_exam(db_session)
    question(db_session, paper(db_session, user), topic)
    ai.responses += [rubric(3), rubric(3), rubric(3)]
    api = make_api(ai)
    body = begin(api, topic)
    assert api.post(f"{SESSIONS}/{body['session_id']}/steps/1/generate").status_code == 502
    url = f"{SESSIONS}/{body['session_id']}/steps/1/answer"
    assert api.post(url, json={"text": "Mine"}).status_code == 409


def test_questions_not_yet_answered_come_first(
    make_api: AppFactory, ai: FakeAIProvider, db_session: Session, user: User, topic: Topic
) -> None:
    add_exam(db_session)
    document = paper(db_session, user)
    rows = [question(db_session, document, topic) for _ in range(6)]
    ai.responses += [rubric(), full(), full(), full()]
    api = make_api(ai)
    first = begin(api, topic)
    assert len(first["steps"]) == 5
    answered = first["steps"][0]["stem"]
    generate(api, first)
    submit(api, first)
    second = begin(api, topic)
    assert answered not in [s["stem"] for s in second["steps"]]
    assert rows[5].stem in [s["stem"] for s in second["steps"]]


def test_only_the_learners_own_reviewed_text_questions_are_used(
    make_api: AppFactory, ai: FakeAIProvider, db_session: Session, user: User, topic: Topic
) -> None:
    add_exam(db_session)
    document = paper(db_session, user)
    wanted = question(db_session, document, topic)
    question(
        db_session, document, topic, verification_status=VerificationStatus.UNVERIFIED
    )  # not reviewed
    question(db_session, document, topic, image_dependent=True)
    question(db_session, document, topic, translation_of_id=wanted.id)
    theirs = paper(db_session, make_user(db_session, "other@example.com"))
    question(db_session, theirs, topic, owner_id=theirs.owner_id)
    question(db_session, paper(db_session, user, duplicate_of_id=document.id), topic)

    api = make_api(ai)
    assert [s["stem"] for s in begin(api, topic)["steps"]] == [wanted.stem]
    listed = api.get("/api/v1/descriptive/overview", params={"exam": EXAM}).json()
    assert next(t for t in listed["topics"] if t["name"] == topic.name)["paper_questions"] == 1


def test_a_topic_with_no_written_questions_is_refused_without_keeping_a_session(
    make_api: AppFactory, ai: FakeAIProvider, db_session: Session, topic: Topic
) -> None:
    add_exam(db_session)
    api = make_api(ai)
    response = api.post(
        SESSIONS, json={"exam_code": EXAM, "topic_id": str(topic.id), "source": "papers"}
    )
    assert response.status_code == 409
    assert response.json()["error"]["code"] == "descriptive_no_papers"


def test_practising_a_real_question_adds_nothing_to_the_question_bank(
    make_api: AppFactory, ai: FakeAIProvider, db_session: Session, user: User, topic: Topic
) -> None:
    add_exam(db_session)
    question(db_session, paper(db_session, user), topic)
    before = db_session.scalar(select(func.count()).select_from(Question))
    ai.responses += [rubric(), full(), full(), full()]
    api = make_api(ai)
    body = begin(api, topic)
    generate(api, body)
    submit(api, body)
    assert db_session.scalar(select(func.count()).select_from(Question)) == before


def test_a_removed_question_keeps_its_attempt(
    make_api: AppFactory, ai: FakeAIProvider, db_session: Session, user: User, topic: Topic
) -> None:
    add_exam(db_session)
    real = question(db_session, paper(db_session, user), topic)
    ai.responses += [rubric(), full(), full(), full()]
    api = make_api(ai)
    body = begin(api, topic)
    generate(api, body)
    submit(api, body)
    stem = real.stem
    db_session.delete(real)
    db_session.flush()
    step = db_session.scalars(select(DescriptiveStep)).one()
    db_session.refresh(step)
    assert step.question_id is None and step.stem == stem
    assert api.get(f"{SESSIONS}/{body['session_id']}").json()["steps"][0]["result"]["marks"] == 10
