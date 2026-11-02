# Global Phase 10 — Language groundwork (part 1): acceptance report

Scope from [audit-and-roadmap.md](audit-and-roadmap.md) §5 "Phase 10": the second Indian exam
end to end, then localisation groundwork. Branch `claude/global-product-716ab9`, 2 Nov 2026.

## Status of the two parts

- **Second exam (railways, RRB NTPC / Group D, chosen by the founder): waiting for the official
  notice.** The RRB websites were unreachable from this machine (connection refused, or a TLS
  certificate for another host); coaching sites disagree on durations and counts, and exam facts
  are never taken from them. Once the founder provides the official CEN PDF(s), the format is
  imported as a draft, checked and published, and the syllabus and `exams.languages` are entered
  from the notice with its number recorded.
- **Language groundwork: done** (this report).

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
