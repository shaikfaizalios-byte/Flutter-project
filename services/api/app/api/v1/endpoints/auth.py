import logging
from typing import Annotated, Any

from fastapi import APIRouter, BackgroundTasks, Depends, Request, Response, status

from app.api.deps import CurrentUser, client_key, get_token_signer
from app.core.config import Settings, get_settings
from app.core.security import TokenSigner
from app.database.session import DbSession
from app.integrations.email import EmailSender, OutgoingEmail
from app.schemas.auth import (
    Accepted,
    AccountExport,
    DeleteAccountRequest,
    LoginRequest,
    PasswordResetConfirm,
    PasswordResetRequest,
    RefreshRequest,
    RegisterRequest,
    TokenPair,
    UserRead,
    VerifyEmailConfirm,
)
from app.schemas.errors import ErrorResponse
from app.services.auth_service import AuthService

logger = logging.getLogger(__name__)

router = APIRouter(
    prefix="/auth",
    tags=["auth"],
    responses={503: {"model": ErrorResponse, "description": "Database unavailable"}},
)

UNAUTHORIZED: dict[int | str, dict[str, Any]] = {
    401: {"model": ErrorResponse, "description": "Not signed in / invalid"}
}


def get_auth_service(
    session: DbSession,
    signer: Annotated[TokenSigner, Depends(get_token_signer)],
    settings: Annotated[Settings, Depends(get_settings)],
) -> AuthService:
    return AuthService(session, signer, settings)


Service = Annotated[AuthService, Depends(get_auth_service)]


def _limit(request: Request, email: str) -> None:
    """Brute-force guard for sign-in and registration (per client address and email)."""
    request.app.state.auth_rate_limiter.check(f"{client_key(request)}:{email}")


@router.post(
    "/register",
    response_model=TokenPair,
    status_code=status.HTTP_201_CREATED,
    responses={409: {"model": ErrorResponse, "description": "Email already registered"}},
    summary="Create an account (the first account claims data created before accounts)",
)
def register(
    body: RegisterRequest, request: Request, service: Service, background: BackgroundTasks
) -> TokenPair:
    _limit(request, body.email)
    pair = service.register(body.email, body.password, body.display_name)
    _send(request, background, service.request_verification(service.user(pair.user.id)))
    return pair


@router.post("/login", response_model=TokenPair, responses=UNAUTHORIZED, summary="Sign in")
def login(body: LoginRequest, request: Request, service: Service) -> TokenPair:
    _limit(request, body.email)
    return service.login(body.email, body.password)


@router.post(
    "/refresh",
    response_model=TokenPair,
    responses=UNAUTHORIZED,
    summary="Exchange a refresh token for new tokens (rotation; reuse revokes the session)",
)
def refresh(body: RefreshRequest, service: Service) -> TokenPair:
    return service.refresh(body.refresh_token)


@router.post(
    "/logout",
    status_code=status.HTTP_204_NO_CONTENT,
    summary="Revoke this device's session (refresh-token family)",
)
def logout(body: RefreshRequest, service: Service) -> Response:
    service.logout(body.refresh_token)
    return Response(status_code=status.HTTP_204_NO_CONTENT)


@router.get("/me", response_model=UserRead, responses=UNAUTHORIZED, summary="The signed-in account")
def me(user: CurrentUser) -> UserRead:
    return UserRead.model_validate(user)


@router.get(
    "/me/export",
    response_model=AccountExport,
    responses=UNAUTHORIZED,
    summary="Download everything the server holds for this account",
)
def export(user: CurrentUser, service: Service) -> AccountExport:
    return service.export(user)


@router.post(
    "/me/delete",
    status_code=status.HTTP_204_NO_CONTENT,
    responses=UNAUTHORIZED,
    summary="Permanently delete the account and all its data (password required)",
)
def delete_account(
    body: DeleteAccountRequest, request: Request, user: CurrentUser, service: Service
) -> Response:
    service.delete_account(user, body.password, request.app.state.document_storage)
    return Response(status_code=status.HTTP_204_NO_CONTENT)


def _send(request: Request, background: BackgroundTasks, email: OutgoingEmail | None) -> None:
    """Sends after the response, so timing never reveals whether an account exists."""
    if email is not None:
        background.add_task(_deliver, request.app.state.email_sender, email)


def _deliver(sender: EmailSender, email: OutgoingEmail) -> None:
    try:
        sender.send(email)
    except Exception:
        logger.warning("An account email could not be sent")


ACCEPTED = "If an account exists for this email, a code has been sent."


@router.post(
    "/password-reset/request",
    response_model=Accepted,
    status_code=status.HTTP_202_ACCEPTED,
    summary="Email a 6-digit reset code (same answer whether or not the account exists)",
)
def request_password_reset(
    body: PasswordResetRequest, request: Request, service: Service, background: BackgroundTasks
) -> Accepted:
    _limit(request, body.email)
    _send(request, background, service.request_password_reset(body.email))
    return Accepted(detail=ACCEPTED)


@router.post(
    "/password-reset/confirm",
    status_code=status.HTTP_204_NO_CONTENT,
    responses={400: {"model": ErrorResponse, "description": "invalid_code"}},
    summary="Set a new password with the emailed code (signs out every device)",
)
def confirm_password_reset(
    body: PasswordResetConfirm, request: Request, service: Service
) -> Response:
    _limit(request, body.email)
    service.confirm_password_reset(body.email, body.code, body.new_password)
    return Response(status_code=status.HTTP_204_NO_CONTENT)


@router.post(
    "/verify-email/request",
    response_model=Accepted,
    status_code=status.HTTP_202_ACCEPTED,
    responses=UNAUTHORIZED,
    summary="Email a 6-digit code to confirm the account's address",
)
def request_verification(
    request: Request, user: CurrentUser, service: Service, background: BackgroundTasks
) -> Accepted:
    _limit(request, user.email)
    _send(request, background, service.request_verification(user))
    return Accepted(detail="If the email is not confirmed yet, a code has been sent.")


@router.post(
    "/verify-email/confirm",
    response_model=UserRead,
    responses={**UNAUTHORIZED, 400: {"model": ErrorResponse, "description": "invalid_code"}},
    summary="Confirm the account's email with the emailed code",
)
def confirm_verification(
    body: VerifyEmailConfirm, request: Request, user: CurrentUser, service: Service
) -> UserRead:
    _limit(request, user.email)
    return UserRead.model_validate(service.confirm_verification(user, body.code))
