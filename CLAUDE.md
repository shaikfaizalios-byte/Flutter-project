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
  bundled Noto Sans Devanagari fallback. Drift/SQLite (`core/database`, schema v5)
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
- Figures: after segmentation the worker reads page layouts with PDFium (`app/services/page_layout.py`) and
  the pure `app/domain/figures.py` assigns figure crops (stem / option / `original` = question as printed)
  to questions → `question_figures` (PNG in Postgres), served by `GET /questions/{id}/figures/{fid}`; mobile
  shows them as printed (`QuestionFigureView`, bytes via Dio for auth). Questions with figures are practice-
  eligible. Topics: keyword rules store a reason (`topic_suggestion_reason`); optional per-paper AI step
  (`POST /ai/documents/{id}/topic-suggestions`) for the rest; `POST /documents/{id}/topics/accept` bulk-confirms.
- Repeated models (the product's core insight): `question_patterns` (named question types under topics,
  seeded in migration 0010) suggested by keyword rules within the topic, confirmed like topics; paper
  date/shift suggested from filename/first page (`app/domain/paper_date.py`), confirmed via
  `PUT /documents/{id}/paper-date`; `GET /insights/repeats` counts reviewed topics/patterns per paper and
  confirmed year (unreviewed apart) + wording-similarity groups (`app/domain/similarity.py`, numbers masked).
  Mobile `features/insights` (Practice tab → Repeated models; `RepeatRules` shown in UI). See docs/insights.md.
- Repeat Radar: opt-in (`users.radar_opt_in`) pooling of confirmed topic/pattern counts per confirmed exam
  shift across accounts, read live; pure `app/domain/radar.py` publishes a shift only with >= 2 accounts and a
  count only when >= 2 accounts agree. `GET /radar`, `GET/PUT /radar/settings`; mobile "All learners" view +
  `RadarSharingCard` (Profile). Response-sheet score checker NOT built yet (needs a real sheet sample).
- Practice (`app/services/practice_service.py`, pure `app/domain/scoring.py`): server-side sessions with
  per-item snapshots; mock timer = server `deadline_at`, expiry auto-submits lazily; answers carry
  `client_seq` (highest wins), submit idempotent; Decimal scoring with explanations. Mobile queues every
  answer in Drift `pending_answers` (schema v3) and replays it. See docs/practice.md.
- Accounts (Phase 10): own email+password — Argon2id, 15-min HS256 access JWT (`PREPLOOP_AUTH_SECRET`,
  required in staging/prod), rotating SHA-256-stored refresh tokens with family reuse detection
  (`app/core/security.py`, `app/services/auth_service.py`). Every learner router requires `CurrentUser`
  (`app/api/deps.py`) AND every service takes the owner id and scopes every query (other accounts → 404).
  First account claims pre-account (owner NULL) rows. Mobile: `flutter_secure_storage`, `AuthInterceptor`
  (single refresh + one retry via a separate client), sign-in gate in `appRedirect`.
- Account recovery (Phase 11): emailed 6-digit codes (`account_codes`, HMAC-stored, 15 min, 5 tries) for
  password reset (no enumeration; emails sent in background; reset revokes all sessions) and email
  verification. Email via `EmailSender` (`app/integrations/email.py`): SMTP (stdlib) or dev file outbox.
  Rate limits: `RateLimiter` protocol, `PostgresRateLimiter` (shared) in staging/prod. Staging/prod settings
  refuse to start without auth secret, postgres limits and TLS SMTP. Metrics: `/api/v1/metrics` (token).
- Sync (Phase 10): server `sync_items` per account (strict per-entity schemas, `sync_seq` cursor, LWW,
  tombstones win, per-account advisory lock). Device: repositories call `db.markDirty(entity, id)` in the
  same transaction; `SyncEngine` pushes current state of outbox ids (versioned clear), pulls all pages and
  applies in one deferred-FK transaction skipping pending records. Switching account erases device data.
  See docs/accounts-sync.md.
- AI (optional; off without `PREPLOOP_AI_API_KEY`): server-only `AIProvider` (`app/integrations/ai.py`,
  Anthropic SDK, default `claude-haiku-5-5`; `FakeAIProvider` in tests). Prompts/schemas/validation are pure
  (`app/domain/ai_content.py`, versioned `PROMPT_VERSION`). AI questions = `origin=ai` rows with provenance
  (CHECK), unverified; AI explanations in `ai_explanations` (draft→approved), never in `questions.explanation`;
  every call logged in `ai_generations` without text. Practice uses AI only with `include_ai`; mocks never.
  See docs/ai.md.
