"""Links to figures that a CDN can cache (app/domain/media.py)."""

import hashlib
import secrets
import time
from collections.abc import Iterable
from functools import cache

from app.core.config import get_settings
from app.domain import media
from app.models.question import QuestionFigure
from app.schemas.question import FigureRead

ROUTE = "/api/v1/media/figures"


@cache
def _process_key() -> bytes:
    return secrets.token_bytes(32)


def media_key() -> bytes:
    """Derived from the auth secret, so every server process signs alike. Without one (development
    only), each process has its own."""
    secret = get_settings().auth_secret
    base = secret.get_secret_value().encode() if secret else _process_key()
    return hashlib.sha256(b"preploop-media:" + base).digest()


def figure_url(sha256: str, now: int | None = None) -> str:
    settings = get_settings()
    moment = int(time.time()) if now is None else now
    expires = media.window_expiry(moment, settings.media_url_hours)
    sig = media.signature(sha256, expires, media_key())
    base = (settings.media_base_url or "").rstrip("/")
    return f"{base}{ROUTE}/{sha256}.png?e={expires}&s={sig}"


def figure_reads(figures: Iterable[QuestionFigure], *, public: bool) -> list[FigureRead]:
    """Figures as the app reads them; those every learner may see also get a cacheable link."""
    reads = []
    for figure in figures:
        read = FigureRead.model_validate(figure)
        if public and figure.sha256:
            read = read.model_copy(update={"url": figure_url(figure.sha256)})
        reads.append(read)
    return reads
