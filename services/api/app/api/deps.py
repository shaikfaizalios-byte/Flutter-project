"""Request dependencies shared by endpoints: the signed-in user."""

import uuid
from typing import Annotated

from fastapi import Depends, Request
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from sqlalchemy import select

from app.core.security import TokenSigner
from app.database.session import DbSession
from app.domain.errors import UnauthorizedError
from app.models.user import RefreshToken, User

_bearer = HTTPBearer(auto_error=False, description="Access token from /auth/login")


def get_token_signer(request: Request) -> TokenSigner:
    signer: TokenSigner = request.app.state.token_signer
    return signer


def get_current_user(
    request: Request,
    session: DbSession,
    signer: Annotated[TokenSigner, Depends(get_token_signer)],
    credentials: Annotated[HTTPAuthorizationCredentials | None, Depends(_bearer)],
) -> User:
    """The account behind the request's Bearer access token, or 401.

    A token of a signed-out device (its refresh-token family revoked: sign-out, remote
    sign-out, password reset or token reuse) is refused at once.
    """
    if credentials is None or credentials.scheme.lower() != "bearer":
        raise UnauthorizedError("Sign in to continue.")
    claims = signer.claims(credentials.credentials)
    user = session.get(User, claims.user_id)
    if user is None:
        raise UnauthorizedError("This account no longer exists.")
    if claims.session_id is not None:
        active = session.scalar(
            select(RefreshToken.id)
            .where(
                RefreshToken.family_id == claims.session_id,
                RefreshToken.user_id == user.id,
                RefreshToken.revoked_at.is_(None),
            )
            .limit(1)
        )
        if active is None:
            raise UnauthorizedError("This device was signed out. Please sign in again.")
    request.state.session_id = claims.session_id
    return user


CurrentUser = Annotated[User, Depends(get_current_user)]


def get_current_session_id(request: Request, user: CurrentUser) -> uuid.UUID | None:
    """The signed-in device of the request (None for tokens issued before sessions)."""
    session_id: uuid.UUID | None = getattr(request.state, "session_id", None)
    return session_id


CurrentSessionId = Annotated[uuid.UUID | None, Depends(get_current_session_id)]


def client_key(request: Request, user: User | None = None) -> str:
    """Rate-limit key: the account when known, otherwise the client address."""
    if user is not None:
        return f"user:{user.id}"
    return f"ip:{request.client.host if request.client else 'unknown'}"
