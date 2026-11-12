import uuid
from collections.abc import Sequence
from typing import Annotated, Any

from fastapi import (
    APIRouter,
    Depends,
    File,
    Form,
    Path,
    Query,
    Request,
    Response,
    UploadFile,
    status,
)
from pydantic import BaseModel, ConfigDict, StringConstraints

from app.api.deps import CurrentUser, client_key
from app.core.config import Settings, get_settings
from app.database.session import DbSession
from app.domain.errors import UploadTooLargeError
from app.domain.segmentation import read_answer_key
from app.schemas.document import (
    AnswerKeyResult,
    AnswerKeyText,
    DocumentPageList,
    DocumentRead,
    DocumentStatusLiteral,
    DuplicateSuggestion,
    PageList,
    PaperDateUpdate,
    PaperDetailsUpdate,
)
from app.schemas.errors import ErrorResponse
from app.schemas.language import Language
from app.schemas.question import (
    DocumentFormatUpdate,
    ImportCheckRead,
    OfficialKeyResult,
    ParseSummary,
    TopicAcceptResult,
    VerifyCleanResult,
)
from app.services.answer_key_file import read_key_pages, read_key_pdf
from app.services.document_service import DocumentService
from app.services.question_service import QuestionService
from app.services.segmentation_service import SegmentationService

router = APIRouter(
    prefix="/documents",
    responses={503: {"model": ErrorResponse, "description": "Database unavailable"}},
)

NOT_FOUND: dict[int | str, dict[str, Any]] = {
    404: {"model": ErrorResponse, "description": "Document not found"}
}
UPLOAD_ERRORS: dict[int | str, dict[str, Any]] = {
    413: {"model": ErrorResponse, "description": "file_too_large"},
    415: {"model": ErrorResponse, "description": "unsupported_file_type (not a PDF)"},
    422: {
        "model": ErrorResponse,
        "description": "validation_error, invalid_reference, empty_file, invalid_pdf, "
        "encrypted_pdf, too_many_pages",
    },
    429: {"model": ErrorResponse, "description": "rate_limited (see Retry-After)"},
}

# Multipart framing overhead allowed on top of the file-size limit.
_MULTIPART_OVERHEAD = 64 * 1024


def get_document_service(
    request: Request,
    session: DbSession,
    settings: Annotated[Settings, Depends(get_settings)],
    user: CurrentUser,
) -> DocumentService:
    return DocumentService(session, request.app.state.document_storage, settings, owner_id=user.id)


Service = Annotated[DocumentService, Depends(get_document_service)]


class SamplePapersAdd(BaseModel):
    model_config = ConfigDict(extra="forbid")

    exam_code: Annotated[str, StringConstraints(min_length=1, max_length=32)]


def guard_upload(
    request: Request, settings: Annotated[Settings, Depends(get_settings)], user: CurrentUser
) -> None:
    """Runs before the body is parsed: rate limit, and reject declared oversize bodies early
    (the streaming copy enforces the limit again for bodies without a length)."""
    request.app.state.upload_rate_limiter.check(client_key(request, user))
    declared = request.headers.get("content-length")
    if (
        declared
        and declared.isdigit()
        and int(declared) > settings.max_upload_bytes + _MULTIPART_OVERHEAD
    ):
        raise UploadTooLargeError(
            f"The file is larger than {settings.max_upload_bytes // (1024 * 1024)} MB."
        )


@router.post(
    "",
    response_model=DocumentRead,
    status_code=status.HTTP_201_CREATED,
    summary="Upload a PDF for processing",
    responses=UPLOAD_ERRORS,
    dependencies=[Depends(guard_upload)],
)
def upload_document(
    service: Service,
    file: Annotated[UploadFile, File(description="PDF file")],
    exam_code: Annotated[str, Form(min_length=1, max_length=32)],
    language: Annotated[Language, Form(description="Language of the document's content")],
    exam_format_code: Annotated[
        str | None,
        Form(max_length=64, description="Optional verified paper format (see /exam-formats)"),
    ] = None,
) -> DocumentRead:
    return service.upload(
        stream=file.file,
        filename=file.filename,
        exam_code=exam_code,
        language=language,
        exam_format_code=exam_format_code or None,
    )


@router.post(
    "/samples",
    response_model=list[DocumentRead],
    status_code=status.HTTP_201_CREATED,
    responses=UPLOAD_ERRORS,
    dependencies=[Depends(guard_upload)],
    summary="Add PrepLoop's made-up sample papers to an exam (to try the app; not real papers)",
)
def add_sample_papers(body: SamplePapersAdd, service: Service) -> list[DocumentRead]:
    return service.add_samples(body.exam_code)


