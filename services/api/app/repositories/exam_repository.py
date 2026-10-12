from collections.abc import Sequence

from sqlalchemy import select
from sqlalchemy.orm import Session

from app.models.exam import Exam


class ExamRepository:
    def __init__(self, session: Session) -> None:
        self._session = session

    def get(self, code: str) -> Exam | None:
        return self._session.get(Exam, code)

    def list_active(self) -> Sequence[Exam]:
        stmt = select(Exam).where(Exam.is_active.is_(True)).order_by(Exam.code)
        return self._session.scalars(stmt).all()
