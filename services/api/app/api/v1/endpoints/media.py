"""Figures for a CDN. No sign-in: the link itself is the permission, and it expires."""

import time
from typing import Annotated

from fastapi import APIRouter, Path, Query, Response
from sqlalchemy import select
from sqlalchemy.orm import undefer

from app.core.config import get_settings
from app.database.session import DbSession
from app.domain import media
from app.domain.errors import NotFoundError
from app.models.question import QuestionFigure
from app.services.media import media_key

router = APIRouter(prefix="/media", tags=["media"])


@router.get(
    "/figures/{sha256}.png",
    response_class=Response,
    summary="A figure by the hash of its bytes, through a signed link",
    responses={200: {"content": {"image/png": {}}}},
)
def figure(
    session: DbSession,
    sha256: Annotated[str, Path(pattern=r"^[0-9a-f]{64}$")],
    e: Annotated[int, Query(ge=0)],
    s: Annotated[str, Query(min_length=8, max_length=64)],
) -> Response:
    now = int(time.time())
    if not media.valid(sha256, e, s, media_key(), now):
        raise NotFoundError("Figure not found.")
    found = session.scalars(
        select(QuestionFigure)
        .where(QuestionFigure.sha256 == sha256)
        .options(undefer(QuestionFigure.data))
        .limit(1)
    ).first()
    if found is None:
        raise NotFoundError("Figure not found.")
    seconds = media.cache_seconds(e, now, get_settings().media_url_hours * 3600)
    return Response(
        content=found.data,
        media_type=found.content_type,
        headers={"Cache-Control": f"public, max-age={seconds}, immutable"},
    )
