"""A separate answer-key file: read with the paper's own key rules, and never overwrites."""

import uuid
from typing import Any

import pytest
from fastapi.testclient import TestClient
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.domain.answer_key import KeyQuestion, plan_key
from app.domain.segmentation import read_answer_key
from app.models.document import Document, DocumentStatus
from app.models.question import Question, QuestionIssue, QuestionOption, QuestionOrigin
from app.models.user import User
from tests.conftest import auth_headers, make_user
from tests.pdf_factory import text_pdf


def _q(number: int, answer: int | None = None, options: int = 4) -> KeyQuestion:
    return KeyQuestion(uuid.uuid4(), number, answer, options)


def test_pairs_tables_and_rows_are_read() -> None:
    assert read_answer_key(["1-(3) 2-(1) 3-(b)"]).entries == [(1, "3"), (2, "1"), (3, "b")]
    table = read_answer_key(["Q. No. 1 2 3", "Ans. b c a"])
    assert sorted(table.entries) == [(1, "b"), (2, "c"), (3, "a")]
    assert read_answer_key(["1 | b", "2 | d"]).entries == [(1, "b"), (2, "d")]


def test_a_title_above_the_key_doesnt_matter() -> None:
    read = read_answer_key(["Answer Key", "Combined Test Paper", "1-(3) 2-(1)"])
    assert read.entries == [(1, "3"), (2, "1")]


def test_a_table_whose_counts_differ_is_reported_and_left_out() -> None:
    read = read_answer_key(["Q. No. 1 2 3", "Ans. b c"])
    assert read.entries == []
    assert read.problems and "not used" in read.problems[0]


def test_a_key_fills_what_is_missing() -> None:
    first, second = _q(1), _q(2)
    plan = plan_key([first, second], [(1, "3"), (2, "a")])
    assert plan.apply == {first.id: 3, second.id: 1}
    assert not plan.conflicts and not plan.unmatched


def test_an_existing_answer_is_never_overwritten() -> None:
    same, different = _q(1, answer=3), _q(2, answer=2)
    plan = plan_key([same, different], [(1, "3"), (2, "4")])
    assert plan.apply == {} and plan.agreed == 1
    assert "key says 4" in plan.conflicts[different.id]


def test_answers_that_cant_be_true_are_flagged() -> None:
    small, doubled = _q(1, options=4), _q(2)
    plan = plan_key([small, doubled], [(1, "5"), (2, "1"), (2, "2")])
    assert plan.apply == {}
    assert set(plan.conflicts) == {small.id, doubled.id}


def test_numbers_with_no_question_are_listed() -> None:
    assert plan_key([_q(1)], [(1, "1"), (9, "2"), (7, "3")]).unmatched == [7, 9]


def test_repeating_numbers_stop_everything() -> None:
    plan = plan_key([_q(1), _q(1)], [(1, "2")])
    assert plan.ambiguous is True and plan.apply == {}


def test_an_empty_key_does_nothing() -> None:
    plan = plan_key([_q(1)], [])
    assert not plan.apply and not plan.ambiguous


_numbers = iter(range(1, 100_000))


def _paper(db: Session, owner: User, answers: list[int | None]) -> Document:
    document = Document(
        owner_id=owner.id,
        exam_code="SSC_CHSL",
        language="en",
        original_filename="paper.pdf",
        size_bytes=1,
        sha256="0" * 64,
        storage_key=f"documents/{uuid.uuid4().hex}.pdf",
        page_count=1,
        status=DocumentStatus.COMPLETED,
        segmentation_status="completed",
    )
    db.add(document)
    db.flush()
    for number, answer in enumerate(answers, start=1):
        question = Question(
            owner_id=owner.id,
            origin=QuestionOrigin.SOURCE,
            exam_code="SSC_CHSL",
            stem=f"Question {next(_numbers)} of this paper, about something",
            language="en",
            document_id=document.id,
            source_question_number=number,
            source_pages=[1],
            correct_option_position=answer,
            answer_source="manual" if answer else None,
        )
        question.options = [
            QuestionOption(position=i, label=str(i), text=f"o{i}") for i in range(1, 5)
        ]
        db.add(question)
    db.flush()
    return document


def _by_number(db: Session, document: Document) -> dict[int, Question]:
    db.expire_all()
    rows = db.scalars(select(Question).where(Question.document_id == document.id)).all()
    return {q.source_question_number or 0: q for q in rows}


