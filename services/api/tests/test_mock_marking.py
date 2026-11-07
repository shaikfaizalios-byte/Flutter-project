"""Marking from the format: section marks, penalties, blanks, partial credit, cutoffs, limits."""

import uuid
from datetime import date
from decimal import Decimal
from typing import Any

import pytest
from fastapi.testclient import TestClient
from sqlalchemy.orm import Session

from app.domain.exam_format import config_problems, format_problems, section_marking
from app.domain.question_formats import partial_marks
from app.domain.scoring import ScoredItem, explain, score_session
from app.models.document import Document, DocumentStatus
from app.models.exam import Exam
from app.models.question import (
    ExamFormat,
    FormatStatus,
    Question,
    QuestionOption,
    QuestionOrigin,
    VerificationStatus,
)
from app.models.user import User

SPEC = {"correct_positions": [1, 2, 3]}
RULE = {"per_correct": "1"}


def _item(position: int = 1, **fields: Any) -> ScoredItem:
    values: dict[str, Any] = {
        "position": position,
        "section": "A",
        "topic_id": None,
        "correct_position": 1,
        "marks_correct": Decimal(4),
        "marks_wrong": Decimal(2),
        **fields,
    }
    return ScoredItem(**values)


def _multiple(position: int = 1) -> ScoredItem:
    return _item(
        position,
        correct_position=None,
        format="multiple_correct",
        answer_spec=SPEC,
        partial_rule=RULE,
    )


def test_a_sections_own_wrong_mark_wins() -> None:
    section = {"questions": 10, "max_marks": 40, "marks_wrong": 2}
    marking = section_marking(section, negative_marks_per_wrong=1, penalty_fraction=0.25)
    assert (marking.marks_correct, marking.marks_wrong) == (4, 2)


def test_a_penalty_fraction_follows_each_sections_marks() -> None:
    first = section_marking(
        {"questions": 30, "max_marks": 30}, negative_marks_per_wrong=None, penalty_fraction=0.25
    )
    second = section_marking(
        {"questions": 35, "max_marks": 40}, negative_marks_per_wrong=None, penalty_fraction=0.25
    )
    assert first.marks_wrong == 0.25
    assert second.marks_wrong == pytest.approx(40 / 35 * 0.25)


def test_with_nothing_special_it_is_the_format_negative_mark() -> None:
    marking = section_marking(
        {"questions": 25, "max_marks": 50}, negative_marks_per_wrong=0.5, penalty_fraction=None
    )
    assert (marking.marks_correct, marking.marks_wrong, marking.marks_unanswered) == (2, 0.5, 0)
    assert marking.partial is None


def _problems(**fields: Any) -> list[str]:
    values: dict[str, Any] = {
        "sections": [{"subject": "A", "questions": 10, "max_marks": 40}],
        "total_questions": 10,
        "duration_minutes": 60,
        "negative_marks_per_wrong": None,
        **fields,
    }
    return format_problems(**values)


def test_a_penalty_can_be_stated_three_ways_but_must_be_stated() -> None:
    assert any("negative marking" in p for p in _problems())
    assert _problems(negative_marks_per_wrong=0) == []
    assert _problems(penalty_fraction=0.25) == []
    sections = [{"subject": "A", "questions": 10, "max_marks": 40, "marks_wrong": 1}]
    assert _problems(sections=sections) == []


def test_a_penalty_fraction_must_be_a_fraction() -> None:
    assert any("between 0 and 1" in p for p in _problems(penalty_fraction=1.5))


def _config(sections: list[dict[str, Any]]) -> list[str]:
    return config_problems(
        sections=sections,
        duration_minutes=60,
        sections_in_fixed_order=True,
        sectional_timing=False,
        question_types=["choice"],
        effective_from=None,
        effective_to=None,
        source_title="T",
        source_url="https://example.com",
        source_reference="R",
    )


