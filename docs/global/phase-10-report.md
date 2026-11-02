# Global Phase 10 — Language groundwork and RRB NTPC: acceptance report

Scope from [audit-and-roadmap.md](audit-and-roadmap.md) §5 "Phase 10": the second Indian exam
end to end, then localisation groundwork. Branch `claude/global-product-716ab9`, 2 Nov 2026.

## Status of the two parts

- **Second exam: RRB NTPC, from CEN 06/2026 (Graduate) and CEN 07/2026 (Under Graduate)**, the
  official notices the founder downloaded (the RRB sites were unreachable from this machine). See
  "Part 2" below.
- **Language groundwork: done** (part 1).

## What changed

- **One reference list** for content languages: `app/domain/languages.py` (code, English and
  native names, ISO 15924 script, direction, Tesseract data, the name used in prompts, whether
  AI-written text needs a language review). Behaviour that branched on `"hi"` reads it: OCR
  language set, prompt language names, the AI language-review flag.
- **Migration 0037:** a `languages` table (seeded en, hi) replaces the `language IN ('en','hi')`
  CHECK constraints on `documents`, `questions`, `concepts` and `ai_explanations` with foreign
  keys. `exams.languages` (empty for every exam: none has been recorded from a notice yet), set by
  `python -m app.cli.exam_formats exam CODE --languages en,hi`, refused for unsupported codes.
- **API:** one `Language` type (validated against the list; the OpenAPI schema still lists the
  codes as an enum). `ExamRead.languages`.
- **App:** `ContentLanguage` is now a code value, not an enum: a code the app doesn't know is
  kept and shown as its code instead of silently becoming English (it used to). Language choices
  are built from one list. Settings → Language gains **"Papers, syllabus and notes"** (preselected
  when adding them) and **"AI lessons and checks"**, each "Same as app" by default. AI
  explanations stay in their question's language. EN + HI strings.

Adding a language is now: an entry in the domain list and a migration row (after checking OCR
data, fonts and AI quality), the app's `ContentLanguage.known` and its translated name, and the
operator recording which exams offer it. No CHECK constraint or Literal changes.

## Tests

- Backend `test_languages.py` (5): database rows equal the list, behaviour reads the list, an
  unknown code can't be stored (foreign key), the OpenAPI enum, requests in another language
  refused with the list. Exam languages set, de-duplicated and validated
  (`test_exam_format_versions.py`). Full suite, ruff, mypy, `alembic check`, upgrade/downgrade.
- Mobile: unknown codes kept, choices include an unknown current language, content/AI languages
  follow the interface unless chosen, preferences round-trip and clear, the Settings choices.

## Not done / risks

- Explanations in a language other than the question's would need one approved explanation per
  language (today one per question); deferred.
- No RTL work (not needed for en/hi); `direction` is recorded for when a market needs it.
- Interface translations are still en/hi only; a new UI language is a separate translation task.
- `taxonomy_labels.language` keeps its own ISO pattern check (labels may exist for languages
  before content in them is supported).
- Hindi strings still lack a native-speaker review.

## Part 2 — RRB NTPC (migration 0038)

Every fact below was read from the notices and checked against the rendered pages (the tables'
text layer scrambles its header):

- **Four draft formats** (`services/api/data/exam_formats/`): Graduate and Under Graduate, 1st stage
  CBT (90 min, 100 questions: General Awareness 40, Mathematics 30, General Intelligence and
  Reasoning 30; para 13.1) and 2nd stage CBT (90 min, 120 questions: 50 / 35 / 35; para 13.2.1).
  1 mark each, 1/3 mark deducted per wrong answer, no sectional timers. Each imports with no
  problems; **none is published**: the operator checks it against the notice and publishes it
  under their own name.
- **"Only indicative"**: the notices say the section split may vary in real papers. New
  `exam_formats.section_counts_indicative`; mocks keep the stated counts and say so (mock card,
  marking note).
- **Catalog**: authority "Railway Recruitment Boards (Ministry of Railways)" and the 15 languages of
  para 14.3 (d). `exams.languages` now takes any ISO 639 code (an exam's own languages, not only
  PrepLoop's content languages).
- **Taxonomy and syllabus**: "Mathematics" is an alias of the canonical "Quantitative Aptitude" so
  mock sections find those questions; 25 syllabus items of para 13.1 not covered by a shared topic
  are added as shared topics for RRB_NTPC only, each with its own confirmed canonical topic.

Tests: `test_rrb_ntpc.py` (8): catalog facts, topics only for NTPC and not duplicated, the alias,
each draft importable and publishable, a published mock's indicative flag, alias-based section
availability and marking note. Migration 0038 upgrades, downgrades and matches the models.

Part 2 risks / not done:

- **Publishing is the operator's step**: until a reviewer publishes the drafts, RRB NTPC has no mock.
- The source URL is the RRB portal the notice names (`https://rrb.indianrailways.gov.in`), not the
  PDF's own address (the file was downloaded by hand). The publication date recorded is the
  Employment News indicative notice date; the detailed CEN states no other.
- Mocks use the indicative counts; real papers may differ (labelled).
- The shared English Language topics were already scoped to RRB NTPC and Group D in migration 0012,
  although the NTPC notices have no English section. Left unchanged (learners' questions may use
  them); worth reviewing.
- RRB Group D: no notice yet, nothing recorded.
- Hindi labels for the new topics were not added (no reviewed Hindi names).

