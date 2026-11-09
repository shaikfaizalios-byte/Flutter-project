import uuid
from typing import Annotated

from fastapi import APIRouter, Depends, Path, Query, Response, status

from app.api.deps import CurrentUser
from app.database.session import DbSession
from app.domain.errors import ForbiddenError
from app.models.user import User
from app.schemas.library import (
    CorrectionResult,
    GeneratedReviewRead,
    LibraryCorrection,
    LibraryCreate,
    LibraryEntryRead,
    LibraryPage,
    LibraryQuestionRead,
    LibraryReportRead,
    LibraryRights,
    LibrarySolve,
    LibraryVersionRead,
    LibraryWithdraw,
    ModelApproval,
    ModelApproved,
    ModelProposalRead,
    ModelsProposed,
    PackDelta,
    PackRead,
    SolveResult,
)
from app.services.library_service import GeneratedQueue, LibraryEditor, LibraryReader
from app.services.repeat_analysis import ModelReview, propose_models

router = APIRouter(prefix="/library", tags=["library"])


def editor_user(user: CurrentUser) -> User:
    if user.content_role != "editor":
        raise ForbiddenError("This is for PrepLoop's content team.")
    return user


Editor = Annotated[User, Depends(editor_user)]
Exam = Annotated[str, Query(max_length=32)]


def _editor(session: DbSession, user: Editor) -> LibraryEditor:
    return LibraryEditor(session, user)


Staff = Annotated[LibraryEditor, Depends(_editor)]


@router.get("/search", response_model=LibraryPage, summary="Search the library")
def search(
    session: DbSession,
    _: CurrentUser,
    exam: Exam,
    unit: Annotated[str | None, Query(max_length=100)] = None,
    topic_id: uuid.UUID | None = None,
    pattern_id: uuid.UUID | None = None,
    format: Annotated[str | None, Query(max_length=20)] = None,
    year: Annotated[int | None, Query(ge=1950, le=2100)] = None,
    difficulty: Annotated[str | None, Query(max_length=6)] = None,
    q: Annotated[str | None, Query(max_length=100)] = None,
    limit: Annotated[int, Query(ge=1, le=100)] = 50,
    offset: Annotated[int, Query(ge=0, le=100_000)] = 0,
) -> LibraryPage:
    return LibraryReader(session).search(
        exam=exam,
        unit=unit,
        topic_id=topic_id,
        pattern_id=pattern_id,
        format_name=format,
        year=year,
        difficulty=difficulty,
        text=q,
        limit=limit,
        offset=offset,
    )


@router.get("/packs", response_model=list[PackRead], summary="Chapter packs for offline use")
def packs(session: DbSession, _: CurrentUser, exam: Exam) -> list[PackRead]:
    return LibraryReader(session).packs(exam)


@router.get(
    "/packs/{key}", response_model=PackDelta, summary="A chapter's changes since a device's copy"
)
def pack(
    session: DbSession,
    _: CurrentUser,
    key: Annotated[str, Path(max_length=200)],
    exam: Exam,
    since: Annotated[int, Query(ge=0)] = 0,
) -> PackDelta:
    return LibraryReader(session).pack(exam, key, since)


@router.get("/entries", response_model=list[LibraryEntryRead], summary="The review queue")
def queue(
    service: Staff, entry_status: Annotated[str | None, Query(alias="status", max_length=9)] = None
) -> list[LibraryEntryRead]:
    return service.queue(entry_status)


@router.post(
    "/entries",
    response_model=LibraryEntryRead,
    status_code=status.HTTP_201_CREATED,
    summary="Add a question as a draft",
)
def create(body: LibraryCreate, service: Staff) -> LibraryEntryRead:
    return service.create(body)


@router.get(
    "/entries/{question_id}/question",
    response_model=LibraryQuestionRead,
    summary="A question for review; the key stays hidden until it has been solved",
)
def question(question_id: uuid.UUID, service: Staff) -> LibraryQuestionRead:
    return service.question(question_id)


@router.get(
    "/entries/{question_id}/figures/{figure_id}",
    response_class=Response,
    summary="A figure of a question under review (PNG)",
)
def figure(question_id: uuid.UUID, figure_id: uuid.UUID, service: Staff) -> Response:
    found = service.figure(question_id, figure_id)
    return Response(content=found.data, media_type=found.content_type)