def test_a_partial_rule_and_an_attempt_limit_must_make_sense() -> None:
    assert _config([{"subject": "A", "questions": 5, "partial": {"per_correct": 1}}]) == []
    assert _config([{"subject": "A", "questions": 5, "partial": {}}])
    assert _config([{"subject": "A", "questions": 5, "attempt_limit": 3}]) == []
    assert _config([{"subject": "A", "questions": 5, "attempt_limit": 9}])


def test_partial_marks_need_some_correct_and_no_wrong_option() -> None:
    def marks(positions: list[int]) -> Decimal | None:
        return partial_marks("multiple_correct", SPEC, {"positions": positions}, RULE)

    assert marks([1]) == 1
    assert marks([1, 3]) == 2
    assert marks([1, 4]) is None  # a wrong option earns nothing partial
    assert marks([1, 2, 3]) is None  # all correct is not partial
    assert marks([]) is None


def test_partial_marks_apply_only_to_their_format() -> None:
    assert partial_marks("match", SPEC, {"positions": [1]}, RULE) is None


def test_scoring_a_multiple_correct_paper() -> None:
    items = [_multiple(1), _multiple(2), _multiple(3), _multiple(4)]
    result = score_session(
        items,
        {
            1: {"positions": [1, 2, 3]},  # all correct: +4
            2: {"positions": [1, 2]},  # partial: +2
            3: {"positions": [1, 4]},  # a wrong option: -2
        },
    )
    total = result.total
    assert (total.correct, total.partial, total.wrong, total.unattempted) == (1, 1, 1, 1)
    assert total.score == 4
    assert total.max_score == 16
    assert total.attempted == 3
    assert "Partly right 1 = 2.00" in explain(total)


def test_a_partly_right_answer_is_still_not_correct() -> None:
    result = score_session([_multiple()], {1: {"positions": [1]}})
    assert result.outcomes[1] is False


def test_marks_for_a_blank_answer_come_from_the_format() -> None:
    result = score_session([_item(marks_unanswered=Decimal(1))], {})
    assert result.total.score == 1
    assert "Unattempted 1 = 1.00" in explain(result.total)


def test_the_explanation_of_a_plain_paper_is_as_it_was() -> None:
    plain = _item(marks_correct=Decimal(2), marks_wrong=Decimal("0.5"))
    text = explain(score_session([plain], {1: 2}).total)
    assert text == "Correct 0; Wrong 1 × −0.50 = −0.50; Unattempted 0 × 0 = 0; Total -0.50 of 2.00"  # noqa: RUF001


_numbers = iter(range(1, 100_000))


def _format(db: Session, sections: list[dict[str, Any]], **fields: Any) -> ExamFormat:
    db.add(Exam(code="MARKED", name="Marked"))
    db.flush()
    row = ExamFormat(
        code="MARKED_2026",
        exam_code="MARKED",
        stage="Paper",
        name="Marked paper",
        sections=sections,
        sections_in_fixed_order=False,
        total_questions=sum(s["questions"] for s in sections),
        duration_minutes=60,
        source_title="Notice",
        source_url="https://example.com/notice",
        source_reference="para 1",
        source_published_on=date(2026, 1, 1),
        verified_on=date(2026, 1, 2),
        reviewed_by="A. Reviewer",
        status=FormatStatus.VERIFIED,
        **fields,
    )
    db.add(row)
    db.flush()
    return row


def _questions(db: Session, owner: User, subject: str, count: int, **fields: Any) -> list[Question]:
    document = Document(
        owner_id=owner.id,
        exam_code="MARKED",
        language="en",
        original_filename="p.pdf",
        size_bytes=1,
        sha256="0" * 64,
        storage_key=f"documents/{uuid.uuid4().hex}.pdf",
        page_count=1,
        status=DocumentStatus.COMPLETED,
    )
    db.add(document)
    db.flush()
    made = []
    for _ in range(count):
        n = next(_numbers)
        question = Question(
            owner_id=owner.id,
            origin=QuestionOrigin.SOURCE,
            exam_code="MARKED",
            subject=subject,
            stem=f"Question {n} of the paper about something",
            language="en",
            document_id=document.id,
            source_question_number=n,
            source_pages=[1],
            verification_status=VerificationStatus.VERIFIED,
            **({"correct_option_position": 1} | fields),
        )
        question.options = [
            QuestionOption(position=i, label=str(i), text=f"o{i}") for i in range(1, 5)
        ]
        db.add(question)
        made.append(question)
    db.flush()
    return made


