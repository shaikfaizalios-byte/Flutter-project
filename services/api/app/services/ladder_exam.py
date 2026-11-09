"""What a Challenge Ladder question must fit, read from the exam's stages.

A catalog exam's stages are its verified formats in effect today, in code order; a learner's own
exam keeps the stages they entered. The ladder writes for the first stage. Nothing here is
invented: without a stage, marks stay unstated and times use the defaults.
"""

import uuid
from collections.abc import Mapping, Sequence
from dataclasses import dataclass
from datetime import date
from typing import Any

from sqlalchemy.orm import Session

from app.domain import challenge_ladder as ladder
from app.domain.exam_format import SectionMarking, format_problems, section_marking
from app.domain.ladder_rules import rules_for
from app.domain.segmentation import same_subject
from app.models.exam import Exam
from app.models.question import ExamFormat
from app.services.exam_formats import mock_formats
from app.services.exam_profiles import profile_of
from app.services.taxonomy_service import subject_labels_by_topic


@dataclass(frozen=True, slots=True)
class _Stage:
    name: str
    base_seconds: float
    formats: tuple[str, ...]
    marking: SectionMarking | None
    markings: Mapping[str, SectionMarking] | None = None


def _section_of(
    sections: Sequence[Mapping[str, Any]], subjects: Sequence[str]
) -> Mapping[str, Any] | None:
    for section in sections:
        name = str(section.get("subject") or "")
        if any(same_subject(subject, name) for subject in subjects):
            return section
    return None


def _by_format(
    exam_format: ExamFormat, subjects: Sequence[str]
) -> dict[str, SectionMarking] | None:
    """Marks by format, where a subject has a section per format."""
    found: dict[str, SectionMarking] = {}
    for section in exam_format.sections or []:
        name = str(section.get("subject") or "")
        if not any(same_subject(subject, name) for subject in subjects):
            continue
        marking = _format_marking(exam_format, section)
        if marking is not None:
            for format_name in section.get("formats") or []:
                found[format_name] = marking
    return found or None


def _format_stage(exam_format: ExamFormat, subjects: Sequence[str]) -> _Stage:
    section = _section_of(exam_format.sections or [], subjects)
    return _Stage(
        name=exam_format.stage,
        base_seconds=ladder.base_time(exam_format.duration_minutes, exam_format.total_questions),
        formats=ladder.allowed_formats(
            exam_format.question_types or [], section.get("formats") if section else None
        ),
        marking=_format_marking(exam_format, section),
        markings=_by_format(exam_format, subjects),
    )


def _format_marking(
    exam_format: ExamFormat, section: Mapping[str, Any] | None
) -> SectionMarking | None:
    """The section's marks; with no matching section, only marks every section shares."""
    sections = exam_format.sections or []
    problems = format_problems(
        sections=sections,
        total_questions=exam_format.total_questions,
        duration_minutes=exam_format.duration_minutes,
        negative_marks_per_wrong=exam_format.negative_marks_per_wrong,
        penalty_fraction=exam_format.penalty_fraction,
    )
    if problems or not sections:
        return None
    marks = [
        section_marking(
            s,
            negative_marks_per_wrong=exam_format.negative_marks_per_wrong,
            penalty_fraction=exam_format.penalty_fraction,
        )
        for s in ([section] if section else sections)
    ]
    return marks[0] if all(m == marks[0] for m in marks) else None


def _entered_stage(stage: Mapping[str, Any]) -> _Stage:
    scheme = stage["marking_scheme"]
    return _Stage(
        name=stage["name"],
        base_seconds=ladder.base_time(
            stage["duration_minutes"], sum(s["question_count"] for s in stage["sections"])
        ),
        formats=(ladder.SINGLE_CORRECT,),
        marking=SectionMarking(
            marks_correct=scheme["marks_correct"],
            marks_wrong=scheme["marks_wrong"],
            marks_unanswered=scheme.get("marks_unanswered", 0),
            partial=None,
        ),
    )


def _stages(
    session: Session, exam: Exam, subject: str, topic_id: uuid.UUID | None, today: date
) -> list[_Stage]:
    if exam.owner_id is not None:
        return [_entered_stage(stage) for stage in exam.custom_stages or []]
    subjects = [subject]
    if topic_id is not None:
        subjects += subject_labels_by_topic(session, {topic_id}).get(topic_id, [])
    return [_format_stage(f, subjects) for f in mock_formats(session, exam.code, today)]


def exam_context(
    session: Session,
    exam: Exam,
    *,
    subject: str,
    topic_id: uuid.UUID | None,
    new_formats: bool,
    today: date,
) -> ladder.ExamContext:
    """An app that can't show the newer formats gets one correct option, as it always did."""
    stages = _stages(session, exam, subject, topic_id, today)
    first = stages[0] if stages else None
    rules = rules_for(exam.code)
    formats = first.formats if first and new_formats else (ladder.SINGLE_CORRECT,)
    if rules is not None and new_formats:
        formats = rules.formats
    return ladder.ExamContext(
        name=exam.name,
        stage=first.name if first else None,
        next_stage=stages[1].name if len(stages) > 1 else None,
        formats=formats,
        options=profile_of(exam).expected_options,
        marking=first.marking if first else None,
        base_time_seconds=first.base_seconds if first else ladder.base_time(None, None),
        anchors=rules.anchors if rules else None,
        strict=rules is not None,
        markings=first.markings if first else None,
    )