@router.post(
    "/entries/{question_id}/solve",
    response_model=SolveResult,
    summary="A second reviewer's own answer",
)
def solve(question_id: uuid.UUID, body: LibrarySolve, service: Staff) -> SolveResult:
    return service.solve(question_id, body)


@router.post(
    "/entries/{question_id}/approve", response_model=LibraryEntryRead, summary="Approve a question"
)
def approve(question_id: uuid.UUID, service: Staff) -> LibraryEntryRead:
    return service.approve(question_id)


@router.put(
    "/entries/{question_id}/rights", response_model=LibraryEntryRead, summary="Record the rights"
)
def set_rights(question_id: uuid.UUID, body: LibraryRights, service: Staff) -> LibraryEntryRead:
    return service.set_rights(question_id, body)


@router.post(
    "/entries/{question_id}/correct",
    response_model=CorrectionResult,
    summary="A new version: attempts are marked again",
)
def correct(question_id: uuid.UUID, body: LibraryCorrection, service: Staff) -> CorrectionResult:
    return service.correct(question_id, body)


@router.post(
    "/entries/{question_id}/withdraw",
    response_model=LibraryEntryRead,
    summary="Take a question out of the library",
)
def withdraw(question_id: uuid.UUID, body: LibraryWithdraw, service: Staff) -> LibraryEntryRead:
    return service.withdraw(question_id, body.reason)


@router.get(
    "/entries/{question_id}/versions",
    response_model=list[LibraryVersionRead],
    summary="A question's version history",
)
def versions(question_id: uuid.UUID, service: Staff) -> list[LibraryVersionRead]:
    return service.versions(question_id)


@router.get(
    "/model-proposals",
    response_model=list[ModelProposalRead],
    summary="Clusters of alike questions waiting for a subject reviewer",
)
def model_proposals(session: DbSession, user: Editor, exam: Exam) -> list[ModelProposalRead]:
    return ModelReview(session, user).listing(exam)


@router.post(
    "/model-proposals",
    response_model=ModelsProposed,
    summary="Rebuild the proposals from curated papers",
)
def run_proposals(session: DbSession, _: Editor, exam: Exam) -> ModelsProposed:
    return ModelsProposed(proposed=propose_models(session, exam))


@router.post(
    "/model-proposals/{proposal_id}/approve",
    response_model=ModelApproved,
    summary="Name the model and confirm it on the questions kept",
)
def approve_model(
    proposal_id: uuid.UUID, body: ModelApproval, session: DbSession, user: Editor
) -> ModelApproved:
    return ModelApproved(questions=ModelReview(session, user).approve(proposal_id, body))


@router.post(
    "/model-proposals/{proposal_id}/reject",
    status_code=status.HTTP_204_NO_CONTENT,
    summary="Reject a proposal: it won't be proposed again",
)
def reject_model(
    proposal_id: uuid.UUID, body: LibraryWithdraw, session: DbSession, user: Editor
) -> None:
    ModelReview(session, user).reject(proposal_id, body.reason)


@router.get(
    "/generated",
    response_model=list[GeneratedReviewRead],
    summary="Generated questions waiting for a person",
)
def generated(session: DbSession, user: Editor) -> list[GeneratedReviewRead]:
    return GeneratedQueue(session, user).pending()


@router.post(
    "/generated/{review_id}/accept",
    response_model=LibraryEntryRead,
    summary="Make it a library draft, for the usual second solve and approval",
)
def accept_generated(review_id: uuid.UUID, session: DbSession, user: Editor) -> LibraryEntryRead:
    return GeneratedQueue(session, user).accept(review_id)


@router.post(
    "/generated/{review_id}/reject",
    status_code=status.HTTP_204_NO_CONTENT,
    summary="Reject a generated question",
)
def reject_generated(
    review_id: uuid.UUID, body: LibraryWithdraw, session: DbSession, user: Editor
) -> None:
    GeneratedQueue(session, user).reject(review_id, body.reason)


@router.get("/reports", response_model=list[LibraryReportRead], summary="Reported mistakes")
def reports(service: Staff) -> list[LibraryReportRead]:
    return service.reports()


@router.post(
    "/reports/{report_id}/dismiss",
    status_code=status.HTTP_204_NO_CONTENT,
    summary="Close a report that needs no change",
)
def dismiss(report_id: uuid.UUID, body: LibraryWithdraw, service: Staff) -> None:
    service.dismiss_report(report_id, body.reason)
