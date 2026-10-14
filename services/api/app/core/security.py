"""Password hashing and tokens.

- Passwords: Argon2id (argon2-cffi defaults, RFC 9106 "low memory" profile); hashes are
  upgraded on login when parameters change.
- Access tokens: short-lived HS256 JWTs (``type=access``) with issuer/audience checks.
- Refresh tokens: random opaque strings; only their SHA-256 is stored, so a database leak
  does not reveal usable tokens.
"""

import hashlib
import secrets
import uuid
from dataclasses import dataclass
from datetime import UTC, datetime, timedelta

import jwt
from argon2 import PasswordHasher
from argon2.exceptions import InvalidHashError, VerificationError, VerifyMismatchError

from app.domain.errors import UnauthorizedError

ISSUER = "preploop-api"
AUDIENCE = "preploop-app"
ALGORITHM = "HS256"

_hasher = PasswordHasher()
# Used when the email is unknown so both paths take similar time (no user enumeration).
_DUMMY_HASH = _hasher.hash("not-a-real-password-" + secrets.token_hex(8))


def hash_password(password: str) -> str:
    return _hasher.hash(password)


def verify_password(password_hash: str | None, password: str) -> bool:
    try:
        return _hasher.verify(password_hash or _DUMMY_HASH, password) and password_hash is not None
    except (VerifyMismatchError, VerificationError, InvalidHashError):
        return False


def needs_rehash(password_hash: str) -> bool:
    return _hasher.check_needs_rehash(password_hash)


def new_refresh_token() -> str:
    return secrets.token_urlsafe(48)


def hash_refresh_token(token: str) -> str:
    return hashlib.sha256(token.encode()).hexdigest()


@dataclass(frozen=True, slots=True)
class TokenSigner:
    """Signs and checks access tokens with the server secret."""

    secret: str
    access_minutes: int

    def access_token(self, user_id: uuid.UUID, *, now: datetime | None = None) -> str:
        issued = now or datetime.now(UTC)
        return jwt.encode(
            {
                "sub": str(user_id),
                "type": "access",
                "iss": ISSUER,
                "aud": AUDIENCE,
                "iat": issued,
                "exp": issued + timedelta(minutes=self.access_minutes),
                "jti": secrets.token_hex(8),
            },
            self.secret,
            algorithm=ALGORITHM,
        )

    def user_id(self, token: str) -> uuid.UUID:
        """The user of a valid access token; raises ``UnauthorizedError`` otherwise."""
        try:
            claims = jwt.decode(
                token,
                self.secret,
                algorithms=[ALGORITHM],
                audience=AUDIENCE,
                issuer=ISSUER,
                options={"require": ["sub", "exp", "iat", "type"]},
            )
        except jwt.ExpiredSignatureError as exc:
            raise UnauthorizedError("Your session has expired. Please sign in again.") from exc
        except jwt.InvalidTokenError as exc:
            raise UnauthorizedError("Invalid access token.") from exc
        if claims.get("type") != "access":
            raise UnauthorizedError("Invalid access token.")
        try:
            return uuid.UUID(str(claims["sub"]))
        except ValueError as exc:
            raise UnauthorizedError("Invalid access token.") from exc
