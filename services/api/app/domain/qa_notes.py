"""Reading Q&A notes: questions with a written answer instead of options (interview questions,
revision notes, solved descriptive questions).

Two layouts are recognised:
  A. A question line (or a few lines ending in "?"), then an "Answer:" / "Ans:" line and the
     answer paragraphs. Questions may be unnumbered; they are then numbered in order.
  B. Numbered questions ("Q.3 What is ...?" / "3. Why ...?") followed directly by the answer.
     A numbered line only starts a question when it has a "?" (or a "Q" prefix), so numbered
     lists inside answers ("1. Use weak references.") stay part of the answer.

Text is kept as found (whitespace and NFC only). Where the split between question and answer
is a guess (no "?"), the question gets an ``ambiguous_boundary`` issue for the reviewer.
"""

import re
import unicodedata
from collections.abc import Sequence
from dataclasses import dataclass, field

from app.domain.segmentation import Issue, IssueCode, PageText

MIN_QUESTIONS = 2  # fewer than this is not a Q&A paper
MAX_QUESTION_LINES = 5

_ANSWER_LABEL = re.compile(r"^\s*(?:answer|ans)\s*[:.\-\u2013]\s*(.*)$", re.IGNORECASE)
_NUMBERED = re.compile(r"^\s*(q(?:uestion)?\s*[.\-:]?\s*)?(\d{1,3})\s*[.):\-]?\s+(\S.*)$", re.I)
_TERMINAL = (".", "!", ":", ";", ")")


@dataclass(frozen=True, slots=True)
class _Line:
    page: int
    text: str


@dataclass(slots=True)
class WrittenQuestion:
    number: int
    numbered: bool  # the number was printed (False: numbered in order by PrepLoop)
    stem: str
    answer: str
    pages: list[int]
    issues: list[Issue] = field(default_factory=list)


def _lines(pages: Sequence[PageText]) -> list[_Line]:
    out: list[_Line] = []
    for page in pages:
        for raw in unicodedata.normalize("NFC", page.text).splitlines():
            text = " ".join(raw.split())
            if text:
                out.append(_Line(page.number, text))
    # Page furniture: a short line (author, title, page header) printed on many pages.
    pages_with: dict[str, set[int]] = {}
    for line in out:
        if len(line.text) <= 60:
            pages_with.setdefault(line.text, set()).add(line.page)
    furniture = {
        text
        for text, on in pages_with.items()
        if len(on) >= 3
        and len(on) >= 0.3 * len(pages)
        and "?" not in text
        and not _ANSWER_LABEL.match(text)  # "Answer:" repeats on every page by design
    }
    return [line for line in out if line.text not in furniture]


def _join(lines: Sequence[_Line]) -> str:
    return "\n".join(line.text for line in lines).strip()


def _heading_like(text: str) -> bool:
    """A title such as "Essential Topics You Can't Miss": mostly capitalised words, no "?"."""
    words: list[str] = re.findall(r"[A-Za-z][\w'\u2019]*", text)
    if len(words) < 2 or "?" in text:
        return False
    return sum(w[0].isupper() for w in words) / len(words) >= 0.7


def _question_end(text: str, limit: int = 600) -> int:
    """Index just after the question in [text]: its first "?", extended over directly
    following short sentences that are questions too. -1 when there is no "?" early on."""
    mark = text.find("?")
    if not 0 <= mark <= limit:
        return -1
    end = mark + 1
    while True:
        following = text.find("?", end)
        stop = min((i for i in (text.find(".", end), text.find("\n\n", end)) if i >= 0),
                   default=-1)  # fmt: skip
        if following < 0 or following - end > 160 or 0 <= stop < following:
            return end
        end = following + 1


def _number_of(text: str) -> tuple[int | None, str]:
    match = _NUMBERED.match(text)
    if match is None:
        return None, text
    return int(match.group(2)), match.group(3)


