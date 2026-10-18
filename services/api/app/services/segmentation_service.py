"""Turns a processed document's pages into question-bank rows.

Re-running is safe: questions a reviewer has verified or rejected are kept untouched, and
freshly parsed questions with the same (section, number) are skipped so human decisions are
never overwritten. Everything else from a previous run is replaced.

When the original PDF is available, pages with a text layer are also read for their layout:
figures (diagrams, charts, formulas drawn as graphics) are cropped from the page and stored
with their question, and labels inside a figure (chart values) are kept out of the question
text. Pages read by OCR have no layout and only get the text-based checks.
"""

import logging
import uuid
from collections.abc import Sequence
from datetime import UTC, datetime
from pathlib import Path

from sqlalchemy import delete, select
from sqlalchemy.orm import Session

from app.domain.figures import (
    PageAnalysis,
    QuestionFigures,
    analyse_page,
    decorations,
    locate_figures,
)
from app.domain.paper_date import suggest_paper_date
from app.domain.segmentation import (
    EXPECTED_OPTIONS,
    Issue,
    IssueCode,
    PageText,
    ParsedQuestion,
    check_against_format,
    content_issues,
    segment,
)
from app.domain.text_quality import normalize_text, unreadable_char_count
from app.domain.topics import TopicCandidate, subject_for_section, suggest_topic
from app.integrations.storage import DocumentStorage
from app.models.document import Document, DocumentPage, ExtractionMethod
from app.models.question import (
    ExamFormat,
    Passage,
    Question,
    QuestionFigure,
    QuestionIssue,
    QuestionOption,
    QuestionOrigin,
    TopicStatus,
    VerificationStatus,
)
from app.services.page_layout import PdfRenderer, read_layouts
from app.services.patterns import pattern_candidates, refresh_pattern
from app.services.topic_service import visible_topics

logger = logging.getLogger("app.segmentation")


