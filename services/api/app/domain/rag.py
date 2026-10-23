"""Answers from the learner's own material: retrieval-augmented generation (RAG), pure parts.

RAG in four steps:
  1. RETRIEVE  find the passages of the learner's material that best match the query
               (keyword full-text search in PostgreSQL; see app/services/rag_service.py).
  2. AUGMENT   put those passages, numbered S1..Sn, into the prompt.
  3. GENERATE  the model answers ONLY from them and marks every statement with [S#].
  4. CHECK     our code verifies each marker is a source we sent; anything else is rejected.

This module holds the parts that need no database or network: query words, the tsquery
text, snippets, the prompt and the citation check. They are unit-tested in tests/test_rag.py.
"""

import re
import unicodedata
from collections.abc import Sequence
from dataclasses import dataclass
from typing import Any, Literal

from app.domain.ai_content import LANGUAGE_NAMES, query_language

SourceKind = Literal["page", "question", "concept"]

MAX_TERMS = 10  # more words add noise, not precision
SOURCES_PER_ANSWER = 6  # enough context to combine sources, small enough to stay cheap
SNIPPET_CHARS = 1200  # per source; a whole PDF page would bury the relevant lines
MAX_RAG_ANSWER = 2500

# Words that appear in almost every query and so say nothing about what is wanted.
STOP_WORDS = frozenset(
    {
        "a", "an", "and", "the", "in", "of", "on", "to", "for", "with", "is", "or", "what",
        "which", "who", "how", "why", "when", "are", "was", "were", "be", "do", "does", "it",
        "this", "that", "by", "as", "at", "from", "explain", "define", "meaning", "between",
    }
)  # fmt: skip

# Word characters in any script, plus the Devanagari block: Hindi vowel signs (matras) are
# "marks", not \w, and would otherwise split a Hindi word in pieces.
_WORD = re.compile(r"[\wऀ-ॿ]+")


# --- 1. RETRIEVE: from a query to search words ---------------------------------------------


def query_terms(text: str) -> list[str]:
    """The search words of a query: NFC, lower-case, no stop words, no duplicates, at most
    MAX_TERMS. When only stop words were typed they are kept (better than searching nothing).

    Only word characters survive, so a term can never inject tsquery syntax (& | ! ' :)."""
    words = [w.casefold() for w in _WORD.findall(unicodedata.normalize("NFC", text))]
    words = [w.strip("_") for w in words if len(w.strip("_")) > 1 or w.isdigit()]
    kept = [w for w in words if w not in STOP_WORDS] or words
    return list(dict.fromkeys(kept))[:MAX_TERMS]


def ts_query(terms: Sequence[str]) -> str:
    """Text for ``to_tsquery('simple', ...)``: any term (OR, ``|``) as a word prefix (``:*``).

    OR gives recall (a page needs only some of the words); the ranking (ts_rank_cd) then puts
    pages with more and closer matches first. The prefix lets "optional" match "optionals"."""
    return " | ".join(f"{t}:*" for t in terms)


def best_window(text: str, terms: Sequence[str], size: int = SNIPPET_CHARS) -> str:
    """The part of [text] (at most [size] characters) with the most query-word hits.

    Sending whole pages wastes tokens and makes the model hunt for the answer; a window around
    the densest hits keeps the evidence and drops the rest."""
    text = text.strip()
    if len(text) <= size:
        return text
    lowered = text.casefold()
    hits = sorted(m.start() for t in terms for m in re.finditer(re.escape(t), lowered))
    if not hits:
        return text[:size].strip()
    best_begin, best_count = 0, -1
    for hit in hits:
        begin = max(0, min(hit - size // 4, len(text) - size))  # a little context before
        count = sum(1 for h in hits if begin <= h < begin + size)
        if count > best_count:
            best_begin, best_count = begin, count
    return text[best_begin : best_begin + size].strip()


# --- 2. AUGMENT: numbered sources in the prompt --------------------------------------------


@dataclass(frozen=True, slots=True)
class RagSource:
    key: str  # "S1", "S2", ... the name the model cites
    kind: SourceKind
    label: str  # shown to the learner: "chsl-2024.pdf, page 7"
    text: str  # the snippet sent to the model
    verified: bool  # a reviewer checked it (questions); raw page text is not checked
    rank: float  # retrieval score, higher = better match
    document_id: str | None = None
    page_number: int | None = None
    question_id: str | None = None
    concept_id: str | None = None


RAG_SYSTEM = (
    "You answer a learner's search using ONLY the numbered sources from their own study "
    "material. Every statement must end with the marker of the source it comes from, like "
    "[S2]. If the sources do not answer the search, set found to false and leave the answer "
    "empty: do not use outside knowledge. Sources may contain OCR mistakes; if a source looks "
    "garbled or sources disagree, say so. Never invent exam patterns, cut-offs, marks or "
    "statistics, and never call something official unless a source says so."
)

# Structured output: the API guarantees JSON of this shape, so we never parse free text.
RAG_SCHEMA: dict[str, Any] = {
    "type": "object",
    "properties": {
        "found": {"type": "boolean"},
        "answer": {"type": "string"},
        "cited": {"type": "array", "items": {"type": "string"}},
        "confident": {"type": "boolean"},
    },
    "required": ["found", "answer", "cited", "confident"],
    "additionalProperties": False,
}


def rag_prompt(*, query: str, exam_name: str | None, sources: Sequence[RagSource]) -> str:
    """Sources first, the question last: models attend best to instructions near the end."""
    blocks = "\n\n".join(
        f"[{s.key}] {s.label}{'' if s.verified else ' (not checked by a reviewer)'}\n{s.text}"
        for s in sources
    )
    material = f" for {exam_name}" if exam_name else ""
    return (
        f"Sources from the learner's material{material}:\n\n{blocks}\n\n"
        f"Search: {query}\n\n"
        f"Answer in at most 150 words, in {LANGUAGE_NAMES[query_language(query)]}, using only "
        "the sources above, with a [S#] marker after each statement. List the markers you "
        "used in cited. Set confident to false if the sources are unclear or disagree."
    )


# --- 4. CHECK: the model's citations ---------------------------------------------------------

_MARKER = re.compile(r"\[(S\d+)\]")


@dataclass(frozen=True, slots=True)
class RagAnswer:
    found: bool
    answer: str | None
    cited: tuple[str, ...]  # source keys in order of first use
    confident: bool


def validate_rag(data: dict[str, Any], source_keys: Sequence[str]) -> RagAnswer | None:
    """The model's answer, or None when it can't be trusted.

    A found answer must have text with at least one [S#] marker, and every marker (in the text
    and in ``cited``) must be a source we sent. An unknown marker means the model referred to
    something that isn't there, so the whole answer is rejected rather than "cleaned up"."""
    confident = data.get("confident") is True
    if data.get("found") is not True:
        return RagAnswer(found=False, answer=None, cited=(), confident=confident)
    text, listed = data.get("answer"), data.get("cited")
    if not isinstance(text, str) or not isinstance(listed, list):
        return None
    text = unicodedata.normalize("NFC", text.strip())
    if not 0 < len(text) <= MAX_RAG_ANSWER:
        return None
    in_text = _MARKER.findall(text)
    in_list = [c for c in listed if isinstance(c, str)]
    allowed = set(source_keys)
    if not in_text or any(key not in allowed for key in [*in_text, *in_list]):
        return None
    return RagAnswer(
        found=True,
        answer=text,
        cited=tuple(dict.fromkeys([*in_text, *in_list])),
        confident=confident,
    )
