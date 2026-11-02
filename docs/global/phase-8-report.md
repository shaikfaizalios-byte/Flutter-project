# Global Phase 8 — Document intelligence for the India launch: acceptance report

Scope from [audit-and-roadmap.md](audit-and-roadmap.md) §5 "Phase 8". Branch
`claude/global-product-716ab9`, 1 Nov 2026. Details: [docs/document-ingestion.md](../document-ingestion.md).

## Approach

No real scanned papers were available to tune heuristics against, so this phase adds what can be
verified with generated PDFs and keeps a human in the loop: pages are **flagged**, never silently
reordered or "fixed", and scanned figures come from a **reviewer's** mark, not from a guess.

## What changed

- **Migration 0036:** `document_pages.script`, `question_figures.source` (pdf | reviewer, CHECK).
- **Per-page script** (`devanagari`, `latin`, `mixed`, `none`) from pure
  `app/domain/page_analysis.py`; a mostly-Devanagari page in a paper uploaded as English is flagged
  `devanagari_in_english_document` (it was read or OCR'd as English).
- **Two-column pages** on the text layer are flagged `two_columns` (check the question order). Lines
  are split into runs at wide gaps from PDFium character boxes (`page_layout.text_runs`), because
  PDFium joins both columns' text on a baseline into one line. Stored text is unchanged.
- **Reviewer-marked figures:** `POST /questions/{id}/figures` crops a region a reviewer marked on the
  page from the original PDF; `DELETE` removes a wrong one. App: "Mark a figure on the page" (drag a
  box on the page image), the marked figures listed with Remove. EN + HI.

## Tests

- Backend `tests/test_page_analysis.py` (8): script detection, two-column rule (both halves, lines
  across), region checks and page-coordinate conversion, a generated two-column PDF flagged with its
  text intact, a one-column page not flagged, a Devanagari OCR page in an English paper flagged,
  marking/removing a figure (PNG served, question image-dependent), invalid regions and other
  accounts refused. Full suite, ruff, mypy, `alembic check` passing.
- Mobile `mark_figure_test.dart` (3): drag-to-fraction math, the page opens with Keep disabled
  until a box is drawn, removing a marked figure. 442 tests passing, analyze clean.

## Not done / risks

- **Not validated on real scans or real two-column papers.** The two-column thresholds are
  untested beyond generated pages; measure them on representative papers before trusting the flag.
- Questions on two-column pages are still segmented in PDF text order; only the flag tells the
  reviewer to check. Column-aware reordering needs real samples first.
- Passages continuing across pages without a stated range are still not detected.
- Page review reasons aren't shown in the app yet (they're in the API's page list); the reviewer
  sees question issues and the page itself.
- The drag gesture itself isn't covered by widget tests (image decoding in tests); the region math
  and the API are.
- No language detection beyond Devanagari/Latin, no other OCR languages, no multi-select questions.
