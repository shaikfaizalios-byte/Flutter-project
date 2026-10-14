from typing import Annotated, Any

from fastapi import APIRouter, Depends, Request, Response, status

from app.api.deps import CurrentUser, client_key, get_token_signer
from app.core.config import Settings, get_settings
from app.core.security import TokenSigner
from app.database.session import DbSession
from app.schemas.auth import (
    AccountExport,
    DeleteAccountRequest,
    LoginRequest,
    RefreshRequest,
    RegisterRequest,
    TokenPair,
    UserRead,
)
from app.schemas.errors import ErrorResponse
from app.services.auth_service import AuthService

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
def register(body: RegisterRequest, request: Request, service: Service) -> TokenPair:
    _limit(request, body.email)
    return service.register(body.email, body.password, body.display_name)


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
