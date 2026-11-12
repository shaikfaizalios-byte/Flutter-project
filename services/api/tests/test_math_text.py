"""Questions whose maths doesn't read as printed (maths letters the app can't draw, or a formula
split over lines) get an image of the question as printed and a review flag. The text is kept as
found; nothing is "fixed"."""

import uuid

from fastapi.testclient import TestClient
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.core.config import Settings
from app.domain.text_quality import math_layout_problems
from app.integrations.storage import LocalDocumentStorage
from app.models.question import Question, QuestionFigure, QuestionIssue
from tests.pdf_factory import text_pdf
from tests.test_document_processing import run_worker, upload

ITALIC_X = chr(0x1D465)  # MATHEMATICAL ITALIC SMALL X, as some papers' text layers give "x"


def test_maths_letters_and_split_formulas_are_noticed() -> None:
    assert math_layout_problems(f"If {ITALIC_X} > 0, find {ITALIC_X}") == [
        "2 mathematical symbol(s) that may not display as printed"
    ]
    split = "If (x\n2\n+ 3x)(x\n2\n+ 2) = 0, then x is"
    assert math_layout_problems(split) == [
        "a formula is split over several lines (exponents or fractions)"
    ]
    assert math_layout_problems("If x\n2\n= 4, x is") == []  # one piece only
    assert math_layout_problems("Pick one", "20\n30\n40") == []  # number options
    assert math_layout_problems("Find the next number: 3, 6, 12, 24") == []


def test_a_split_formula_gets_the_question_as_printed(
    db_client: TestClient,
    db_session: Session,
    storage: LocalDocumentStorage,
    settings: Settings,
) -> None:
    pdf = text_pdf(
        [
            [
                "Q.1 If (x",
                "2",
                "+ 3x)(x",
                "2",
                "+ 3x + 2) = 0, then x equals",
                "(1) 1   (2) 2   (3) 3   (4) 5",
                "Q.2 What is 20% of 150?",
                "(1) 20   (2) 30   (3) 40   (4) 50",
                "Answer Key",
                "1-(2)   2-(2)",
            ]
        ]
    )
    document_id = upload(db_client, pdf)
    run_worker(db_session, storage, settings)
    questions = db_session.scalars(
        select(Question)
        .where(Question.document_id == document_id)
        .order_by(Question.source_question_number)
    ).all()
    assert [q.source_question_number for q in questions] == [1, 2]
    split, plain = questions

    assert split.stem.startswith("If (x\n2\n+ 3x)(x")  # kept as found
    kinds = db_session.scalars(
        select(QuestionFigure.kind).where(QuestionFigure.question_id == split.id)
    ).all()
    assert "original" in kinds
    issue = db_session.scalars(
        select(QuestionIssue).where(
            QuestionIssue.question_id == split.id, QuestionIssue.code == "unreadable_text"
        )
    ).one()
    assert "split over several lines" in issue.detail

    assert (
        db_session.scalars(
            select(QuestionFigure).where(QuestionFigure.question_id == plain.id)
        ).all()
        == []
    )
    assert isinstance(document_id, uuid.UUID)
