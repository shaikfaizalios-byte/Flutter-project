"""Current affairs cards drafted by AI from the learner's own sources. Nothing is stored."""

from typing import Annotated

from pydantic import BaseModel, ConfigDict, StringConstraints

from app.domain.current_affairs import TEXT_MAX
from app.schemas.language import Language


class CurrentAffairsText(BaseModel):
    model_config = ConfigDict(extra="forbid")

    exam_code: str
    text: Annotated[
        str, StringConstraints(strip_whitespace=True, min_length=20, max_length=TEXT_MAX)
    ]
    language: Language = "en"


class CurrentAffairsCard(BaseModel):
    front: str
    back: str
    source_label: str  # "Pasted text", "news.pdf, page 3"
    quote: str  # the material's own words the card comes from (checked to be there)


class CurrentAffairsDraft(BaseModel):
    """AI-generated drafts: the learner approves each one before it is saved."""

    cards: list[CurrentAffairsCard]
    dropped: int  # drafts whose quote wasn't found in the material, or malformed
    left_out: bool  # the material was too long: only its start was read
    no_text: bool = False  # nothing could be read (a scan OCR couldn't read, an empty file)
    model: str | None = None