def _send_text(client: TestClient, document: Document, text: str) -> Any:
    return client.post(f"/api/v1/documents/{document.id}/answer-key/text", json={"text": text})


def test_a_typed_key_is_applied_and_reported(
    db_client: TestClient, db_session: Session, user: User
) -> None:
    paper = _paper(db_session, user, [None, 2, 3])
    response = _send_text(db_client, paper, "1-(4) 2-(2) 3-(1) 9-(1)")
    assert response.status_code == 200, response.text
    assert response.json() == {
        "read_by": "typed",
        "applied": 1,
        "agreed": 1,
        "conflicts": 1,
        "unmatched": [9],
        "ambiguous": False,
        "without_answer": 0,
        "problems": [],
    }
    questions = _by_number(db_session, paper)
    assert questions[1].correct_option_position == 4
    assert questions[1].answer_source == "answer_key"
    assert questions[3].correct_option_position == 3  # kept, and flagged
    issues = db_session.scalars(
        select(QuestionIssue).where(QuestionIssue.question_id == questions[3].id)
    ).all()
    assert [i.code for i in issues] == ["conflicting_answers"]


def test_applied_answers_read_as_from_the_paper_and_enter_history(
    db_client: TestClient, db_session: Session, user: User
) -> None:
    paper = _paper(db_session, user, [None])
    _send_text(db_client, paper, "1-(4)")
    question = _by_number(db_session, paper)[1]
    data = db_client.get(f"/api/v1/questions/{question.id}").json()
    assert data["answer_origin"] == "paper"
    revisions = db_client.get(f"/api/v1/questions/{question.id}/revisions").json()
    assert "correct_option_position" in revisions[-1]["changed"]


def test_a_missing_answer_issue_goes_once_the_key_fills_it(
    db_client: TestClient, db_session: Session, user: User
) -> None:
    paper = _paper(db_session, user, [None])
    question = _by_number(db_session, paper)[1]
    db_session.add(
        QuestionIssue(document_id=paper.id, question_id=question.id, code="missing_answer")
    )
    db_session.flush()
    _send_text(db_client, paper, "1-(4)")
    db_session.expire_all()
    left = db_session.scalars(
        select(QuestionIssue).where(QuestionIssue.question_id == question.id)
    ).all()
    assert [i.code for i in left] == []


def test_a_pdf_key(db_client: TestClient, db_session: Session, user: User) -> None:
    paper = _paper(db_session, user, [None, None])
    # Enough text to count as a text layer: a shorter page goes to OCR where Tesseract is installed.
    key_pdf = text_pdf([["Sample paper for checking a key file", "Answer Key", "1-(2) 2-(3)"]])
    response = db_client.post(
        f"/api/v1/documents/{paper.id}/answer-key",
        files={"file": ("key.pdf", key_pdf, "application/pdf")},
    )
    assert response.status_code == 200, response.text
    assert response.json()["applied"] == 2
    assert response.json()["read_by"] == "text"
    assert _by_number(db_session, paper)[2].correct_option_position == 3


def test_something_other_than_a_pdf_is_refused(
    db_client: TestClient, db_session: Session, user: User
) -> None:
    paper = _paper(db_session, user, [None])
    response = db_client.post(
        f"/api/v1/documents/{paper.id}/answer-key",
        files={"file": ("key.txt", b"1-(2)", "text/plain")},
    )
    assert response.status_code == 415


def test_a_file_with_no_key_says_so_and_changes_nothing(
    db_client: TestClient, db_session: Session, user: User
) -> None:
    paper = _paper(db_session, user, [None])
    data = _send_text(db_client, paper, "Some words that are not a key").json()
    assert data["applied"] == 0 and data["without_answer"] == 1


@pytest.mark.parametrize("text", ["", "   "])
def test_empty_text_is_refused(
    db_client: TestClient, db_session: Session, user: User, text: str
) -> None:
    assert _send_text(db_client, _paper(db_session, user, [None]), text).status_code == 422


def test_another_learners_paper_looks_missing(
    db_client: TestClient, db_session: Session, user: User
) -> None:
    paper = _paper(db_session, user, [None])
    other = auth_headers(make_user(db_session, "other@example.com"))
    response = db_client.post(
        f"/api/v1/documents/{paper.id}/answer-key/text", json={"text": "1-(2)"}, headers=other
    )
    assert response.status_code == 404
    assert _by_number(db_session, paper)[1].correct_option_position is None
