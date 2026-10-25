"""RAG retrieval: the learner's material that best matches a query, as numbered sources.

Three kinds of material are searched with PostgreSQL full-text search and merged by score:
  - PDF pages of the learner's own documents (``document_pages.text``; extracted, unchecked);
  - source questions they may see: their own plus shared-bank ones (``visible_question``),
    never AI-generated or rejected ones, so AI never cites AI;
  - their concepts (synced from the device into ``sync_items``).
All three are filtered to one exam and one account before ranking.

Full-text basics used here:
  to_tsvector('simple', text)    the words of a text ('simple' = no stemming, works for Hindi)
  to_tsquery('simple', 'a:* | b:*')  any of the words, as prefixes
  vector @@ query                does the text match?
  ts_rank_cd(vector, query)      how well: more query words, closer together = higher
Ranks of different kinds are comparable enough for a top-N merge; a later improvement is a
re-ranker (see docs/rag-guide.md, step 10).
"""

import uuid
from collections.abc import Sequence
from dataclasses import replace
from typing import Any

from sqlalchemy import func, select
from sqlalchemy.orm import Session, selectinload

from app.domain.rag import SOURCES_PER_ANSWER, RagSource, best_window, ts_query
from app.models.document import Document, DocumentPage
from app.models.question import Question, QuestionOption, QuestionOrigin, VerificationStatus
from app.models.sync import SyncItem
from app.services.shared_bank import visible_question

CANDIDATES_PER_KIND = SOURCES_PER_ANSWER  # fetch this many of each kind, then merge
TS_CONFIG = "simple"


def _match(text: Any, terms: Sequence[str]) -> tuple[Any, Any]:
    """(text matches the query, its score) as SQL expressions."""
    vector = func.to_tsvector(TS_CONFIG, text)
    query = func.to_tsquery(TS_CONFIG, ts_query(terms))  # sent as a bound parameter
    return vector.op("@@")(query), func.ts_rank_cd(vector, query)


class RagRetriever:
    def __init__(self, session: Session, owner_id: uuid.UUID) -> None:
        self._session = session
        self._owner_id = owner_id

    def retrieve(
        self, terms: Sequence[str], exam_code: str, limit: int = SOURCES_PER_ANSWER
    ) -> list[RagSource]:
        """The best [limit] sources for [terms], best first, keyed S1..Sn."""
        if not terms:
            return []
        found = [
            *self._pages(terms, exam_code),
            *self._questions(terms, exam_code),
            *self._concepts(terms, exam_code),
        ]
        found.sort(key=lambda s: s.rank, reverse=True)
        return [replace(s, key=f"S{i}") for i, s in enumerate(found[:limit], start=1)]

    # --- PDF pages ---------------------------------------------------------------------------

    def _pages(self, terms: Sequence[str], exam_code: str) -> list[RagSource]:
        matches, rank = _match(DocumentPage.text, terms)
        rows = self._session.execute(
            select(DocumentPage, Document.original_filename, rank.label("rank"))
            .join(Document, Document.id == DocumentPage.document_id)
            .where(
                Document.owner_id == self._owner_id,
                Document.exam_code == exam_code,
                matches,
            )
            .order_by(rank.desc())
            .limit(CANDIDATES_PER_KIND)
        ).all()
        return [
            RagSource(
                key="",
                kind="page",
                label=f"{filename}, page {page.page_number}",
                text=best_window(page.text, terms),
                verified=False,  # extracted text (maybe OCR); nobody reviewed it
                rank=float(score),
                document_id=str(page.document_id),
                page_number=page.page_number,
            )
            for page, filename, score in rows
        ]

    # --- questions ---------------------------------------------------------------------------

    def _questions(self, terms: Sequence[str], exam_code: str) -> list[RagSource]:
        # Search the stem together with its options and explanation (one text per question).
        options = (
            select(func.string_agg(QuestionOption.text, " "))
            .where(QuestionOption.question_id == Question.id)
            .scalar_subquery()
        )
        searchable = func.concat_ws(
            " ", Question.stem, options, Question.model_answer, Question.explanation
        )
        matches, rank = _match(searchable, terms)
        rows = self._session.execute(
            select(Question, Document.original_filename, rank.label("rank"))
            .outerjoin(Document, Document.id == Question.document_id)
            .options(selectinload(Question.options), selectinload(Question.passage))
            .where(
                visible_question(self._owner_id),
                Question.exam_code == exam_code,
                Question.origin == QuestionOrigin.SOURCE,
                Question.verification_status != VerificationStatus.REJECTED,
                matches,
            )
            .order_by(rank.desc())
            .limit(CANDIDATES_PER_KIND)
        ).all()
        sources = []
        for question, filename, score in rows:
            shared = question.owner_id != self._owner_id
            number = f"Q.{question.source_question_number}"
            where = "shared bank" if shared else (filename or "")
            sources.append(
                RagSource(
                    key="",
                    kind="question",
                    label=f"{number} · {where}".strip(" ·"),
                    text=best_window(_question_text(question), terms),
                    verified=question.verification_status == VerificationStatus.VERIFIED,
                    rank=float(score),
                    question_id=str(question.id),
                )
            )
        return sources

    # --- concepts ----------------------------------------------------------------------------

    def _concepts(self, terms: Sequence[str], exam_code: str) -> list[RagSource]:
        data = SyncItem.data
        searchable = func.concat_ws(
            " ",
            data["title"].astext,
            data["subject"].astext,
            data["topic"].astext,
            data["notes"].astext,
        )
        matches, rank = _match(searchable, terms)
        rows = self._session.execute(
            select(SyncItem, rank.label("rank"))
            .where(
                SyncItem.owner_id == self._owner_id,
                SyncItem.entity == "concept",
                SyncItem.deleted.is_(False),
                data["exam_code"].astext == exam_code,
                data["archived_at"].astext.is_(None),  # archived concepts are put away
                matches,
            )
            .order_by(rank.desc())
            .limit(CANDIDATES_PER_KIND)
        ).all()
        sources = []
        for item, score in rows:
            concept = item.data or {}
            text = f"{concept.get('title', '')}\n{concept.get('notes', '')}"
            sources.append(
                RagSource(
                    key="",
                    kind="concept",
                    label=f"Concept: {concept.get('title', '')}",
                    text=best_window(text, terms),
                    verified=True,  # the learner's own notes
                    rank=float(score),
                    concept_id=item.item_id,
                )
            )
        return sources


def _question_text(question: Question) -> str:
    """One question as plain text: passage, stem, options, answer and explanation."""
    lines = []
    if question.passage is not None:
        lines.append(f"Passage: {question.passage.text}")
    lines.append(question.stem)
    lines += [f"({o.label}) {o.text}" for o in question.options]
    if question.answer_type == "written" and question.model_answer:
        lines.append(f"Answer: {question.model_answer}")
    elif question.answer_type == "typed" and question.typed_answer:
        lines.append(f"Answer: {question.typed_answer}")
    else:
        correct = next(
            (o for o in question.options if o.position == question.correct_option_position), None
        )
        if correct is not None:
            lines.append(f"Answer: ({correct.label}) {correct.text}")
    if question.explanation:
        lines.append(f"Explanation: {question.explanation}")
    return "\n".join(lines)