- Analytics: `GET /api/v1/analytics/overview?timezone=<IANA>` returns RAW counts only (days bucketed in
  PostgreSQL with `timezone(zone, answered_at)`; mock answers count only once submitted). Mobile decides
  accuracy/"weak" with named `AnalyticsRules` (shown in UI) and builds the daily plan with the pure
  `buildStudyPlan` (no AI; every item has a reason). Charts are plain widgets. See docs/analytics.md.
- Revision (device-only, Drift v4 `revision_cards`/`card_reviews`): pure `RevisionScheduler` with a stored
  ladder (`revision_day_offsets`, default 1/4/7 days after adding) and Good/Easy/Hard/Forgot adaptation;
  concept cards read the live concept, question cards snapshot verified source questions only.
  Reminders: `ReminderController` keeps ONE daily notification (fixed id) in sync via a plan fingerprint;
  `ReminderScheduler` wraps flutter_local_notifications (inexact alarms). See docs/revision.md.
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
- Mobile app tests get `FakeQuestionsRepository`, `FakePracticeRepository`, `FakeReminderScheduler`,
  `FakeAnalyticsRepository` (timezone fixed to Asia/Kolkata), `FakeAiRepository` (AI off), and start
  signed in (`testSession`, `FakeAuthApi`, `FakeTokenStore`, `FakeSyncServer`, auto-sync off) by default
  (`pumpPrepLoopApp(questions: ..., practice: ..., clockOverride: ...)`).
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
python scripts\serve_web.py  # serve apps/mobile/build/web with COOP/COEP headers on :8080 (--lan: phones on Wi-Fi; add origin to PREPLOOP_CORS_ORIGINS)
docker compose -f infra/docker-compose.yml up --build   # full stack + Mailpit (needs Docker; copy infra/compose.env.example)
services\api\.venv\Scripts\python.exe scripts\generate_app_icons.py  # launcher icons (Android/iOS/web)
cd apps\mobile; flutter build appbundle --release --dart-define=FLAVOR=production --dart-define=API_BASE_URL=https://...
cd services\api; .\.venv\Scripts\python.exe -m app.workers.document_worker  # standalone worker
```
Toolchain locations on the dev machine: Flutter SDK `D:\dev\flutter` (on user PATH), Python 3.12 (winget),
backend venv `services/api/.venv`, PostgreSQL 17 Windows service `postgresql-x64-17` (port 5432; role
`preploop`, DBs `preploop` + `preploop_test`; URLs in gitignored `services/api/.env`; superuser password in
`%USERPROFILE%\.preploop\postgres-superuser.txt`), Tesseract 5.4 at `C:\Program Files\Tesseract-OCR`
with eng+hin data in `%USERPROFILE%\.preploop\tessdata` (configured in `services/api/.env`).
Shells opened before installation need a restart for PATH.
Docker and the Android SDK are NOT installed locally: CI (GitHub Actions, `.github/workflows/ci.yml`) builds the
image, validates compose and builds the Android APK; `device-tests.yml` (manual) runs integration tests on an
emulator. Release/deployment steps: docs/release.md, docs/deployment.md.

## Security rules
- Never commit secrets, `.env`, signing keys, service-account files, local DBs or uploads (.gitignore covers these).
- Provider API keys live only on the server. The mobile app embeds no secrets.
- Don't log tokens, passwords, document content or unnecessary personal data (request log records path only, no query).
- Enforce ownership at the service/repository boundary once accounts exist; never trust filenames/paths as auth.
- Production: HTTPS only, explicit CORS origins, interactive docs disabled, migrations (never create_all).

## Current phase: Phase 11 complete → release candidate (operator steps in docs/release.md)
Known limitations right now:
- Android SDK / Android Studio not installed locally. CI builds the Android APK, and the device-tests workflow
  ran `integration_test/` green on an Android 14 emulator (secure storage, on-disk DB, onboarding flow).
  Not yet verified on a physical phone: notifications, PDF picker, R8. iOS needs macOS + Xcode.
- Visual Studio C++ workload not installed → Windows desktop target unavailable (not a product target anyway).
- Web: the Claude desktop browser pane can't fetch from web workers, so Drift's web DB never opens there
  (app shows first-run onboarding after a 3 s timeout; concept list stays loading). Server-backed screens
  (documents, question review) work there. Verify web persistence in Chrome/Edge. Native is unaffected.
- Not deployed anywhere yet; production topology documented (docs/deployment.md) but no hosting chosen.
  Docker image/compose and the Android build are verified only by CI (no Docker/Android SDK locally).
- Accounts: no device list or remote session revocation UI. Unverified emails can still use the app.
- Legal texts are DRAFTS with [placeholders] (operator, contact, processors, retention, law, minimum age).
- Launcher icon/splash are provisional (generated); application id `com.preploop.preploop` must be changed
  to the operator's domain before the first Play upload. R8 shrinking is off until verified on a device.
- Sync is last-writer-wins per record (no field merge, no conflict UI). Documents, the question bank and
  practice sessions are server-only: starting/opening a session needs a connection; only answers queue offline.
- The old `/api/v1/concepts` REST API is a separate server store (deprecated); the app syncs concepts via `/sync`.
- Only one verified exam format exists (SSC CHSL 2026 Tier-I, from the official notice). **SSC CGL has
  none** — add only after verifying the current official notice (record source in a migration).
- Figures are found only from PDF vector/image objects: scanned papers (one image per page), multi-column
  and rotated pages give no crops (flagged `figures_not_extracted`; reviewer uses the source page).
  Topic rules suggested 83/100 on one sample CHSL paper (coverage, not validated accuracy).
- Repeats are counted only from the learner's own imported + reviewed papers (no bundled papers); pattern
  list is a starter set (41/100 sample questions got a pattern); similarity is wording-only.
  Radar shows nothing until 2 opted-in learners review the same shift (confirmed date + shift).
- Segmenter limits: passages without a stated question range aren't detected; table-style answer keys
  aren't parsed; bilingual papers keep only the first language's options (rest in issue detail).
  Issue details are English (labels are localised).
- Rate limits are shared via Postgres only when `PREPLOOP_RATE_LIMIT_BACKEND=postgres` (required in staging/prod);
  metrics are per process; PDFs live on a shared volume (no S3 adapter yet); no malware scanning.
- Hindi OCR quality depends on scan quality; low-confidence pages are flagged, never corrected.
- Mock tests need enough *verified* questions per section (CHSL: 25 × 4); with only a few reviewed papers
  the hub shows the shortfall. No mock for SSC CGL (no verified format). Mocks never use AI questions (by design).
- AI: no real provider call made yet (needs a key); answer/Hindi quality, latency and cost unmeasured.
  AI rate limit is per process. Review Anthropic's data-retention terms before production use.
- Practice has no analytics UI beyond the session summary (Phase 8); no resume-list of unfinished sessions
  other than history.
- Reminder notifications are implemented but **never run on a device** (no Android SDK / macOS): delivery,
  permission dialogs, boot receiver, desugaring and the Gradle build are unverified. Web/desktop: unsupported
  (UI says so). A timezone change while the app stays closed keeps the old zone until the next open.
- The web preview pane can't open Drift, so revision/sync can't be tried there. Secure storage and sync
  between two real devices are unverified (no devices).
- Analytics/plan need the server for practice data; offline they show device revision only (UI says so).
  Weak-topic thresholds (10 answers, 60 %, 5 reviews, 40 % forgotten) are product choices, not validated research.
- No typed Dart API client generated yet (hand-written DTO parsing per feature). CI branch protection must be
  enabled by the repo owner.
- Hindi strings were written without native-speaker review.
- Starlette 1.7 warns that `httpx` for TestClient is deprecated in favour of `httpx2`; deferred until vetted.
- Locally PostgreSQL is a native install; docker-compose exists for a full stack where Docker is available.

## Post-release backlog (not scheduled)
- Verify on devices (docs/release.md §3): notifications, secure storage, PDF picker, Hindi, offline sync, R8.
- S3-compatible `DocumentStorage`; malware scanning if originals become downloadable.
- Device/session list with remote sign-out; field-level sync merge or conflict UI.
- Verified SSC CGL exam format (from the current official notice, source recorded).
- Native-speaker review of Hindi strings; typed Dart API client from `contracts/openapi`.
- Opt-in server error reporting (documented in the privacy policy before enabling).
