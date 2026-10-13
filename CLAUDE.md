# CLAUDE.md — PrepLoop project guidance

Persistent guidance for Claude Code sessions. Keep it current when phases, commands or decisions change.

## Product scope
PrepLoop is a personalised exam-preparation app for **SSC CGL and SSC CHSL** aspirants (English and Hindi).
Core loop: select exam → import papers/material → extract & organise questions → practise / flashcards →
track weak topics → scheduled revision → reminders → measurable progress.

Non-negotiable product rules:
- Distinguish **verified source content** from **AI-generated content** everywhere (data model + UI labels).
- Never present generated questions as official previous-year questions.
- Never invent exam patterns, question counts, cutoffs or marking schemes; they come from configuration.
- No fake statistics, charts or question data in production flows. Dev fixtures are labelled as sample data.
- Uncertain OCR/parsing/topic results are flagged for review, never silently "fixed".
- The domain model must allow other exams later without rewrites (exam is data, not code).

## Repository structure
```
apps/mobile/        Flutter app (UI, state, offline DB, device integrations). No Python here.
services/api/       FastAPI backend (API, services, persistence, AI orchestration). No Dart here.
contracts/openapi/  Exported OpenAPI schema (scripts/export-openapi.ps1). Source of the typed client.
docs/               Architecture, API, security, testing, release docs.
scripts/            PowerShell dev utilities (setup, run, check, export).
infra/              Containers/deployment (added in Phase 2+).
```
Frontend and backend never share DB entities; they talk via explicit API schemas only.

## Architecture decisions (see docs/architecture.md for rationale)
- **Mobile:** feature-first Clean Architecture (`features/<f>/{presentation,application,domain,data}`),
  only the layers a feature actually needs. Riverpod 3 for state + DI, GoRouter (StatefulShellRoute,
  5 tabs, onboarding gate via redirect), Dio (single `dioProvider`), Material 3, gen-l10n (EN + HI),
  bundled Noto Sans Devanagari fallback. Drift/SQLite (`core/database`, schema v2)
  is the offline-first local store; repositories in `features/*/data`. Phase 2 is local-only — no sync.
- **Backend:** modular monolith. FastAPI + Pydantic v2 + pydantic-settings; routing → service → repository.
  SQLAlchemy 2 (sync, psycopg 3) + Alembic + PostgreSQL 17. Services own the transaction (commit per
  operation); domain errors (`app/domain/errors.py`) map to HTTP in `app/core/errors.py`. Versioned `/api/v1`.
- Exams are reference data (`exams` table, `core/exams/exam_catalog.dart` on mobile), never code branches.
- Documents: upload → validate (magic bytes, PDFium) → `DocumentStorage` → DB-backed queue → worker
  (`app/workers/document_worker.py`, lease + SKIP LOCKED) → per-page text layer or Tesseract OCR
  (`OcrEngine`), uncertain pages flagged. pypdfium2, not PyMuPDF (AGPL). See docs/document-ingestion.md.
- Question bank: worker runs the pure segmenter (`app/domain/segmentation.py`) after extraction →
  `questions`/`question_options`/`passages`/`question_issues`; review via PATCH (verify blocked while
  content issues are open); re-runs keep verified/rejected questions; `exam_formats` rows only with a
  recorded official source; topic keywords only suggest. See docs/question-bank.md.
- See docs/database.md for schemas, migration workflows and the designed (not implemented) sync rules.
- Errors: backend returns `{"error": {"code","message","request_id","details"}}`; mobile maps Dio errors to
  sealed `AppFailure` types in repositories. Widgets never see Dio types.
- Config: backend env vars prefixed `PREPLOOP_`; mobile build-time `--dart-define` (`API_BASE_URL`, `FLAVOR`,
  `APP_NAME`). Non-development mobile builds require https. Production backend rejects wildcard/regex CORS.
- Every response carries `X-Request-ID`; logs are JSON lines with request_id.

## Coding conventions
- Dart: `dart format` page width 100 (set in analysis_options.yaml); strict-casts/raw-types; no hardcoded
  user-facing strings — add keys to `lib/core/localization/arb/app_en.arb` **and** `app_hi.arb`.
- Shared UI lives in `lib/core/widgets/` and theme tokens in `lib/app/theme/` (use `AppSpacing`).
- No DB queries, scheduling rules, scoring or AI calls inside widgets.
- Mobile errors: log with `logError` (`core/utils/app_log.dart`), never user content. Generated code
  (`*.g.dart`, l10n) is committed; regenerate with `dart run build_runner build` / `flutter gen-l10n`.
- Widget tests that pump the app use `testAppWidgets` (test/helpers/pump_app.dart), not `testWidgets`.
- Backend validation limits must match mobile `ConceptRules` (same normalisation both sides).
- Extracted/parsed text is stored as found (whitespace + NFC only); uncertainty → review flags with
  reason codes, never silent correction. Test PDFs are generated (tests/pdf_factory.py), never real papers.
- Every question shows its origin (source PDF vs AI). Exam patterns/counts/marking come only from
  `exam_formats` (verified, sourced) — never hard-code them in code or UI.
- Mobile app tests get a `FakeQuestionsRepository` by default (`pumpPrepLoopApp(questions: ...)`).
- Mobile time: read "now" from `clockProvider`; date-only values use `CalendarDate` (never `DateTime`).
- New ARB keys go in both files; `arb_parity_test.dart` fails otherwise. Hindi-capable text needs no
  per-widget font: the theme's `fontFamilyFallback` covers Devanagari.