def _start(client: TestClient, **body: Any) -> Any:
    return client.post(
        "/api/v1/practice/mock-tests", json={"exam_format_code": "MARKED_2026", **body}
    )


def _answer(client: TestClient, session: dict[str, Any], position: int, **body: Any) -> Any:
    return client.put(
        f"/api/v1/practice/sessions/{session['id']}/answers/{position}",
        json={"client_seq": position, **body},
    )


def _submit(client: TestClient, session: dict[str, Any]) -> dict[str, Any]:
    result: dict[str, Any] = client.post(
        f"/api/v1/practice/sessions/{session['id']}/submit"
    ).json()["result"]
    return result


def test_a_penalty_fraction_in_a_real_mock(
    db_client: TestClient, db_session: Session, user: User
) -> None:
    _format(
        db_session,
        [{"part": "1", "subject": "Maths", "questions": 2, "max_marks": 8}],
        penalty_fraction=0.25,
    )
    _questions(db_session, user, "Maths", 2)
    session = _start(db_client).json()
    _answer(db_client, session, 1, selected_position=1)
    _answer(db_client, session, 2, selected_position=2)
    result = _submit(db_client, session)
    assert (result["score"], result["max_score"]) == (3.0, 8.0)  # +4, -1
    assert "minus 0.25 of the question's marks" in result["marking_note"]


def test_each_section_uses_its_own_marks_and_shows_its_breakdown(
    db_client: TestClient, db_session: Session, user: User
) -> None:
    _format(
        db_session,
        [
            {"part": "1", "subject": "Maths", "questions": 1, "max_marks": 4, "marks_wrong": 1},
            {"part": "2", "subject": "Logic", "questions": 1, "max_marks": 2, "marks_wrong": 0},
        ],
    )
    _questions(db_session, user, "Maths", 1)
    _questions(db_session, user, "Logic", 1)
    session = _start(db_client).json()
    for item in session["items"]:
        _answer(db_client, session, item["position"], selected_position=2)
    sections = {s["name"]: s for s in _submit(db_client, session)["sections"]}
    assert sections["Maths"]["score"] == -1
    assert sections["Logic"]["score"] == 0


def test_a_cutoff_is_reported_only_where_the_format_states_one(
    db_client: TestClient, db_session: Session, user: User
) -> None:
    _format(
        db_session,
        [
            {"part": "1", "subject": "Maths", "questions": 1, "max_marks": 4, "cutoff": 3},
            {"part": "2", "subject": "Logic", "questions": 1, "max_marks": 4, "cutoff": 5},
            {"part": "3", "subject": "Words", "questions": 1, "max_marks": 4},
        ],
        negative_marks_per_wrong=0,
    )
    for subject in ("Maths", "Logic", "Words"):
        _questions(db_session, user, subject, 1)
    session = _start(db_client).json()
    for item in session["items"]:
        _answer(db_client, session, item["position"], selected_position=1)
    sections = {s["name"]: s for s in _submit(db_client, session)["sections"]}
    assert (sections["Maths"]["cutoff"], sections["Maths"]["cleared"]) == (3.0, True)
    assert sections["Logic"]["cleared"] is False
    assert sections["Words"]["cutoff"] is None and sections["Words"]["cleared"] is None