def _labelled(lines: list[_Line]) -> list[WrittenQuestion]:
    """Layout A: each "Answer:" line closes the question written just above it."""
    labels = [i for i, line in enumerate(lines) if _ANSWER_LABEL.match(line.text)]
    if len(labels) < MIN_QUESTIONS:
        return []
    starts: list[int] = []
    previous = -1
    for label in labels:
        start = label - 1
        # Walk up while the line above continues the question (no full stop ends it).
        while (
            start - 1 > previous
            and label - (start - 1) <= MAX_QUESTION_LINES
            and not lines[start - 1].text.endswith(_TERMINAL)
        ):
            start -= 1
        while start < label - 1 and _heading_like(lines[start].text):
            start += 1  # a page or section title above the first question
        starts.append(max(start, previous + 1))
        previous = label
    questions: list[WrittenQuestion] = []
    for n, (start, label) in enumerate(zip(starts, labels, strict=True)):
        end = starts[n + 1] if n + 1 < len(starts) else len(lines)
        question_lines = lines[start:label]
        if not question_lines:
            continue
        first = _ANSWER_LABEL.match(lines[label].text)
        rest = first.group(1).strip() if first else ""
        answer_lines = ([_Line(lines[label].page, rest)] if rest else []) + lines[label + 1 : end]
        number, first_text = _number_of(question_lines[0].text)
        stem = " ".join(
            _join([_Line(question_lines[0].page, first_text), *question_lines[1:]]).split()
        )
        issues = (
            [Issue(IssueCode.AMBIGUOUS_BOUNDARY, "Check where the question starts.")]
            if len(question_lines) >= MAX_QUESTION_LINES
            else []
        )
        questions.append(
            WrittenQuestion(
                number=number if number is not None else len(questions) + 1,
                numbered=number is not None,
                stem=stem,
                answer=_join(answer_lines),
                pages=sorted({line.page for line in lines[start:end]}),
                issues=issues,
            )
        )
    if any(not q.numbered for q in questions):  # mixed: number everything in order
        for i, q in enumerate(questions, start=1):
            q.number, q.numbered = i, False
    return questions


def _numbered(lines: list[_Line]) -> list[WrittenQuestion]:
    """Layout B: a numbered question line starts each block; the answer follows it."""
    starts: list[int] = []
    for i, line in enumerate(lines):
        match = _NUMBERED.match(line.text)
        if match is None:
            continue
        nearby = " ".join(x.text for x in lines[i : i + 2])
        if match.group(1) or "?" in nearby:
            starts.append(i)
    if len(starts) < MIN_QUESTIONS:
        return []
    questions: list[WrittenQuestion] = []
    seen: set[int] = set()
    for n, start in enumerate(starts):
        end = starts[n + 1] if n + 1 < len(starts) else len(lines)
        block = lines[start:end]
        number, first_text = _number_of(block[0].text)
        if number is None or number in seen:
            continue
        seen.add(number)
        text = _join([_Line(block[0].page, first_text), *block[1:]])
        end = _question_end(text)
        issues: list[Issue] = []
        if end > 0:
            stem, answer = text[:end], text[end:]
        else:
            stem, _, answer = text.partition("\n")
            issues.append(
                Issue(IssueCode.AMBIGUOUS_BOUNDARY, "No question mark: check where it ends.")
            )
        questions.append(
            WrittenQuestion(
                number=number,
                numbered=True,
                stem=" ".join(stem.split()),
                answer=answer.strip(),
                pages=sorted({line.page for line in block}),
                issues=issues,
            )
        )
    return questions


def read_qa_notes(pages: Sequence[PageText]) -> list[WrittenQuestion]:
    """The Q&A pairs of a paper, or [] when it doesn't look like Q&A notes."""
    lines = _lines(pages)
    found = _labelled(lines)
    if len(found) < MIN_QUESTIONS:
        found = _numbered(lines)
    return found if len(found) >= MIN_QUESTIONS else []
