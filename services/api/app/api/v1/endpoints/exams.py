from fastapi import APIRouter

from app.database.session import DbSession
from app.repositories.exam_repository import ExamRepository
from app.schemas.exam import ExamRead
from app.services.topic_service import exam_read

router = APIRouter(prefix="/exams")


@router.get("", response_model=list[ExamRead], summary="The exam catalog (public)")
def list_exams(session: DbSession) -> list[ExamRead]:
    return [exam_read(e) for e in ExamRepository(session).list_active()]
