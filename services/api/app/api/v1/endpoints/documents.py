import uuid
from typing import Annotated, Any

from fastapi import APIRouter, Depends, File, Form, Query, Request, UploadFile, status

from app.core.config import Settings, get_settings
from app.database.session import DbSession
from app.domain.errors import UploadTooLargeError
from app.schemas.concept import Language
from app.schemas.document import (
    DocumentPageList,
    DocumentRead,
    DocumentStatusLiteral,
    PageList,
)
from app.schemas.errors import ErrorResponse
from app.services.document_service import DocumentService

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
    request: Request, session: DbSession, settings: Annotated[Settings, Depends(get_settings)]
) -> DocumentService:
    return DocumentService(session, request.app.state.document_storage, settings)


Service = Annotated[DocumentService, Depends(get_document_service)]


def guard_upload(request: Request, settings: Annotated[Settings, Depends(get_settings)]) -> None:
    """Runs before the body is parsed: rate limit, and reject declared oversize bodies early
    (the streaming copy enforces the limit again for bodies without a length)."""
    client = request.client.host if request.client else "unknown"
    request.app.state.upload_rate_limiter.check(client)
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
) -> DocumentRead:
    return service.upload(
        stream=file.file, filename=file.filename, exam_code=exam_code, language=language
    )


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


@router.delete(
    "/{document_id}",
    status_code=status.HTTP_204_NO_CONTENT,
    responses=NOT_FOUND,
    summary="Permanently delete a document, its pages and the original file",
)
def delete_document(document_id: uuid.UUID, service: Service) -> None:
    service.delete(document_id)