@router.get("", response_model=DocumentPageList, summary="List uploaded documents")
def list_documents(
    service: Service,
    status_filter: Annotated[DocumentStatusLiteral | None, Query(alias="status")] = None,
    limit: Annotated[int, Query(ge=1, le=100)] = 20,
    offset: Annotated[int, Query(ge=0, le=100_000)] = 0,
) -> DocumentPageList:
    return service.list(status=status_filter, limit=limit, offset=offset)


@router.get("/{document_id}", response_model=DocumentRead, responses=NOT_FOUND)
def get_document(document_id: uuid.UUID, service: Service) -> DocumentRead:
    return service.get(document_id)


@router.get(
    "/{document_id}/pages",
    response_model=PageList,
    responses=NOT_FOUND,
    summary="Extracted text per page (with review flags)",
)
def get_document_pages(
    document_id: uuid.UUID,
    service: Service,
    limit: Annotated[int, Query(ge=1, le=100)] = 20,
    offset: Annotated[int, Query(ge=0, le=100_000)] = 0,
) -> PageList:
    return service.pages(document_id, limit=limit, offset=offset)


@router.get(
    "/{document_id}/pages/{page_number}/image",
    summary="One page of the original PDF as PNG, as uploaded (for reading the paper)",
    response_class=Response,
    responses={
        200: {"content": {"image/png": {}}, "description": "The page"},
        404: {"model": ErrorResponse, "description": "Document or page not found"},
    },
)
def get_page_image(
    document_id: uuid.UUID,
    page_number: Annotated[int, Path(ge=1, le=100_000)],
    service: Service,
    max_edge: Annotated[int, Query(ge=400, le=2400, description="Longer side in pixels")] = 1600,
) -> Response:
    return Response(
        content=service.page_image(document_id, page_number, max_edge),
        media_type="image/png",
        # The original file never changes; only this account may cache it.
        headers={"Cache-Control": "private, max-age=86400"},
    )


@router.delete(
    "/{document_id}",
    status_code=status.HTTP_204_NO_CONTENT,
    responses=NOT_FOUND,
    summary="Permanently delete a document, its pages and the original file",
)
def delete_document(document_id: uuid.UUID, service: Service) -> None:
    service.delete(document_id)


@router.get(
    "/{document_id}/parse-summary",
    response_model=ParseSummary,
    responses=NOT_FOUND,
    summary="Question segmentation results and document-level issues",
)
def get_parse_summary(
    document_id: uuid.UUID, session: DbSession, user: CurrentUser
) -> ParseSummary:
    return QuestionService(session, user.id).parse_summary(document_id)


@router.put(
    "/{document_id}/exam-format",
    response_model=DocumentRead,
    responses=NOT_FOUND,
    summary="Link (or unlink) a verified paper format; re-run segmentation to apply it",
)
def set_exam_format(
    document_id: uuid.UUID, body: DocumentFormatUpdate, service: Service
) -> DocumentRead:
    return service.set_exam_format(document_id, body.exam_format_code)


@router.post(
    "/{document_id}/answer-key",
    response_model=AnswerKeyResult,
    responses={**NOT_FOUND, **UPLOAD_ERRORS},
    dependencies=[Depends(guard_upload)],
    summary="Fill in missing answers from a separate answer-key PDF (the file isn't kept)",
)
def upload_answer_key(
    document_id: uuid.UUID,
    request: Request,
    service: Service,
    session: DbSession,
    user: CurrentUser,
    settings: Annotated[Settings, Depends(get_settings)],
    file: Annotated[UploadFile, File(description="Answer-key PDF")],
) -> AnswerKeyResult:
    document = service.get(document_id)  # 404 before any work on someone else's paper
    read, read_by = read_key_pdf(
        file.file,
        language=document.language,
        settings=settings,
        ocr=request.app.state.ocr_engine,
        temp_dir=request.app.state.document_storage.temp_dir(),
    )
    return QuestionService(session, user.id).apply_answer_key(document_id, read, read_by)


