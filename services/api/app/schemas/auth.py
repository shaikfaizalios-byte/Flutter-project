import uuid
from datetime import datetime
from typing import Annotated, Any, Literal

from pydantic import BaseModel, ConfigDict, Field, StringConstraints, field_validator

# NIST SP 800-63B: length matters, composition rules do not: 10 to 128 characters.
PASSWORD_MIN = 10
PASSWORD_MAX = 128

Password = Annotated[str, Field(min_length=PASSWORD_MIN, max_length=PASSWORD_MAX)]

# Minimum age to create an account (self-declared at sign-up). 18 because India's DPDP Act treats
# anyone younger as a child needing verifiable parental consent, which PrepLoop doesn't collect.
# Mobile `AuthRules.minimumAge` must match.
MINIMUM_AGE = 18


class _EmailInput(BaseModel):
    model_config = ConfigDict(extra="forbid")

    email: Annotated[str, StringConstraints(strip_whitespace=True, min_length=3, max_length=254)]

    @field_validator("email")
    @classmethod
    def _normalise(cls, value: str) -> str:
        email = value.strip().lower()
        local, _, domain = email.partition("@")
        if not local or "." not in domain or " " in email or email.count("@") != 1:
            raise ValueError("Enter a valid email address.")
        return email


class RegisterRequest(_EmailInput):
    password: Password
    # The learner confirms they are at least MINIMUM_AGE; sign-up is refused without it.
    confirms_minimum_age: Literal[True] = Field(
        description=f"Must be true: the learner confirms they are at least {MINIMUM_AGE}."
    )
    display_name: (
        Annotated[str, StringConstraints(strip_whitespace=True, min_length=1, max_length=100)]
        | None
    ) = None


class LoginRequest(_EmailInput):
    # No minimum here: old accounts must still be able to sign in if rules change.
    password: Annotated[str, Field(min_length=1, max_length=PASSWORD_MAX)]


class RefreshRequest(BaseModel):
    model_config = ConfigDict(extra="forbid")

    refresh_token: Annotated[str, StringConstraints(min_length=20, max_length=200)]


class DeleteAccountRequest(BaseModel):
    model_config = ConfigDict(extra="forbid")

    password: Annotated[str, Field(min_length=1, max_length=PASSWORD_MAX)]


class UserRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    email: str
    display_name: str | None
    email_verified: bool
    created_at: datetime


class TokenPair(BaseModel):
    access_token: str
    refresh_token: str
    token_type: str = "bearer"  # noqa: S105 - the OAuth token type name, not a secret
    # Seconds until the access token expires.
    expires_in: int
    user: UserRead


class AccountExport(BaseModel):
    """Everything the server holds for the account (privacy export)."""

    exported_at: datetime
    user: UserRead
    data: dict[str, list[dict[str, Any]]]


Code = Annotated[str, StringConstraints(strip_whitespace=True, pattern=r"^[0-9]{6}$")]


class PasswordResetRequest(_EmailInput):
    pass


class PasswordResetConfirm(_EmailInput):
    code: Code
    new_password: Password


class VerifyEmailConfirm(BaseModel):
    model_config = ConfigDict(extra="forbid")

    code: Code


class Accepted(BaseModel):
    detail: str
