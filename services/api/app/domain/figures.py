"""Finding the figures that belong to each question, from a page's layout.

A PDF's text layer has no pictures: Venn diagrams, figure series, charts and formulas drawn
as vector paths are lost when only text is read. This module works on a page *layout* (text
lines with their positions, plus image and vector-graphic objects) and decides, without
guessing beyond the geometry:

* which graphics are page decoration (logos, footer rules repeated on most pages),
* which graphics form a figure (clusters of touching objects of a visible size),
* which text lines are labels inside a figure (chart values, axis labels) and so belong to the
  figure instead of the question text,
* which question, and which option of it, each figure belongs to.

Coordinates are PDF points with the origin at the bottom-left of the page (y grows upwards).
Everything here is pure; reading PDFs and rendering crops lives in
``app.services.page_layout``. Pages that do not fit the rules (several text columns,
rotated pages, too many objects) are skipped and left to the text-only checks.
"""

import math
import re
from collections import Counter
from collections.abc import Sequence
from dataclasses import dataclass, field

from app.domain.segmentation import (
    ANSWER_KEY_HEADING,
    EXPLANATION_HEADING,
    OPTION_INLINE,
    OPTION_LINE_START,
    PASSAGE_START,
    WEAK_QUESTION,
    ParsedQuestion,
    section_heading,
    strong_start,
)

# A figure must be at least this big (points) in both directions and in area; thinner marks
# are underlines, fraction bars and table rules.
MIN_FIGURE_SIDE = 6.0
MIN_FIGURE_AREA = 100.0
# Objects closer than this (points) belong to the same figure.
CLUSTER_GAP = 4.0
# A text line inside a figure longer than this is real text in a box, not a figure label.
MAX_LABEL_CHARS = 40
# Pages with more graphic objects than this are not analysed (too slow, rarely a paper).
MAX_GRAPHICS_PER_PAGE = 4000
CROP_PADDING = 2.0


class FigureKind:
    STEM = "stem"  # a figure in the question itself
    OPTION = "option"  # the figure that is an option
    ORIGINAL = "original"  # the whole question as printed (text could not be read in full)


@dataclass(frozen=True, slots=True)
class Box:
    left: float
    bottom: float
    right: float
    top: float

    @property
    def width(self) -> float:
        return self.right - self.left

    @property
    def height(self) -> float:
        return self.top - self.bottom

    @property
    def center_x(self) -> float:
        return (self.left + self.right) / 2

    @property
    def center_y(self) -> float:
        return (self.bottom + self.top) / 2

    def union(self, other: "Box") -> "Box":
        return Box(
            min(self.left, other.left),
            min(self.bottom, other.bottom),
            max(self.right, other.right),
            max(self.top, other.top),
        )

    def near(self, other: "Box", gap: float) -> bool:
        return (
            self.left - gap <= other.right
            and other.left - gap <= self.right
            and self.bottom - gap <= other.top
            and other.bottom - gap <= self.top
        )

    def contains(self, other: "Box", tolerance: float = 2.0) -> bool:
        return (
            self.left - tolerance <= other.left
            and other.right <= self.right + tolerance
            and self.bottom - tolerance <= other.bottom
            and other.top <= self.top + tolerance
        )

    def padded(self, padding: float, *, width: float, height: float) -> "Box":
        return Box(
            max(0.0, self.left - padding),
            max(0.0, self.bottom - padding),
            min(width, self.right + padding),
            min(height, self.top + padding),
        )

    def as_list(self) -> list[float]:
        return [round(v, 2) for v in (self.left, self.bottom, self.right, self.top)]


@dataclass(frozen=True, slots=True)
class LayoutLine:
    text: str  # as extracted (not normalised)
    box: Box


@dataclass(frozen=True, slots=True)
class Graphic:
    kind: str  # "image" | "path" | "shading" | "form"
    box: Box