def test_an_attempt_limit_stops_the_next_new_answer_only(
    db_client: TestClient, db_session: Session, user: User
) -> None:
    _format(
        db_session,
        [{"part": "1", "subject": "Maths", "questions": 3, "max_marks": 12, "attempt_limit": 2}],
        negative_marks_per_wrong=0,
    )
    _questions(db_session, user, "Maths", 3)
    session = _start(db_client).json()
    assert _answer(db_client, session, 1, selected_position=1).status_code == 200
    assert _answer(db_client, session, 2, selected_position=1).status_code == 200
    third = _answer(db_client, session, 3, selected_position=1)
    assert third.status_code == 409
    assert third.json()["error"]["code"] == "section_limit"
    changed = db_client.put(
        f"/api/v1/practice/sessions/{session['id']}/answers/2",
        json={"client_seq": 50, "selected_position": 3},
    )
    assert changed.status_code == 200  # changing an answer is fine
    db_client.put(
        f"/api/v1/practice/sessions/{session['id']}/answers/2",
        json={"client_seq": 60, "selected_position": None},
    )
    again = db_client.put(
        f"/api/v1/practice/sessions/{session['id']}/answers/3",
        json={"client_seq": 70, "selected_position": 1},
    )
    assert again.status_code == 200  # clearing one frees a place


def test_partial_marks_in_a_real_mock(
    db_client: TestClient, db_session: Session, user: User
) -> None:
    _format(
        db_session,
        [
            {
                "part": "1",
                "subject": "Maths",
                "questions": 1,
                "max_marks": 4,
                "marks_wrong": 2,
                "partial": RULE,
                "formats": ["multiple_correct"],
            }
        ],
        question_types=["multiple_correct"],
    )
    _questions(
        db_session,
        user,
        "Maths",
        1,
        format="multiple_correct",
        answer_spec=SPEC,
        correct_option_position=None,
    )
    session = _start(db_client, include_new_formats=True).json()
    _answer(db_client, session, 1, response={"positions": [1, 2]})
    result = _submit(db_client, session)
    assert result["score"] == 2.0
    assert result["partial"] == 1


def test_an_app_that_cant_show_a_format_cant_start_its_mock(
    db_client: TestClient, db_session: Session, user: User
) -> None:
    _format(
        db_session,
        [{"part": "1", "subject": "Maths", "questions": 1, "max_marks": 4}],
        question_types=["multiple_correct"],
        negative_marks_per_wrong=1,
    )
    _questions(
        db_session,
        user,
        "Maths",
        1,
        format="multiple_correct",
        answer_spec=SPEC,
        correct_option_position=None,
    )
    assert _start(db_client).status_code == 422


def test_a_section_takes_only_its_own_formats(
    db_client: TestClient, db_session: Session, user: User
) -> None:
    _format(
        db_session,
        [
            {
                "part": "1",
                "subject": "Maths",
                "questions": 1,
                "max_marks": 4,
                "formats": ["numeric"],
            }
        ],
        question_types=["choice", "numeric"],
        negative_marks_per_wrong=0,
    )
    _questions(db_session, user, "Maths", 3)  # plain choice: not for this section
    assert _start(db_client, include_new_formats=True).status_code == 422
    _questions(
        db_session,
        user,
        "Maths",
        1,
        format="numeric",
        answer_type="typed",
        answer_spec={"value": "2"},
        correct_option_position=None,
    )
    session = _start(db_client, include_new_formats=True)
    assert session.status_code == 201, session.text
    assert session.json()["items"][0]["format"] == "numeric"


def test_typed_questions_join_a_mock_only_if_the_format_says_so(
    db_client: TestClient, db_session: Session, user: User
) -> None:
    row = _format(
        db_session,
        [{"part": "1", "subject": "Maths", "questions": 1, "max_marks": 4}],
        negative_marks_per_wrong=0,
    )
    _questions(
        db_session,
        user,
        "Maths",
        1,
        answer_type="typed",
        typed_answer="2",
        correct_option_position=None,
    )
    assert _start(db_client).status_code == 422
    row.question_types = ["typed"]
    db_session.flush()
    session = _start(db_client)
    assert session.status_code == 201, session.text
    assert session.json()["items"][0]["answer_type"] == "typed"
