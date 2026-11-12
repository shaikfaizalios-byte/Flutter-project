from functools import lru_cache

from fastapi import APIRouter, Path

from app.database.session import DbSession
from app.domain.paper_sources import PaperSource, load_sources
from app.repositories.exam_repository import ExamRepository
from app.schemas.exam import ExamRead, PaperSourceRead
from app.services.topic_service import exam_read

router = APIRouter(prefix="/exams")


@lru_cache(maxsize=1)
def _sources() -> dict[str, tuple[PaperSource, ...]]:
    return load_sources()


@router.get("", response_model=list[ExamRead], summary="The exam catalog (public)")
def list_exams(session: DbSession) -> list[ExamRead]:
    return [exam_read(e) for e in ExamRepository(session).list_active()]


@router.get(
    "/{code}/paper-sources",
    response_model=list[PaperSourceRead],
    summary="Official pages where papers for this exam can be found (public; [] if none listed)",
)
def paper_sources(code: str = Path(max_length=32)) -> list[PaperSourceRead]:
    return [
        PaperSourceRead(
            title=s.title,
            url=s.url,
            publisher=s.publisher,
            offers=s.offers,
            checked_on=s.checked_on,
        )
        for s in _sources().get(code, ())
    ]