@dataclass(frozen=True, slots=True)
class PageLayout:
    number: int
    width: float
    height: float
    lines: Sequence[LayoutLine]
    graphics: Sequence[Graphic]
    rotated: bool = False


@dataclass(slots=True)
class PageAnalysis:
    """A page after decoration removal and clustering."""

    layout: PageLayout
    figures: list[Box]  # clusters that are figures
    figure_lines: set[int]  # indexes of lines that are labels inside a figure
    supported: bool = True
    reason: str | None = None

    def text(self) -> str:
        """Page text without the labels inside figures, in the PDF's own text order."""
        return "\n".join(
            line.text for i, line in enumerate(self.layout.lines) if i not in self.figure_lines
        )


@dataclass(frozen=True, slots=True)
class FigureCrop:
    kind: str
    page: int
    box: Box
    option_index: int | None = None  # 0-based index into ParsedQuestion.options


@dataclass(slots=True)
class QuestionFigures:
    crops: list[FigureCrop] = field(default_factory=list)
    # True when figures were found but could not be tied to individual options.
    ambiguous_options: bool = False
    # True when a figure sits on a text line (a formula or symbol drawn as graphics): the
    # extracted text of that line is incomplete.
    text_incomplete: bool = False

    @property
    def has_figure(self) -> bool:
        return any(c.kind in (FigureKind.STEM, FigureKind.OPTION) for c in self.crops) or (
            self.ambiguous_options
        )


# --- page analysis ---------------------------------------------------------------------


def _key(graphic: Graphic) -> tuple[str, int, int, int, int]:
    b = graphic.box
    return (graphic.kind, round(b.left), round(b.bottom), round(b.right), round(b.top))


def decorations(layouts: Sequence[PageLayout]) -> set[tuple[str, int, int, int, int]]:
    """Graphics drawn at the same place on most pages (logos, header and footer rules)."""
    if len(layouts) < 2:
        return set()
    counts: Counter[tuple[str, int, int, int, int]] = Counter()
    for layout in layouts:
        counts.update({_key(g) for g in layout.graphics})
    threshold = max(2, math.ceil(len(layouts) / 2))
    return {key for key, count in counts.items() if count >= threshold}


def _clusters(boxes: list[Box]) -> list[tuple[Box, int]]:
    """Merge boxes that touch (within CLUSTER_GAP); returns (bounds, object count)."""
    parent = list(range(len(boxes)))

    def find(i: int) -> int:
        while parent[i] != i:
            parent[i] = parent[parent[i]]
            i = parent[i]
        return i

    order = sorted(range(len(boxes)), key=lambda i: boxes[i].left)
    for position, i in enumerate(order):
        for j in order[position + 1 :]:
            if boxes[j].left - CLUSTER_GAP > boxes[i].right:
                break
            if boxes[i].near(boxes[j], CLUSTER_GAP):
                parent[find(i)] = find(j)
    groups: dict[int, tuple[Box, int]] = {}
    for i, box in enumerate(boxes):
        root = find(i)
        bounds, count = groups.get(root, (box, 0))
        groups[root] = (bounds.union(box), count + 1)
    # Merging can make two clusters touch; repeat until stable.
    merged = list(groups.values())
    changed = True
    while changed:
        changed = False
        result: list[tuple[Box, int]] = []
        for box, count in merged:
            for k, (other, other_count) in enumerate(result):
                if box.near(other, CLUSTER_GAP):
                    result[k] = (other.union(box), other_count + count)
                    changed = True
                    break
            else:
                result.append((box, count))
        merged = result
    return merged


def _is_anchor(text: str) -> bool:
    stripped = text.strip()
    return bool(
        strong_start(stripped)
        or WEAK_QUESTION.match(stripped)
        or OPTION_LINE_START.match(stripped)
        or OPTION_INLINE.match(stripped)
    )