class SegmentationService:
    def __init__(self, session: Session, storage: DocumentStorage | None = None) -> None:
        self._session = session
        self._storage = storage

    def segment_document(self, document_id: uuid.UUID) -> None:
        """Segment and persist. On unexpected errors the document's segmentation_status is
        set to ``failed`` (the extraction result itself is unaffected)."""
        document = self._session.get(Document, document_id)
        if document is None:
            return
        try:
            self._run(document)
        except Exception:
            self._session.rollback()
            logger.exception(
                "segmentation failed", extra={"fields": {"document_id": str(document_id)}}
            )
            document = self._session.get(Document, document_id)
            if document is not None:
                document.segmentation_status = "failed"
                self._session.commit()

    def _pdf_path(self, document: Document) -> Path | None:
        if self._storage is None:
            return None
        try:
            path = self._storage.path_for(document.storage_key)
        except ValueError:
            return None
        return path if path.is_file() else None

    def _run(self, document: Document) -> None:
        pages = self._session.scalars(
            select(DocumentPage)
            .where(DocumentPage.document_id == document.id)
            .order_by(DocumentPage.page_number)
        ).all()
        pdf_path = self._pdf_path(document)
        analyses, layout_issue = _analyse(pdf_path, pages)
        figure_text = {
            a.layout.number: normalize_text(a.text()) for a in analyses if a.figure_lines
        }
        exam_topics = visible_topics(self._session, document.owner_id, document.exam_code)
        result = segment(
            [
                PageText(p.page_number, figure_text.get(p.page_number, p.text), p.needs_review)
                for p in pages
            ],
            expected_options=EXPECTED_OPTIONS,
            # The exam's own subjects are recognised as section headings too.
            extra_headings=sorted({t.subject for t in exam_topics}),
        )
        if layout_issue is not None:
            result.document_issues.append(layout_issue)
        unreadable = [_unreadable_count(q) for q in result.questions]
        located = (
            locate_figures(
                result.questions,
                analyses,
                strong_numbering=result.strong_numbering,
                unreadable=[n > 0 for n in unreadable],
            )
            if analyses
            else [QuestionFigures() for _ in result.questions]
        )
        exam_format = (
            self._session.get(ExamFormat, document.exam_format_id)
            if document.exam_format_id
            else None
        )
        if exam_format is not None:
            result.document_issues.extend(
                check_against_format(
                    result,
                    total_questions=exam_format.total_questions,
                    sections=[(s["subject"], int(s["questions"])) for s in exam_format.sections],
                )
            )

        kept = self._session.scalars(
            select(Question).where(
                Question.document_id == document.id,
                Question.verification_status != VerificationStatus.UNVERIFIED,
            )
        ).all()
        kept_keys = {(q.section, q.source_question_number) for q in kept}
        kept_passages = {q.passage_id for q in kept if q.passage_id}

        # Replace everything from the previous run except human-reviewed questions.
        self._session.execute(
            delete(Question).where(
                Question.document_id == document.id,
                Question.verification_status == VerificationStatus.UNVERIFIED,
            )
        )
        self._session.execute(
            delete(QuestionIssue).where(
                QuestionIssue.document_id == document.id, QuestionIssue.question_id.is_(None)
            )
        )
        self._session.execute(
            delete(Passage).where(
                Passage.document_id == document.id, Passage.id.not_in(kept_passages)
            )
            if kept_passages
            else delete(Passage).where(Passage.document_id == document.id)
        )

        passage_rows = [
            Passage(
                document_id=document.id,
                text=p.text,
                first_question=p.first_question,
                last_question=p.last_question,
                source_pages=p.pages,
            )
            for p in result.passages
        ]
        self._session.add_all(passage_rows)
        self._session.flush()

        topics = [TopicCandidate(t.id, t.subject, t.name, t.keywords) for t in exam_topics]
        subjects = sorted({t.subject for t in topics})
        patterns = pattern_candidates(self._session)
        for question in kept:  # reviewed questions only gain a pattern suggestion
            if question.pattern_status == TopicStatus.UNASSIGNED:
                refresh_pattern(question, patterns)
        _suggest_paper_date(document, pages)
        created = 0
        renderer = PdfRenderer(pdf_path) if pdf_path is not None and analyses else None
        try:
            for parsed, figures, unreadable_chars in zip(
                result.questions, located, unreadable, strict=True
            ):
                if (parsed.section, parsed.number) in kept_keys:
                    continue
                question = self._build_question(
                    document, exam_format, parsed, passage_rows, topics, subjects
                )
                _apply_figures(question, parsed, figures, unreadable_chars, renderer)
                refresh_pattern(question, patterns)
                self._session.add(question)
                created += 1
        finally:
            if renderer is not None:
                renderer.close()

        for issue in result.document_issues:
            self._session.add(
                QuestionIssue(document_id=document.id, code=issue.code, detail=issue.detail)
            )
        document.segmentation_status = "completed"
        document.questions_found = created + len(kept)
        document.segmented_at = datetime.now(UTC)
        self._session.commit()
        logger.info(
            "document segmented",
            extra={
                "fields": {
                    "document_id": str(document.id),
                    "questions": document.questions_found,
                    "kept_reviewed": len(kept),
                    "document_issues": len(result.document_issues),
                }
            },
        )

    @staticmethod
    def _build_question(
        document: Document,
        exam_format: ExamFormat | None,
        parsed: ParsedQuestion,
        passages: list[Passage],
        topics: list[TopicCandidate],
        subjects: list[str],
    ) -> Question:
        subject = subject_for_section(parsed.section, subjects)
        suggestion = suggest_topic(parsed.stem, subject=subject, topics=topics)
        question = Question(
            origin=QuestionOrigin.SOURCE,
            owner_id=document.owner_id,  # questions belong to the document's owner
            exam_code=document.exam_code,
            exam_format_id=exam_format.id if exam_format else None,
            section=parsed.section,
            # Without a section heading the subject follows the suggested topic (and is shown
            # as part of that suggestion until a reviewer accepts it).
            subject=subject or (suggestion.subject if suggestion else None),
            topic_id=suggestion.topic_id if suggestion else None,
            topic_status=TopicStatus.SUGGESTED if suggestion else TopicStatus.UNASSIGNED,
            topic_suggested_by="keywords" if suggestion else None,
            topic_suggestion_reason=suggestion.reason[:200] if suggestion else None,
            stem=parsed.stem,
            language=document.language,
            document_id=document.id,
            source_question_number=parsed.number,
            source_pages=parsed.pages,
            passage_id=passages[parsed.passage_index].id
            if parsed.passage_index is not None
            else None,
            correct_option_position=parsed.answer_position,
            answer_source=parsed.answer_source,
            explanation=parsed.explanation,
            image_dependent=parsed.image_dependent,
            verification_status=VerificationStatus.UNVERIFIED,
        )
        question.options = [
            QuestionOption(position=i + 1, label=o.label, text=o.text)
            for i, o in enumerate(parsed.options)
        ]
        question.issues = [
            QuestionIssue(document_id=document.id, code=i.code, detail=i.detail)
            for i in parsed.issues
        ]
        return question


