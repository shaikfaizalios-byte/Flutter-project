"""Domain errors raised by services and mapped to HTTP responses in app.core.errors."""


class DomainError(Exception):
    status_code = 400
    code = "domain_error"

    def __init__(self, message: str) -> None:
        super().__init__(message)
        self.message = message


class NotFoundError(DomainError):
    status_code = 404
    code = "not_found"


class InvalidReferenceError(DomainError):
    """A request referenced another entity that does not exist (e.g. an unknown exam)."""

    status_code = 422
    code = "invalid_reference"


class UploadTooLargeError(DomainError):
    status_code = 413
    code = "file_too_large"


class UnsupportedFileTypeError(DomainError):
    status_code = 415
    code = "unsupported_file_type"


class InvalidDocumentError(DomainError):
    """The file is a PDF in name only, damaged, encrypted, empty or too long."""

    status_code = 422

    def __init__(self, code: str, message: str) -> None:
        super().__init__(message)
        self.code = code


class ConflictError(DomainError):
    """The request is valid but the resource is not in a state that allows it."""

    status_code = 409

    def __init__(self, code: str, message: str) -> None:
        super().__init__(message)
        self.code = code


class RateLimitedError(DomainError):
    status_code = 429
    code = "rate_limited"

    def __init__(self, message: str, retry_after_seconds: int) -> None:
        super().__init__(message)
        self.retry_after_seconds = retry_after_seconds


class PlusRequiredError(DomainError):
    """The AI features need an active PrepLoop Plus subscription."""

    status_code = 403
    code = "plus_required"


class AIAllowanceUsedError(RateLimitedError):
    """This month's AI allowance is used up; it resets at the start of next month (UTC)."""

    code = "ai_allowance_used"


class AIDisabledError(DomainError):
    """AI assistance is not configured on this server (no provider key)."""

    status_code = 503
    code = "ai_disabled"


class AIUnavailableError(DomainError):
    """The AI provider failed or returned unusable output; usually worth retrying."""

    status_code = 502
    code = "ai_unavailable"


class NotEligibleError(DomainError):
    """The item does not meet the rules for this action (e.g. AI on unverified content)."""

    status_code = 422
    code = "not_eligible"


class UnauthorizedError(DomainError):
    """Missing, malformed or expired credentials."""

    status_code = 401
    code = "unauthorized"


class InvalidCredentialsError(DomainError):
    status_code = 401
    code = "invalid_credentials"


class EmailTakenError(DomainError):
    status_code = 409
    code = "email_taken"


class InvalidCodeError(DomainError):
    """A one-time code is wrong, expired, used up or unknown (all look the same)."""

    status_code = 400
    code = "invalid_code"
