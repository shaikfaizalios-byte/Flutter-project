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
  5 tabs), Dio (single `dioProvider`), Material 3, gen-l10n (EN + HI). Drift/SQLite arrives in Phase 2.
- **Backend:** modular monolith. FastAPI + Pydantic v2 + pydantic-settings; routing → service → repository.
  SQLAlchemy 2 + Alembic + PostgreSQL arrive in Phase 2. Versioned under `/api/v1`.
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
- Python: ruff (format + lint), mypy strict, type hints everywhere, line length 100.
- Small, reviewable commits. Inspect files before modifying. Don't upgrade unrelated packages.
- Before adding a package: state its purpose, check compatibility and licence.

## Commands (Windows PowerShell, from repo root)
```powershell
.\scripts\setup.ps1          # one-time: venv + pip install (lock file), flutter pub get, gen-l10n
.\scripts\dev-api.ps1        # API on http://127.0.0.1:8000  (docs: /docs)
.\scripts\dev-mobile.ps1     # Flutter on Chrome; -Device emulator-5554 for Android emulator
.\scripts\check.ps1          # ruff, mypy, pytest, dart format, flutter analyze, flutter test
.\scripts\export-openapi.ps1 # refresh contracts/openapi/openapi.json after API changes
```
Toolchain locations on the dev machine: Flutter SDK `D:\dev\flutter` (on user PATH), Python 3.12 (winget),
backend venv `services/api/.venv`. Shells opened before installation need a restart to see PATH changes.

## Security rules
- Never commit secrets, `.env`, signing keys, service-account files, local DBs or uploads (.gitignore covers these).
- Provider API keys live only on the server. The mobile app embeds no secrets.
- Don't log tokens, passwords, document content or unnecessary personal data (request log records path only, no query).
- Enforce ownership at the service/repository boundary once accounts exist; never trust filenames/paths as auth.
- Production: HTTPS only, explicit CORS origins, interactive docs disabled, migrations (never create_all).

## Current phase: Phase 1 complete → next is Phase 2 (database & persistence)
Known limitations right now:
- Android SDK / Android Studio not installed → no Android build verified yet. iOS needs macOS + Xcode.
- Visual Studio C++ workload not installed → Windows desktop target unavailable (not a product target anyway).
- Preferences (language/theme) are in-memory only; persisted in Phase 2.
- Flutter web downloads the Devanagari fallback font on demand; bundle Noto Sans Devanagari in Phase 3.
- No CI workflow yet; no typed API client generated yet (only one endpoint exists).
- Hindi strings were written without native-speaker review.
- Starlette 1.7 warns that `httpx` for TestClient is deprecated in favour of `httpx2`; deferred until vetted.

## Phase 2 acceptance criteria
1. PostgreSQL runs locally via `infra/docker/docker-compose.yml` (or a documented native install); the
   API's `/api/v1/health/ready` reports database connectivity (503 when down).
2. SQLAlchemy 2 models + an initial Alembic migration for `exams` and `concepts`
   (title, notes, exam, subject, topic, subtopic, language, tags, source_reference, archived_at, timestamps).
   `alembic upgrade head` on an empty DB succeeds; no `create_all` outside tests.
3. Concept CRUD + archive + search under `/api/v1/concepts` via route → service → repository, with Pydantic
   schemas, pagination, validation errors in the standard envelope; OpenAPI exported to contracts/.
4. Pytest covers repositories against a real test database, services, API validation and 404s.
5. Mobile: Drift/SQLite database with a `concepts` table + migration strategy; a concepts repository that
   persists locally (offline-first) with the cache/sync rules documented before any sync is implemented.
6. Mobile: language/theme preferences persist across restarts.
7. Mobile: a minimal concept list + create form backed by the local DB (localised EN/HI, empty/error states).
8. `scripts/check.ps1` passes; docs (database.md, api.md) updated; known limitations listed.
