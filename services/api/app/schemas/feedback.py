import uuid
from datetime import datetime
from typing import Annotated, Literal

from pydantic import BaseModel, ConfigDict, StringConstraints

SUGGESTION_MIN = 10
SUGGESTION_MAX = 2000
# Suggestions one account may send per day (spam guard; mobile `SuggestionRules` matches).
SUGGESTIONS_PER_DAY = 10

SuggestionKind = Literal["add", "remove", "change", "other"]


class SuggestionCreate(BaseModel):
    model_config = ConfigDict(extra="forbid")

    kind: SuggestionKind
    text: Annotated[
        str,
        StringConstraints(
            strip_whitespace=True, min_length=SUGGESTION_MIN, max_length=SUGGESTION_MAX
        ),
    ]


class SuggestionRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    kind: SuggestionKind
    text: str
    status: Literal["new", "read", "planned", "done", "declined"]
    created_at: datetime
