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
