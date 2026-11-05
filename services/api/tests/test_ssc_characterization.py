"""Pins what SSC learners get today, so the any-exam work can't change it unnoticed.

Generated SSC-style papers (never real ones) go through the real parser, topic and model
suggestions, review and the repeats report; the outcome is compared with tests/golden. The
seeded syllabus, models, exam rows and formats are pinned the same way.

These must pass unchanged after every phase. A difference is a behaviour change: fix it, or
agree it first. To rewrite the golden files after an agreed change:
    PREPLOOP_UPDATE_GOLDEN=1 python -m pytest tests/test_ssc_characterization.py
"""

import hashlib
import json
import os
import uuid
from collections import Counter
from dataclasses import dataclass
from pathlib import Path
from typing import Any

import pytest
from sqlalchemy import select
from sqlalchemy.orm import Session, selectinload

from app.models.document import Document, DocumentPage, DocumentStatus
from app.models.exam import Exam
from app.models.question import (
    ExamFormat,
    Question,
    QuestionIssue,
    QuestionPattern,
    TopicStatus,
)
from app.models.user import User
from app.services.insights_service import InsightsService
from app.services.segmentation_service import SegmentationService
from app.services.topic_service import visible_topics

GOLDEN = Path(__file__).parent / "golden"
SSC_EXAMS = ("SSC_CGL", "SSC_CHSL")

# Made-up questions in the style of the papers. {0} and {1} change from paper to paper.
STEMS = {
    "venn": "Select the Venn diagram that best illustrates the relationship between the "
    "following classes. {0}, Doctors, Teachers",
    "analogy": "{0} is related to Water in the same way as Bird is related to {1}.",
    "coding": "In a certain code language, {0} is coded as {1}. How is PLANT written in that "
    "code language?",
    "odd": "Select the odd one out from the given words and find the one that does not belong.",
    "percent": "A man spends {1}% of his income and saves the rest. If he saves Rs 500, what "
    "is his income?",
    "profit": "A shopkeeper buys a pen for Rs {1} and sells it for Rs 90. Find his profit "
    "and the cost price of ten pens.",
    "synonym": "Select the synonym of the given word from the options below. {0}",
    "passive": "Select the correct passive form of the given sentence. {0} wrote a letter.",
    "history": "Who among the following founded the {0} dynasty in ancient India?",
    "polity": "Which Article of the Constitution of India deals with the {0}?",
}
SECTIONS = {
    "General Intelligence": ("venn", "analogy", "coding", "odd"),
    "Quantitative Aptitude": ("percent", "profit"),
    "English Language": ("synonym", "passive"),
    "General Awareness": ("history", "polity"),
}
WORDS = ("Mango", "Fish", "River", "Tiger", "Stone", "Cloud", "Paper", "Lamp")


@dataclass(frozen=True)
class Paper:
    name: str
    exam: str
    year: int | None  # None: the date was never confirmed
    leaves_out: tuple[str, ...] = ()  # question kinds this paper doesn't have
    reviewed: bool = True  # False: suggestions are left unreviewed
    options: int = 4  # of the first question (others have 4)


PAPERS = (
    Paper("chsl-2019-shift-1.pdf", "SSC_CHSL", 2019, ("odd",)),
    Paper("chsl-2020-shift-2.pdf", "SSC_CHSL", 2020, ("coding", "polity")),
    Paper("chsl-2021-shift-1.pdf", "SSC_CHSL", 2021, ("odd", "profit", "history")),
    Paper("chsl-2022-shift-3.pdf", "SSC_CHSL", 2022, ("analogy",), options=5),
    Paper("chsl-undated.pdf", "SSC_CHSL", None, ("passive", "polity"), options=3),
    Paper("chsl-2023-shift-1.pdf", "SSC_CHSL", 2023, ("venn", "synonym"), reviewed=False),
    Paper("cgl-2021-shift-1.pdf", "SSC_CGL", 2021, ("odd", "polity")),
    Paper("cgl-2022-shift-2.pdf", "SSC_CGL", 2022, ("analogy", "percent")),
)


