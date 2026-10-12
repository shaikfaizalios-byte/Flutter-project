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
```
Toolchain locations on the dev machine: Flutter SDK `D:\dev\flutter` (on user PATH), Python 3.12 (winget),
backend venv `services/api/.venv`, PostgreSQL 17 Windows service `postgresql-x64-17` (port 5432; role
`preploop`, DBs `preploop` + `preploop_test`; URLs in gitignored `services/api/.env`; superuser password in
`%USERPROFILE%\.preploop\postgres-superuser.txt`). Shells opened before installation need a restart for PATH.

## Security rules
- Never commit secrets, `.env`, signing keys, service-account files, local DBs or uploads (.gitignore covers these).
- Provider API keys live only on the server. The mobile app embeds no secrets.
- Don't log tokens, passwords, document content or unnecessary personal data (request log records path only, no query).
- Enforce ownership at the service/repository boundary once accounts exist; never trust filenames/paths as auth.
- Production: HTTPS only, explicit CORS origins, interactive docs disabled, migrations (never create_all).

## Current phase: Phase 3 complete → next is Phase 4 (document ingestion)
Known limitations right now:
- Android SDK / Android Studio not installed → no Android build verified; `integration_test/` not yet run
  on a device. iOS needs macOS + Xcode.
- Visual Studio C++ workload not installed → Windows desktop target unavailable (not a product target anyway).
- Web: the Claude desktop browser pane can't fetch from web workers, so Drift's web DB never opens there
  (app renders after a 3 s storage timeout, shows first-run onboarding, concept list stays loading).
  Verify web persistence in Chrome/Edge. Native is unaffected.
- No auth/ownership on `/api/v1/concepts` (single-tenant dev API until Phase 10) — never deploy publicly.
- Mobile concepts and study profile are local-only (sync = Phase 10).
- Exam list on mobile is a constant mirroring the server seed; subject/topic are free text; filter choices
  come from the learner's own data (no managed taxonomy yet).
- Reminder time is stored but no notifications are scheduled yet (Phase 7). The UI says so.
- "What should I study today?" shows real counts/goal but no generated plan yet (Phase 8).
- No CI workflow yet; no typed Dart API client generated yet.
- Hindi strings were written without native-speaker review.
- Starlette 1.7 warns that `httpx` for TestClient is deprecated in favour of `httpx2`; deferred until vetted.
- PostgreSQL is a native install; no docker-compose yet (optional).

## Phase 4 acceptance criteria (document ingestion)
0. **Licence decision first:** PyMuPDF (named in the brief) is AGPL-3.0 or commercial. Running it in a
   network service can trigger AGPL source-disclosure duties. Document the decision (accept AGPL, buy a
   licence, or use a permissive alternative such as pypdfium2 Apache-2.0/BSD) before adding it.
1. `POST /api/v1/documents` (multipart): validates content by magic bytes (not extension/MIME), size limit
   and page limit (configurable), rejects encrypted/corrupt/non-PDF with the standard error envelope;
   rate-limited. Stores the file via a `DocumentStorage` interface (local-disk impl) under a generated
   UUID path — the user's filename is metadata only (sanitised), never part of a path.
2. Alembic migration for `documents` (exam, language, original filename, size, sha256, page_count,
   status queued/processing/completed/failed, extraction method summary, error code, timestamps) and
   `document_pages` (page number, method text|ocr|none, normalised text, confidence, needs_review).
3. Per-page extraction off the request path (background worker/task) with a processing time limit: text
   layer first; OCR (Tesseract eng+hin, behind an `OcrEngine` interface) when the text layer is missing or
   below a configurable quality threshold. Uncertain pages are flagged `needs_review`; text is never
   invented. Large files are processed page by page (bounded memory).
4. `GET /api/v1/documents`, `GET /api/v1/documents/{id}` (status, progress, warnings),
   `GET /api/v1/documents/{id}/pages`, `DELETE /api/v1/documents/{id}` (explicit; removes file + rows).
5. Tests use small synthetic PDFs generated in the test suite (text PDF, image-only page, mixed,
   encrypted, corrupt, wrong type, oversize, too many pages) and a fake OCR engine; real Tesseract tests
   skip when it isn't installed. Upload validation and error-path tests included.
6. Mobile: an "Import paper" entry in Study that picks a PDF, uploads it with progress, and lists
   documents with live status (queued/processing/completed/failed + warnings); offline/server-down
   states. Requires a file-picker package (state purpose/licence before adding).
7. Tesseract installation documented (Windows + Linux), including Hindi language data; `scripts/check.ps1`
   passes; docs (api.md, database.md, security.md) updated with retention and deletion behaviour.
