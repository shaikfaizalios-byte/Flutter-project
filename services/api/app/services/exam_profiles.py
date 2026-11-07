"""An exam's profile, from its row (app/domain/exam_profile.py)."""

from sqlalchemy.orm import Session

from app.domain.exam_profile import ExamProfile, resolve
from app.models.exam import Exam


def profile_of(exam: Exam | None) -> ExamProfile:
    if exam is None:
        return resolve()
    return resolve(
        kind=exam.kind,
        options_per_question=exam.options_per_question,
        repeat_share=exam.repeat_share,
        min_papers=exam.min_papers,
        reliable_papers=exam.reliable_papers,
        counting_unit=exam.counting_unit,
    )


def profile_for(session: Session, exam_code: str | None) -> ExamProfile:
    return profile_of(session.get(Exam, exam_code) if exam_code else None)
