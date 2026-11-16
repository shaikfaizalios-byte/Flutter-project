"""Snap a question: a photo read with OCR and matched against the learner's own material."""

from typing import Annotated

from fastapi import APIRouter, Depends, File, Form, Request, UploadFile

from app.api.deps import CurrentUser
from app.api.v1.endpoints.documents import guard_upload
from app.core.config import Settings, get_settings
from app.database.session import DbSession
from app.schemas.errors import ErrorResponse
from app.schemas.language import Language
from app.schemas.snap import SnapMatch, SnapMatchRequest, SnapRead
from app.services.snap_service import MAX_PHOTO_BYTES, PhotoTooLargeError, SnapService

router = APIRouter(tags=["search"])


def _service(
    request: Request, session: DbSession, user: CurrentUser, settings: Settings
) -> SnapService:
    return SnapService(session, user.id, settings, request.app.state.ocr_engine)


@router.post(
    "/search/photo",
    response_model=SnapRead,
    dependencies=[Depends(guard_upload)],
    responses={413: {"model": ErrorResponse}, 422: {"model": ErrorResponse}},
    summary="Read a photo of a question and find it in your material (nothing is stored)",
)
def search_photo(
    request: Request,
    session: DbSession,
    user: CurrentUser,
    settings: Annotated[Settings, Depends(get_settings)],
    photo: Annotated[UploadFile, File(description="A photo of the question: JPEG, PNG or WebP")],
    exam_code: Annotated[str, Form(max_length=32)],
    language: Annotated[Language, Form(description="Language the question is printed in")] = "en",
) -> SnapRead:
    data = photo.file.read(MAX_PHOTO_BYTES + 1)
    if len(data) > MAX_PHOTO_BYTES:
        raise PhotoTooLargeError("The photo is too large (12 MB at most).")
    return _service(request, session, user, settings).read_photo(exam_code, data, language)


@router.post(
    "/search/match",
    response_model=list[SnapMatch],
    summary="Find text (a corrected photo reading) in your material",
)
def search_match(
    body: SnapMatchRequest,
    request: Request,
    session: DbSession,
    user: CurrentUser,
    settings: Annotated[Settings, Depends(get_settings)],
) -> list[SnapMatch]:
    return _service(request, session, user, settings).match_text(body.exam_code, body.text)
