"""Consistent JSON error responses. Internal details are logged, never returned."""

import logging
from http import HTTPStatus

from fastapi import FastAPI, Request
from fastapi.exceptions import RequestValidationError
from fastapi.responses import JSONResponse
from sqlalchemy.exc import OperationalError
from starlette.exceptions import HTTPException as StarletteHTTPException

from app.core.logging import request_id_var
from app.domain.errors import DomainError, RateLimitedError
from app.schemas.errors import ErrorBody, ErrorDetail, ErrorResponse

logger = logging.getLogger("app.errors")


def _response(
    status_code: int,
    code: str,
    message: str,
    details: list[ErrorDetail] | None = None,
) -> JSONResponse:
    body = ErrorResponse(
        error=ErrorBody(
            code=code,
            message=message,
            request_id=request_id_var.get(),
            details=details or [],
        )
    )
    return JSONResponse(status_code=status_code, content=body.model_dump(mode="json"))


def _status_code_name(status_code: int) -> str:
    try:
        return HTTPStatus(status_code).name.lower()
    except ValueError:
        return "http_error"


async def http_exception_handler(_: Request, exc: Exception) -> JSONResponse:
    assert isinstance(exc, StarletteHTTPException)  # noqa: S101
    message = exc.detail if isinstance(exc.detail, str) else "Request failed."
    return _response(exc.status_code, _status_code_name(exc.status_code), message)


async def validation_exception_handler(_: Request, exc: Exception) -> JSONResponse:
    assert isinstance(exc, RequestValidationError)  # noqa: S101
    details = [
        ErrorDetail(
            field=".".join(str(part) for part in err.get("loc", ())),
            message=str(err.get("msg", "Invalid value.")),
        )
        for err in exc.errors()
    ]
    return _response(422, "validation_error", "The request is invalid.", details)


async def domain_error_handler(_: Request, exc: Exception) -> JSONResponse:
    assert isinstance(exc, DomainError)  # noqa: S101
    response = _response(exc.status_code, exc.code, exc.message)
    if isinstance(exc, RateLimitedError):
        response.headers["Retry-After"] = str(exc.retry_after_seconds)
    if exc.status_code == 401:
        response.headers["WWW-Authenticate"] = "Bearer"
    return response


async def database_unavailable_handler(_: Request, exc: Exception) -> JSONResponse:
    # Driver messages can contain host/user names: log the class only.
    logger.warning("database unavailable: %s", type(exc).__name__)
    return _response(503, "database_unavailable", "The database is temporarily unavailable.")


async def unhandled_exception_handler(_: Request, exc: Exception) -> JSONResponse:
    logger.exception("unhandled error", exc_info=exc)
    return _response(500, "internal_error", "An unexpected error occurred.")


def register_exception_handlers(app: FastAPI) -> None:
    app.add_exception_handler(StarletteHTTPException, http_exception_handler)
    app.add_exception_handler(RequestValidationError, validation_exception_handler)
    app.add_exception_handler(DomainError, domain_error_handler)
    app.add_exception_handler(OperationalError, database_unavailable_handler)
    app.add_exception_handler(Exception, unhandled_exception_handler)