def _paper_text(paper: Paper, seed: int) -> str:
    lines: list[str] = []
    key: list[str] = []
    number = 0
    for section, kinds in SECTIONS.items():
        lines.append(section)
        for kind in kinds:
            if kind in paper.leaves_out:
                continue
            number += 1
            word = WORDS[(seed + number) % len(WORDS)]
            lines.append(f"{number}. " + STEMS[kind].format(word, 10 * (seed + 2) + number))
            count = paper.options if number == 1 else 4
            lines.extend(f"({i}) {word} choice {i}" for i in range(1, count + 1))
            key.append(f"{number}-({(number + seed) % 3 + 1})")
    return "\n".join([*lines, "Answer Key", " ".join(key)])


def _import(db: Session, owner: User, paper: Paper, seed: int) -> Document:
    document = Document(
        owner_id=owner.id,
        exam_code=paper.exam,
        language="en",
        original_filename=paper.name,
        size_bytes=1,
        sha256=hashlib.sha256(paper.name.encode()).hexdigest(),
        storage_key=f"documents/{uuid.uuid4().hex}.pdf",
        page_count=1,
        status=DocumentStatus.COMPLETED,
    )
    db.add(document)
    db.flush()
    text = _paper_text(paper, seed)
    db.add(
        DocumentPage(
            document_id=document.id,
            page_number=1,
            method="text",
            text=text,
            char_count=len(text),
        )
    )
    db.commit()
    SegmentationService(db).segment_document(document.id)
    db.refresh(document)
    assert document.segmentation_status == "completed"
    return document


def _review(db: Session, document: Document, paper: Paper) -> None:
    if paper.year is not None:
        document.exam_year = paper.year
        document.paper_date_status = "confirmed"
    else:
        document.exam_year = None
        document.paper_date_status = "unknown"
    if paper.reviewed:
        for question in _questions(db, document):
            if question.topic_status == TopicStatus.SUGGESTED:
                question.topic_status = TopicStatus.CONFIRMED
            if question.pattern_status == TopicStatus.SUGGESTED:
                question.pattern_status = TopicStatus.CONFIRMED
    db.commit()


def _questions(db: Session, document: Document) -> list[Question]:
    return list(
        db.scalars(
            select(Question)
            .where(Question.document_id == document.id)
            .options(selectinload(Question.options))
            .order_by(Question.source_question_number)
        ).all()
    )


def _parsed(db: Session, document: Document) -> dict[str, Any]:
    """What the parser and the suggestions made of a paper, before review."""
    names = {t.id: t.name for t in visible_topics(db, document.owner_id, document.exam_code)}
    models = {p.id: p.name for p in db.scalars(select(QuestionPattern)).all()}
    issues = Counter(
        db.scalars(select(QuestionIssue.code).where(QuestionIssue.document_id == document.id)).all()
    )
    return {
        "paper": document.original_filename,
        "questions": [
            {
                "number": q.source_question_number,
                "section": q.section,
                "subject": q.subject,
                "options": len(q.options),
                "answer": q.correct_option_position,
                "topic": names.get(q.topic_id) if q.topic_id else None,
                "model": models.get(q.pattern_id) if q.pattern_id else None,
            }
            for q in _questions(db, document)
        ],
        "issues": dict(sorted(issues.items())),
    }


def _counts(counts: dict[str, Any]) -> dict[str, Any]:
    return {
        "questions": counts["questions"],
        "papers": counts["papers"],
        "years": {str(y["year"]): y["questions"] for y in counts["years"]},
    }


def _worded_alike(groups: list[dict[str, Any]]) -> list[dict[str, Any]]:
    """Groups come most papers first, then most questions. Beyond that their order follows the
    database's row order, which isn't defined, so ties and members are put in a fixed order."""
    ranks = [(-g["papers"], -len(g["questions"])) for g in groups]
    assert ranks == sorted(ranks)
    pinned = [
        {
            "topic": g["topic_name"],
            "subject": g["subject"],
            "papers": g["papers"],
            "years": g["years"],
            "questions": sorted(
                [q["document_filename"], q["question_number"]] for q in g["questions"]
            ),
        }
        for g in groups
    ]
    return sorted(pinned, key=lambda g: (-g["papers"], -len(g["questions"]), g["questions"]))