- Python: ruff (format + lint), mypy strict, type hints everywhere, line length 100.
- Small, reviewable commits. Inspect files before modifying. Don't upgrade unrelated packages.
- Before adding a package: state its purpose, check compatibility and licence.

## Commands (Windows PowerShell, from repo root)
```powershell
.\scripts\setup.ps1          # one-time: venv + lock-file install, alembic upgrade, pub get, l10n, build_runner
.\scripts\dev-api.ps1        # API on http://127.0.0.1:8000  (docs: /docs)
.\scripts\dev-mobile.ps1     # Flutter on Chrome (cross-origin isolated); -Device emulator-5554 for Android
.\scripts\check.ps1          # ruff, mypy, pytest (real Postgres), alembic check, dart format, analyze, test
.\scripts\export-openapi.ps1 # refresh contracts/openapi/openapi.json after API changes
python scripts\serve_web.py  # serve apps/mobile/build/web with COOP/COEP headers on :8080
cd services\api; .\.venv\Scripts\python.exe -m app.workers.document_worker  # standalone worker
```
Toolchain locations on the dev machine: Flutter SDK `D:\dev\flutter` (on user PATH), Python 3.12 (winget),
backend venv `services/api/.venv`, PostgreSQL 17 Windows service `postgresql-x64-17` (port 5432; role
`preploop`, DBs `preploop` + `preploop_test`; URLs in gitignored `services/api/.env`; superuser password in
`%USERPROFILE%\.preploop\postgres-superuser.txt`), Tesseract 5.4 at `C:\Program Files\Tesseract-OCR`
with eng+hin data in `%USERPROFILE%\.preploop\tessdata` (configured in `services/api/.env`).
Shells opened before installation need a restart for PATH.

## Security rules
- Never commit secrets, `.env`, signing keys, service-account files, local DBs or uploads (.gitignore covers these).
- Provider API keys live only on the server. The mobile app embeds no secrets.
- Don't log tokens, passwords, document content or unnecessary personal data (request log records path only, no query).
- Enforce ownership at the service/repository boundary once accounts exist; never trust filenames/paths as auth.
- Production: HTTPS only, explicit CORS origins, interactive docs disabled, migrations (never create_all).

## Current phase: Phase 5 complete → next is Phase 6 (practice & mock tests)
Known limitations right now:
- Android SDK / Android Studio not installed → no Android build verified; `integration_test/` not yet run
  on a device. iOS needs macOS + Xcode. The native PDF picker is only exercised via a fake in tests.
- Visual Studio C++ workload not installed → Windows desktop target unavailable (not a product target anyway).
- Web: the Claude desktop browser pane can't fetch from web workers, so Drift's web DB never opens there
  (app shows first-run onboarding after a 3 s timeout; concept list stays loading). Server-backed screens
  (documents, question review) work there. Verify web persistence in Chrome/Edge. Native is unaffected.
- **No auth/ownership on `/api/v1/concepts`, `/documents`, `/questions`** (single-tenant dev API until
  Phase 10) — never deploy publicly.
- Mobile concepts and study profile are local-only (sync = Phase 10). Documents and the question bank are
  server-only (no offline cache yet).
- Only one verified exam format exists (SSC CHSL 2026 Tier-I, from the official notice). **SSC CGL has
  none** — add only after verifying the current official notice (record source in a migration).
- Segmenter limits: passages without a stated question range aren't detected; table-style answer keys
  aren't parsed; bilingual papers keep only the first language's options (rest in issue detail).
  Issue details are English (labels are localised).
- Upload rate limiter is per-process; no malware scanning; PDF parsing runs in the worker process.
- Hindi OCR quality depends on scan quality; low-confidence pages are flagged, never corrected.
- Reminder time is stored but no notifications are scheduled yet (Phase 7). The UI says so.
- "What should I study today?" shows real counts/goal but no generated plan yet (Phase 8).
- No CI workflow yet; no typed Dart API client generated yet (hand-written DTO parsing per feature).
- Hindi strings were written without native-speaker review.
- Starlette 1.7 warns that `httpx` for TestClient is deprecated in favour of `httpx2`; deferred until vetted.
- PostgreSQL is a native install; no docker-compose yet (optional).

## Phase 6 acceptance criteria (practice & mock tests)
1. Practice draws **only verified, non-image-dependent source questions** by default (unverified ones only
   if the learner opts in, clearly labelled "not yet reviewed"); never mixes AI questions without a label.
2. Practice modes: topic-wise, section/subject-wise, mixed; untimed with immediate correct/incorrect
   feedback and the explanation when one exists; session summary (score, accuracy, time, per-topic).
3. Timed mock tests **only for verified exam formats**: question count, sections, duration and marking
   (marks per question = section max marks / questions; negative marks) come from `exam_formats` — never
   hard-coded. If too few verified questions exist, the mock is unavailable with an explanation.
4. Robust test state: server-side `practice_sessions` + `attempts` (Alembic); the timer is derived from the
   server-recorded start time (closing/reopening the app cannot reset it); answers saved as they are given
   (offline-tolerant local queue on mobile, replayed idempotently); submission is idempotent; expired tests
   auto-submit with saved answers.
5. Scoring validated against the format's marking scheme with unit tests (correct, wrong, unattempted,
   negative marking, section totals); results explain how the score was computed.
6. Bookmarks, incorrect-answer review, and question/session history (per question: attempts, last result).
7. Attempt data recorded per question/topic/section for Phase 8 analytics (no analytics UI yet beyond the
   session summary).
8. EN/HI UI; tests for scoring, timer persistence (simulated restart), idempotent submit, offline answer
   queue; `scripts/check.ps1` passes; docs updated.
