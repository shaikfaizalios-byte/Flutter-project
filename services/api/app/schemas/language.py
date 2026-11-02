"""The content-language type used by every request and response (global Phase 10)."""

from typing import Annotated

from pydantic import AfterValidator, Field

from app.domain.languages import CODES, is_supported


def _supported(code: str) -> str:
    if not is_supported(code):
        raise ValueError(f"language must be one of: {', '.join(CODES)}")
    return code


# A supported content language code (see app/domain/languages.py). The OpenAPI schema lists
# the codes, so clients see the same reference list.
Language = Annotated[
    str, AfterValidator(_supported), Field(json_schema_extra={"enum": list(CODES)})
]