def _report(db: Session, owner: User, exam: str) -> dict[str, Any]:
    """The repeats report with ids left out; other lists keep the order the server sends."""
    data = InsightsService(db, owner.id).repeats(exam).model_dump(mode="json")
    gaps = data["not_repeated"]
    return {
        "papers": data["papers"],
        "similarity_threshold": data["similarity_threshold"],
        "topics": [
            {
                "subject": t["subject"],
                "name": t["name"],
                **_counts(t["confirmed"]),
                "unreviewed": t["unreviewed"],
                "without_model": t["without_pattern"],
                "models": [
                    {"name": p["name"], **_counts(p["confirmed"]), "unreviewed": p["unreviewed"]}
                    for p in t["patterns"]
                ],
            }
            for t in data["topics"]
        ],
        "worded_alike": _worded_alike(data["similar_groups"]),
        "not_repeated": {
            "topics": [[t["subject"], t["name"]] for t in gaps["not_seen"]],
            "models": [[g["topic_name"], g["name"]] for g in gaps["patterns_not_seen"]],
            "questions_without_topic": gaps["questions_without_topic"],
        },
    }


def _matches_golden(name: str, actual: dict[str, Any]) -> None:
    path = GOLDEN / name
    text = json.dumps(actual, indent=1, ensure_ascii=False, sort_keys=True) + "\n"
    if os.environ.get("PREPLOOP_UPDATE_GOLDEN"):
        path.write_text(text, encoding="utf-8", newline="\n")
    assert json.loads(text) == json.loads(path.read_text(encoding="utf-8"))


@pytest.fixture
def imported(db_session: Session, user: User) -> dict[str, Any]:
    """Every paper imported and reviewed; returns how each was read before the review."""
    parsed = []
    for seed, paper in enumerate(PAPERS):
        document = _import(db_session, user, paper, seed)
        parsed.append(_parsed(db_session, document))
        _review(db_session, document, paper)
    return {"papers": parsed}


def test_papers_are_read_and_classified_as_before(imported: dict[str, Any]) -> None:
    _matches_golden("ssc_papers.json", imported)


@pytest.mark.parametrize("exam", SSC_EXAMS)
def test_repeats_report_is_unchanged(
    imported: dict[str, Any], db_session: Session, user: User, exam: str
) -> None:
    _matches_golden(f"ssc_repeats_{exam.lower()}.json", _report(db_session, user, exam))


def _digest(value: Any) -> str:
    text = json.dumps(value, ensure_ascii=False, sort_keys=True)
    return hashlib.sha256(text.encode()).hexdigest()


def test_seeded_exams_syllabus_models_and_formats_are_unchanged(
    db_session: Session, user: User
) -> None:
    seeded: dict[str, Any] = {}
    models = db_session.scalars(select(QuestionPattern)).all()
    for code in SSC_EXAMS:
        exam = db_session.get(Exam, code)
        assert exam is not None
        topics = sorted(
            visible_topics(db_session, user.id, code), key=lambda t: (t.subject, t.name)
        )
        ids = {t.id: t for t in topics}
        rows = sorted(
            (ids[m.topic_id].subject, ids[m.topic_id].name, m.name, list(m.keywords))
            for m in models
            if m.topic_id in ids
        )
        formats = db_session.scalars(
            select(ExamFormat).where(ExamFormat.exam_code == code).order_by(ExamFormat.code)
        ).all()
        seeded[code] = {
            "exam": {
                "name": exam.name,
                "short_name": exam.short_name,
                "category": exam.category,
                "featured": exam.featured,
                "sort_order": exam.sort_order,
            },
            "topics": dict(sorted(Counter(t.subject for t in topics).items())),
            "topics_digest": _digest([[t.subject, t.name, list(t.keywords)] for t in topics]),
            "models": len(rows),
            "models_digest": _digest(rows),
            "formats": [
                {
                    "code": f.code,
                    "stage": f.tier,
                    "sections": f.sections,
                    "fixed_order": f.sections_in_fixed_order,
                    "total_questions": f.total_questions,
                    "duration_minutes": f.duration_minutes,
                    "negative_marks_per_wrong": f.negative_marks_per_wrong,
                    "sectional_timing": f.sectional_timing,
                    "question_types": list(f.question_types),
                    "status": str(f.status),
                }
                for f in formats
            ],
        }
    _matches_golden("ssc_seed.json", seeded)
