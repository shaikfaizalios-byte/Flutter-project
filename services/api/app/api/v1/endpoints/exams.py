from fastapi import APIRouter

from app.database.session import DbSession
from app.repositories.exam_repository import ExamRepository
from app.schemas.exam import ExamRead

router = APIRouter(prefix="/exams")


@router.get("", response_model=list[ExamRead], summary="List supported exams")
def list_exams(session: DbSession) -> list[ExamRead]:
    return [ExamRead.model_validate(e) for e in ExamRepository(session).list_active()]
