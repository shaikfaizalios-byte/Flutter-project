# Global Phase 5 — Exam configuration engine v1: acceptance report

Scope from [audit-and-roadmap.md](audit-and-roadmap.md) §5 "Phase 5". Branch
`claude/global-product-716ab9`, 1 Nov 2026. Two slices.

## 5a — Formats as reviewed versions; catalog exams by configuration (`cd1d402`)

- **Migration 0032:** `exam_formats` gain `status` (draft/verified/retired), `effective_from/to`,
  `supersedes_id`, `question_types`, `sectional_timing`, `reviewed_by`, `review_notes` (CHECKs:
  published ⇒ reviewed; dates in order). The two recorded formats become verified; CGL is
  sectionally timed (all its sections record a timer). `exams` gain `country_code` (ISO alpha-2
  CHECK), `authority`, `aliases`; the 0012 catalog exams (all Indian) get IN; authorities are left
  empty for the operator (not guessed).
- **Rules:** pure `config_problems` (timers add up, fixed order when timed, supported answer types,
  dates, https source with title and reference) and `in_effect`; `app/services/exam_formats.py`:
  new mocks only from verified formats in effect today; drafts never shown or linkable.
- **Operator tool** `python -m app.cli.exam_formats`: `import` (draft from JSON, unknown keys
  refused), `check`, `publish --reviewer` (refused while anything is missing; ends the superseded
  version the day before the new one starts), `retire --on`, `list`, and `exam` to add or describe
  catalog exams. Formats are never edited once published.
- **Decision:** no separate `exam_authorities` / `exam_versions` tables (the audit floated them):
  the format row already is the version, and authority is one text field until a second country
  needs more.

## 5b — Sectional timers in mocks

- **Migration 0033:** `practice_sessions.current_section`, `section_started_at`; the section plan
  is copied into `selection.sections` at the start, so the attempt never changes with the format.
- **Rules** (`app/domain/sections.py`): sections in order; each closes at its own time or when
  finished early; no way back; the last closing submits. Server refuses answers outside the open
  section (`409 section_closed`) and withholds questions of sections not open yet.
  `POST /practice/sessions/{id}/next-section` (idempotent by `from_section`).
- **App:** section banner, the section's own countdown, Finish section with a confirmation, no
  going back, palette limited to the open section, next section loaded when time is up. EN + HI.
- **Honesty note:** the notice gives the timers and order; "finish a section early" is this mock's
  choice and the marking note says so.

## Tests

- Backend: `test_exam_format_versions.py` (8: publish rules, in-effect, migrated formats, draft
  hidden then published, new version ends the old one, retiring, catalog exams), `test_sectional_mock.py`
  (7: schedule rules, CGL mock opens section 1 only, answers only in the open section, time-up
  opens the next and ends the mock, finishing early incl. idempotent retry and the last submitting,
  CHSL unchanged), plus updated `test_exam_format.py` and the exam list test. Full suite, ruff,
  mypy, `alembic check` (migrations up → down → up incl. 0032/0033) all passing.
- Mobile: `sectional_mock_test.dart` (4: open section, banner/timer/Finish section, finishing moves
  on with no way back, time-up opens the next). 432 tests passing, analyze clean.

## Not done / risks

- Effective dates are compared with the server's UTC date (a format starting "today" in India
  becomes usable at 05:30 IST).
- Offline: mocks need a connection (unchanged); an answer queued for a section that has since
  closed is dropped by the server (`section_closed`), which matches the exam's rule.
- No admin UI: formats and catalog exams are managed with the CLI.
- Canonical taxonomy (sections ↔ topics by ID rather than name) is Phase 6.
