"""Reading question papers published with official question and option IDs. Pure.

These papers print each question as a header line ("Question Number : 3 Question Id : 6911213
Question Type : MCQ ...") with the question and each option drawn as an image, and each option
labelled by its own ID. So a question can be taken exactly as printed: no text is read from the
pictures, and an answer key can be matched by ID rather than by position.

Works on page layouts (app/domain/figures.py), so nothing here touches a PDF.
"""

import re
from collections.abc import Iterable, Sequence
from dataclasses import dataclass, field

from app.domain.figures import Box, PageLayout

HEADER = re.compile(
    r"Question Number\s*:\s*(?P<number>\d+)\s+Question Id\s*:\s*(?P<id>\d+)\s+"
    r"Question Type\s*:\s*(?P<type>[A-Z]+)"
)
SECTION = re.compile(r"^\s*(?P<subject>[A-Z][A-Za-z &]+?)\s+Section\s+(?P<part>[A-Z])\s*$")
OPTIONS = re.compile(r"^\s*Options\s*:\s*$")
OPTION = re.compile(r"^\s*(?P<id>\d{5,})\.\s*(?P<text>.*)$")
# Lines of a typed-answer question that describe its entry box.
ENTRY_BOX = re.compile(
    r"^\s*(Response Type|Evaluation Required|Show Word Count|Answers Type|Text Areas|"
    r"Possible Answers|Question Mandatory|Keyboard Layout)\b"
)
MIN_IMAGE_SIDE = 6.0
MIN_QUESTIONS = 5  # fewer headers than this isn't one of these papers
CROP_PADDING = 1.0


@dataclass(frozen=True, slots=True)
class Crop:
    page: int
    box: Box


@dataclass(slots=True)
class OfficialOption:
    external_id: str
    text: str = ""
    crops: list[Crop] = field(default_factory=list)


@dataclass(slots=True)
class OfficialQuestion:
    number: int
    external_id: str
    kind: str  # the paper's own word: MCQ, SA, ...
    subject: str | None
    part: str | None
    page: int
    text: str = ""
    crops: list[Crop] = field(default_factory=list)
    options: list[OfficialOption] = field(default_factory=list)

    @property
    def section(self) -> str | None:
        return f"{self.subject} Section {self.part}" if self.subject and self.part else None


def is_official_paper(pages_text: Iterable[str]) -> bool:
    return sum(len(HEADER.findall(text)) for text in pages_text) >= MIN_QUESTIONS


@dataclass(frozen=True, slots=True)
class _Anchor:
    top: float
    bottom: float
    kind: str  # header | section | options | option | text | image
    text: str = ""
    box: Box | None = None


def _anchors(layout: PageLayout) -> list[_Anchor]:
    found = [_Anchor(ln.box.top, ln.box.bottom, "text", ln.text) for ln in layout.lines]
    found += [
        _Anchor(g.box.top, g.box.bottom, "image", box=g.box)
        for g in layout.graphics
        if g.kind == "image" and min(g.box.width, g.box.height) >= MIN_IMAGE_SIDE
    ]
    return sorted(found, key=lambda a: -((a.top + a.bottom) / 2))


def _padded(box: Box) -> Box:
    return Box(
        box.left - CROP_PADDING,
        box.bottom - CROP_PADDING,
        box.right + CROP_PADDING,
        box.top + CROP_PADDING,
    )


def read_official_paper(layouts: Sequence[PageLayout]) -> list[OfficialQuestion]:
    """Every question in printed order, each with its crops. An image next to an option label
    belongs to that option; the rest of a question's images are the question."""
    questions: list[OfficialQuestion] = []
    subject: str | None = None
    part: str | None = None
    current: OfficialQuestion | None = None
    in_options = placing_options = False
    for layout in layouts:
        anchors = _anchors(layout)
        labels: list[tuple[float, OfficialOption]] = []
        for anchor in anchors:
            middle = (anchor.top + anchor.bottom) / 2
            if anchor.kind == "image":
                continue
            header = HEADER.search(anchor.text)
            section = SECTION.match(anchor.text)
            option = OPTION.match(anchor.text)
            if header:
                current = OfficialQuestion(
                    int(header["number"]),
                    header["id"],
                    header["type"],
                    subject,
                    part,
                    layout.number,
                )
                questions.append(current)
                in_options = False
            elif section:
                subject, part = section["subject"].strip(), section["part"]
                current, in_options = None, False
            elif current is None:
                continue
            elif OPTIONS.match(anchor.text):
                in_options = True
            elif in_options and option:
                entry = OfficialOption(option["id"], option["text"].strip())
                current.options.append(entry)
                labels.append((middle, entry))
        placing_options = _place_images(layout, anchors, labels, questions, placing_options)
    return questions


def _place_images(
    layout: PageLayout,
    anchors: Sequence[_Anchor],
    labels: Sequence[tuple[float, OfficialOption]],
    questions: Sequence[OfficialQuestion],
    in_options: bool,
) -> bool:
    """Walks the page top to bottom, knowing which question each image falls under. Returns
    whether the page ended among a question's options."""
    number_on_page = [q for q in questions if q.page == layout.number]
    index = -1
    owner = _before(questions, number_on_page)
    for anchor in anchors:
        if anchor.kind == "image":
            if owner is None or anchor.box is None:
                continue
            middle = (anchor.top + anchor.bottom) / 2
            crop = Crop(layout.number, _padded(anchor.box))
            near = [pair for pair in labels if pair[1] in owner.options]
            if in_options and near:
                min(near, key=lambda pair: abs(pair[0] - middle))[1].crops.append(crop)
            elif in_options and owner.options:
                owner.options[-1].crops.append(crop)
            else:
                owner.crops.append(crop)
            continue
        if HEADER.search(anchor.text):
            index += 1
            owner = number_on_page[index]
            in_options = False
        elif SECTION.match(anchor.text):
            owner = None
        elif OPTIONS.match(anchor.text):
            in_options = True
        elif owner is not None and not in_options and not ENTRY_BOX.match(anchor.text):
            line = anchor.text.strip()
            if line and not line.isdigit():
                owner.text = f"{owner.text} {line}".strip()
    return in_options


def _before(
    questions: Sequence[OfficialQuestion], on_page: Sequence[OfficialQuestion]
) -> OfficialQuestion | None:
    """The question running over from the page before."""
    if on_page:
        at = questions.index(on_page[0])
        return questions[at - 1] if at else None
    return questions[-1] if questions else None
