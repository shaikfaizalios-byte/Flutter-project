import uuid
from collections.abc import Sequence

from sqlalchemy import or_, select
from sqlalchemy.orm import Session

from app.models.exam import Exam


class ExamRepository:
    def __init__(self, session: Session) -> None:
        self._session = session

    def get(self, code: str) -> Exam | None:
        return self._session.get(Exam, code)

    def get_visible(self, code: str, owner_id: uuid.UUID | None) -> Exam | None:
        """An active catalog exam, or one of ``owner_id``'s own exams; else None (another
        learner's private exam looks exactly like a missing one)."""
        exam = self._session.get(Exam, code)
        if exam is None or not exam.is_active:
            return None
        if exam.owner_id is not None and exam.owner_id != owner_id:
            return None
        return exam

    def list_active(self) -> Sequence[Exam]:
        """The public catalog."""
        stmt = (
            select(Exam)
            .where(Exam.is_active.is_(True), Exam.owner_id.is_(None))
            .order_by(Exam.sort_order, Exam.name)
        )
        return self._session.scalars(stmt).all()

    def list_visible(self, owner_id: uuid.UUID) -> Sequence[Exam]:
        """Catalog plus the learner's own exams."""
        stmt = (
            select(Exam)
            .where(
                Exam.is_active.is_(True),
                or_(Exam.owner_id.is_(None), Exam.owner_id == owner_id),
            )
            .order_by(Exam.owner_id.is_not(None), Exam.sort_order, Exam.name)
        )
        return self._session.scalars(stmt).all()
