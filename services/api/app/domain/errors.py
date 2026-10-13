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


class RateLimitedError(DomainError):
    status_code = 429
    code = "rate_limited"

    def __init__(self, message: str, retry_after_seconds: int) -> None:
        super().__init__(message)
        self.retry_after_seconds = retry_after_seconds