def _unreadable_count(question: ParsedQuestion) -> int:
    return unreadable_char_count(
        "\n".join([question.stem, *(option.text for option in question.options)])
    )


def _analyse(
    pdf_path: Path | None, pages: Sequence[DocumentPage]
) -> tuple[list[PageAnalysis], Issue | None]:
    """Layout analysis of the pages that have a text layer. Never fails segmentation: on
    any error the paper is segmented from its stored text only, with a document issue."""
    text_pages = {p.page_number for p in pages if p.method == ExtractionMethod.TEXT}
    if pdf_path is None or not text_pages:
        return [], None
    try:
        layouts = list(read_layouts(pdf_path, text_pages))
        decoration_keys = decorations(layouts)
        analyses = [analyse_page(layout, decoration_keys) for layout in layouts]
    except Exception:
        logger.exception("page layout analysis failed")
        return [], Issue(IssueCode.FIGURES_NOT_EXTRACTED, "The page layout could not be read.")
    skipped = sorted(a.layout.number for a in analyses if not a.supported)
    issue = (
        Issue(
            IssueCode.FIGURES_NOT_EXTRACTED,
            "Pages not analysed for figures: " + ", ".join(str(p) for p in skipped),
        )
        if skipped
        else None
    )
    return analyses, issue


def _suggest_paper_date(document: Document, pages: Sequence[DocumentPage]) -> None:
    """Suggest when the paper was held, unless the reviewer has confirmed it already."""
    if document.paper_date_status == "confirmed":
        return
    first_page = pages[0].text if pages else ""
    suggestion = suggest_paper_date(document.original_filename, first_page)
    if suggestion.empty:
        document.exam_year = document.exam_date = document.exam_shift = None
        document.paper_date_status = "unknown"
        document.paper_date_reason = suggestion.reason or None
        return
    document.exam_year = suggestion.year
    document.exam_date = suggestion.date
    document.exam_shift = suggestion.shift
    document.paper_date_status = "suggested"
    document.paper_date_reason = suggestion.reason or None


def _apply_figures(
    question: Question,
    parsed: ParsedQuestion,
    figures: QuestionFigures,
    unreadable_chars: int,
    renderer: PdfRenderer | None,
) -> None:
    """Store figure crops on ``question`` and adjust its issues and image flag."""
    rows: list[QuestionFigure] = []
    if renderer is not None:
        for crop in figures.crops:
            try:
                data, width, height = renderer.render(crop.page, crop.box)
            except Exception:
                logger.exception("figure crop failed")
                continue
            rows.append(
                QuestionFigure(
                    kind=crop.kind,
                    option_position=crop.option_index + 1
                    if crop.option_index is not None
                    else None,
                    sort_order=len(rows),
                    page_number=crop.page,
                    box=crop.box.as_list(),
                    width=width,
                    height=height,
                    content_type="image/png",
                    data=data,
                )
            )
    question.figures = rows
    option_figures = {f.option_position for f in rows if f.option_position is not None}
    pictured = [f for f in rows if f.kind in ("stem", "option")]

    issues = [i for i in parsed.issues if i.code != IssueCode.EMPTY_OPTION]
    issues += [
        i
        for i in content_issues(
            option_texts=[o.text for o in parsed.options],
            answer_position=parsed.answer_position,
            expected_options=EXPECTED_OPTIONS,
            option_figures=option_figures,
        )
        if i.code == IssueCode.EMPTY_OPTION
    ]
    if pictured or (figures.ambiguous_options and rows):
        question.image_dependent = True
        pages = sorted({f.page_number for f in rows})
        detail = "Figure from page " + ", ".join(str(p) for p in pages)
        issues = [i for i in issues if i.code != IssueCode.IMAGE_DEPENDENT]
        issues.append(Issue(IssueCode.IMAGE_DEPENDENT, detail))
    reasons = []
    if unreadable_chars:
        reasons.append(f"{unreadable_chars} character(s) could not be read from the PDF")
    if figures.text_incomplete:
        reasons.append("part of the text is drawn as graphics (formula or symbols)")
    if reasons:
        detail = "; ".join(reasons) + ". Compare with the image of the question as printed."
        issues.append(Issue(IssueCode.UNREADABLE_TEXT, detail[:500]))
    question.issues = [
        QuestionIssue(document_id=question.document_id, code=i.code, detail=i.detail)
        for i in issues
    ]
