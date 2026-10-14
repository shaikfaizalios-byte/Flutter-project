"""Request dependencies shared by endpoints: the signed-in user."""

from typing import Annotated

from fastapi import Depends, Request
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer

from app.core.security import TokenSigner
from app.database.session import DbSession
from app.domain.errors import UnauthorizedError
from app.models.user import User

_bearer = HTTPBearer(auto_error=False, description="Access token from /auth/login")


def get_token_signer(request: Request) -> TokenSigner:
    signer: TokenSigner = request.app.state.token_signer
    return signer


def get_current_user(
    session: DbSession,
    signer: Annotated[TokenSigner, Depends(get_token_signer)],
    credentials: Annotated[HTTPAuthorizationCredentials | None, Depends(_bearer)],
) -> User:
    """The account behind the request's Bearer access token, or 401."""
    if credentials is None or credentials.scheme.lower() != "bearer":
        raise UnauthorizedError("Sign in to continue.")
    user = session.get(User, signer.user_id(credentials.credentials))
    if user is None:
        raise UnauthorizedError("This account no longer exists.")
    return user


CurrentUser = Annotated[User, Depends(get_current_user)]


def client_key(request: Request, user: User | None = None) -> str:
    """Rate-limit key: the account when known, otherwise the client address."""
    if user is not None:
        return f"user:{user.id}"
    return f"ip:{request.client.host if request.client else 'unknown'}"
