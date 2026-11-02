"""Which exam formats are used where (rules in app/domain/exam_format.py).

- New mocks: verified formats in effect today.
- Reading and linking papers: verified and retired formats (an old paper follows its old
  format); drafts are only seen by the operator tool.
"""

from collections.abc import Sequence
from datetime import date

from sqlalchemy import select
from sqlalchemy.orm import Session

from app.domain.exam_format import config_problems, format_problems, in_effect
from app.models.question import ExamFormat, FormatStatus


def publish_problems(f: ExamFormat) -> list[str]:
    """Everything that stops this format from being published (empty: it can be)."""
    return format_problems(
        sections=f.sections,
        total_questions=f.total_questions,
        duration_minutes=f.duration_minutes,
        negative_marks_per_wrong=f.negative_marks_per_wrong,
    ) + config_problems(
        sections=f.sections,
        duration_minutes=f.duration_minutes,
        sections_in_fixed_order=f.sections_in_fixed_order,
        sectional_timing=f.sectional_timing,
        question_types=f.question_types,
        effective_from=f.effective_from,
        effective_to=f.effective_to,
        source_title=f.source_title,
        source_url=f.source_url,
        source_reference=f.source_reference,
    )


def is_in_effect(f: ExamFormat, today: date) -> bool:
    return in_effect(
        status=f.status, effective_from=f.effective_from, effective_to=f.effective_to, today=today
    )


def published_formats(session: Session, exam_code: str | None) -> Sequence[ExamFormat]:
    """Verified and retired formats (never drafts), by exam and code."""
    stmt = (
        select(ExamFormat)
        .where(ExamFormat.status != FormatStatus.DRAFT)
        .order_by(ExamFormat.exam_code, ExamFormat.code)
    )
    if exam_code:
        stmt = stmt.where(ExamFormat.exam_code == exam_code)
    return session.scalars(stmt).all()


def mock_formats(session: Session, exam_code: str | None, today: date) -> list[ExamFormat]:
    """Formats a new mock may use today."""
    return [f for f in published_formats(session, exam_code) if is_in_effect(f, today)]