def analyse_page(
    layout: PageLayout, decoration_keys: set[tuple[str, int, int, int, int]]
) -> PageAnalysis:
    if layout.rotated:
        return PageAnalysis(layout, [], set(), supported=False, reason="rotated_page")
    graphics = [g for g in layout.graphics if _key(g) not in decoration_keys]
    if len(graphics) > MAX_GRAPHICS_PER_PAGE:
        return PageAnalysis(layout, [], set(), supported=False, reason="too_many_objects")
    boxes = [g.box for g in graphics if g.box.width > 0.2 or g.box.height > 0.2]

    figures: list[Box] = []
    figure_lines: set[int] = set()
    for box, _count in _clusters(boxes):
        if (
            box.width < MIN_FIGURE_SIDE
            or box.height < MIN_FIGURE_SIDE
            or box.width * box.height < MIN_FIGURE_AREA
        ):
            continue
        inside = [
            i
            for i, line in enumerate(layout.lines)
            if line.box.width > 0 and box.contains(line.box)
        ]
        # A box around questions or real sentences is page layout (a bordered question or a
        # passage in a frame), not a figure: keep its text and ignore the box.
        if any(
            _is_anchor(layout.lines[i].text) or len(layout.lines[i].text.strip()) > MAX_LABEL_CHARS
            for i in inside
        ):
            continue
        figures.append(box)
        figure_lines.update(inside)
    return PageAnalysis(layout, figures, figure_lines)


# --- assigning figures to questions ----------------------------------------------------


@dataclass(frozen=True, slots=True)
class _Anchor:
    page: int
    top: float
    number: int | None  # question number; None for other boundaries (headings, key)
    left: float


def _anchors(analysis: PageAnalysis, strong_numbering: bool) -> list[_Anchor]:
    anchors: list[_Anchor] = []
    for i, line in enumerate(analysis.layout.lines):
        if i in analysis.figure_lines:
            continue
        text = line.text.strip()
        match = strong_start(text) if strong_numbering else WEAK_QUESTION.match(text)
        if match:
            anchors.append(
                _Anchor(analysis.layout.number, line.box.top, int(match.group(1)), line.box.left)
            )
        elif (
            ANSWER_KEY_HEADING.match(text)
            or EXPLANATION_HEADING.match(text)
            or PASSAGE_START.match(text)
            or section_heading(text)
        ):
            anchors.append(_Anchor(analysis.layout.number, line.box.top, None, line.box.left))
    return anchors


def _multi_column(anchors: list[_Anchor], width: float) -> bool:
    numbered = [a for a in anchors if a.number is not None]
    return any(a.left > width / 2 for a in numbered) and any(a.left < width / 2 for a in numbered)


_OPTION_LABEL = re.compile(r"\(\s*([1-9]|[a-eA-E])\s*\)")


def _option_labels(text: str) -> list[str]:
    stripped = text.strip()
    start = OPTION_LINE_START.match(stripped)
    if start:
        return [start.group(1)]
    if not OPTION_INLINE.match(stripped):
        return []
    return [m.group(1) for m in _OPTION_LABEL.finditer(stripped)]


def locate_figures(
    questions: Sequence[ParsedQuestion],
    analyses: Sequence[PageAnalysis],
    *,
    strong_numbering: bool,
    unreadable: Sequence[bool],
) -> list[QuestionFigures]:
    """One ``QuestionFigures`` per question (same order). ``unreadable[i]`` asks for an
    ``original`` crop of question i (its text lost characters)."""
    by_page = {a.layout.number: a for a in analyses}
    anchors_by_page = {
        number: _anchors(analysis, strong_numbering) for number, analysis in by_page.items()
    }
    usable = {
        number
        for number, analysis in by_page.items()
        if analysis.supported and not _multi_column(anchors_by_page[number], analysis.layout.width)
    }

    results: list[QuestionFigures] = []
    used: set[tuple[int, float]] = set()
    for index, question in enumerate(questions):
        result = QuestionFigures()
        results.append(result)
        if not question.pages or any(p not in usable for p in question.pages):
            continue
        first_page = question.pages[0]
        anchor = next(
            (
                a
                for a in anchors_by_page[first_page]
                if a.number == question.number and (a.page, a.top) not in used
            ),
            None,
        )
        if anchor is None:
            continue
        used.add((anchor.page, anchor.top))
        _collect(question, anchor, by_page, anchors_by_page, result, unreadable[index])
    return results