@router.post(
    "/{document_id}/official-key",
    response_model=OfficialKeyResult,
    responses={**NOT_FOUND, **UPLOAD_ERRORS},
    dependencies=[Depends(guard_upload)],
    summary="Match an official key file to this paper by question ID (the file isn't kept)",
)
def upload_official_key(
    document_id: uuid.UUID,
    request: Request,
    service: Service,
    session: DbSession,
    user: CurrentUser,
    settings: Annotated[Settings, Depends(get_settings)],
    file: Annotated[UploadFile, File(description="Official answer-key PDF")],
) -> OfficialKeyResult:
    document = service.get(document_id)  # 404 before any work on someone else's paper
    pages, _ = read_key_pages(
        file.file,
        language=document.language,
        settings=settings,
        ocr=request.app.state.ocr_engine,
        temp_dir=request.app.state.document_storage.temp_dir(),
    )
    return QuestionService(session, user.id).apply_official_key(document_id, pages)


@router.get(
    "/{document_id}/import-check",
    response_model=ImportCheckRead,
    responses=NOT_FOUND,
    summary="Compare an imported paper with a format: counts, keys and question formats",
)
def import_check(
    document_id: uuid.UUID,
    format_code: Annotated[str, Query(max_length=64)],
    session: DbSession,
    user: CurrentUser,
) -> ImportCheckRead:
    return QuestionService(session, user.id).import_check(document_id, format_code)


@router.post(
    "/{document_id}/answer-key/text",
    response_model=AnswerKeyResult,
    responses=NOT_FOUND,
    summary="Fill in missing answers from a typed or pasted answer key",
)
def type_answer_key(
    document_id: uuid.UUID, body: AnswerKeyText, session: DbSession, user: CurrentUser
) -> AnswerKeyResult:
    return QuestionService(session, user.id).apply_answer_key(
        document_id, read_answer_key([body.text]), "typed"
    )


@router.put(
    "/{document_id}/details",
    response_model=DocumentRead,
    responses=NOT_FOUND,
    summary="Stage, session, set and languages; mark the paper as another set of a paper",
)
def set_details(document_id: uuid.UUID, body: PaperDetailsUpdate, service: Service) -> DocumentRead:
    return service.set_details(document_id, body)


@router.get(
    "/{document_id}/duplicate-suggestions",
    response_model=list[DuplicateSuggestion],
    responses=NOT_FOUND,
    summary="Your papers that look like another set of this one (nothing changes until you say)",
)
def duplicate_suggestions(
    document_id: uuid.UUID, service: Service
) -> Sequence[DuplicateSuggestion]:
    return service.duplicate_suggestions(document_id)


@router.put(
    "/{document_id}/paper-date",
    response_model=DocumentRead,
    responses=NOT_FOUND,
    summary="Confirm when the paper was held (year, date, shift); used for year trends",
)
def set_paper_date(document_id: uuid.UUID, body: PaperDateUpdate, service: Service) -> DocumentRead:
    return service.set_paper_date(document_id, body)


@router.post(
    "/{document_id}/segment",
    response_model=ParseSummary,
    responses={
        **NOT_FOUND,
        409: {"model": ErrorResponse, "description": "document_not_ready"},
    },
    summary="Re-run question segmentation (keeps verified and rejected questions)",
)
def resegment_document(
    document_id: uuid.UUID,
    service: Service,
    session: DbSession,
    user: CurrentUser,
    request: Request,
) -> ParseSummary:
    service.require_extracted(document_id)  # also checks the document is the user's
    SegmentationService(session, request.app.state.document_storage).segment_document(document_id)
    return QuestionService(session, user.id).parse_summary(document_id)


@router.post(
    "/{document_id}/questions/verify-clean",
    response_model=VerifyCleanResult,
    responses=NOT_FOUND,
    summary="Verify every question of the paper that needs no review (answer known, no open "
    "issues); the rest stay for review",
)
def verify_clean_questions(
    document_id: uuid.UUID, session: DbSession, user: CurrentUser
) -> VerifyCleanResult:
    verified, left = QuestionService(session, user.id).verify_clean(document_id)
    return VerifyCleanResult(verified=verified, left_for_review=left)


@router.post(
    "/{document_id}/topics/accept",
    response_model=TopicAcceptResult,
    responses=NOT_FOUND,
    summary="Accept every suggested topic and pattern of the paper's questions "
    "(rejected ones excluded)",
)
def accept_suggested_topics(
    document_id: uuid.UUID, session: DbSession, user: CurrentUser
) -> TopicAcceptResult:
    accepted, patterns = QuestionService(session, user.id).accept_suggested_topics(document_id)
    return TopicAcceptResult(accepted=accepted, patterns_accepted=patterns)