def _collect(
    question: ParsedQuestion,
    anchor: _Anchor,
    by_page: dict[int, PageAnalysis],
    anchors_by_page: dict[int, list[_Anchor]],
    result: QuestionFigures,
    unreadable: bool,
) -> None:
    labels = [o.label.casefold() for o in question.options]
    unknown = -1  # after a line with several options (or an unknown label): owner unclear
    owner: int | None = None  # option index; None = the stem
    owned: dict[int | None, list[tuple[int, Box]]] = {}
    region_boxes: dict[int, Box] = {}
    text_lines: list[tuple[int, Box]] = []

    for page in question.pages:
        analysis = by_page[page]
        anchors = anchors_by_page[page]
        if page == anchor.page:
            top = anchor.top + 2.0
            below = [a.top for a in anchors if a.top < anchor.top - 1.0]
        else:
            top = analysis.layout.height
            below = [a.top for a in anchors]
        bottom = max(below) + 0.5 if below else 0.0

        events: list[tuple[float, str, int]] = []  # (y, kind, index)
        for i, line in enumerate(analysis.layout.lines):
            if i in analysis.figure_lines or not bottom <= line.box.center_y <= top:
                continue
            region_boxes[page] = region_boxes.get(page, line.box).union(line.box)
            if line.text.strip():
                text_lines.append((page, line.box))
            found = _option_labels(line.text)
            if found:
                events.append((line.box.top, "option", i))
        for k, box in enumerate(analysis.figures):
            if bottom <= box.center_y <= top:
                region_boxes[page] = region_boxes.get(page, box).union(box)
                events.append((box.center_y, "figure", k))

        for _y, kind, i in sorted(events, key=lambda e: -e[0]):
            if kind == "option":
                found = [f.casefold() for f in _option_labels(analysis.layout.lines[i].text)]
                owner = (
                    labels.index(found[0]) if len(found) == 1 and found[0] in labels else unknown
                )
            else:
                owned.setdefault(owner, []).append((page, analysis.figures[i]))

    result.ambiguous_options = unknown in owned
    result.text_incomplete = any(
        _on_line(figure, line)
        for items in owned.values()
        for page, figure in items
        for line_page, line in text_lines
        if line_page == page
    )
    for owner_index, items in owned.items():
        if owner_index == unknown:
            continue
        for page in sorted({p for p, _ in items}):
            boxes = [b for p, b in items if p == page]
            bounds = boxes[0]
            for b in boxes[1:]:
                bounds = bounds.union(b)
            layout = by_page[page].layout
            result.crops.append(
                FigureCrop(
                    FigureKind.OPTION if owner_index is not None else FigureKind.STEM,
                    page,
                    bounds.padded(CROP_PADDING, width=layout.width, height=layout.height),
                    owner_index,
                )
            )

    if unreadable or result.ambiguous_options or result.text_incomplete:
        for page, bounds in sorted(region_boxes.items()):
            layout = by_page[page].layout
            result.crops.append(
                FigureCrop(
                    FigureKind.ORIGINAL,
                    page,
                    bounds.padded(CROP_PADDING, width=layout.width, height=layout.height),
                )
            )
    result.crops.sort(
        key=lambda c: (
            {FigureKind.STEM: 0, FigureKind.OPTION: 1, FigureKind.ORIGINAL: 2}[c.kind],
            c.option_index or 0,
            c.page,
        )
    )


def _on_line(figure: Box, line: Box) -> bool:
    """The figure shares at least half of the line's height (it is part of that line)."""
    overlap = min(figure.top, line.top) - max(figure.bottom, line.bottom)
    return line.height > 0 and overlap >= line.height / 2
