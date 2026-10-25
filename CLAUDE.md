# CLAUDE.md — PrepLoop project guidance

Persistent guidance for Claude Code sessions. Keep it current when phases, commands or decisions change.

## Product scope
PrepLoop is a personalised exam-preparation app for **any multiple-choice exam** (English and Hindi), with
**SSC CGL and SSC CHSL** featured. Learners pick exams from a server-managed catalog (names only) or create their
own, and give each exam its own subjects/topics (optionally drafted by AI from their papers).
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
  bundled Noto Sans Devanagari fallback. Drift/SQLite (`core/database`, schema v7)
  is the offline-first local store; repositories in `features/*/data`. Phase 2 is local-only — no sync.
- **Backend:** modular monolith. FastAPI + Pydantic v2 + pydantic-settings; routing → service → repository.
  SQLAlchemy 2 (sync, psycopg 3) + Alembic + PostgreSQL 17. Services own the transaction (commit per
  operation); domain errors (`app/domain/errors.py`) map to HTTP in `app/core/errors.py`. Versioned `/api/v1`.
- Exams are reference data, never code branches: `exams` = catalog (owner NULL; name, short_name, category,
  featured; migrations 0012/0014) + learners' private exams (`MY_...`, owner set). Topics have `owner_id` (NULL =
  shared) and `exam_codes` (NULL = every exam); ONE visibility rule (`app/services/topic_service.py`
  `topic_scope`/`visible_topics`) is used by parsing (exam subjects = extra section headings), suggestions,
  review, AI, uploads, notes. `/me/exams`, `/exams/{code}/topics`, `/topics` (+bulk), `/patterns`; optional
  `POST /ai/exams/{code}/topic-draft` (never saved). Mobile: `examCatalogProvider` (server list cached in
  `app_settings`, built-in SSC fallback), `features/exams` (selector + "More exams" search, My exams, topics).
- Current exam (mobile, `features/exams/application/active_exam.dart`): `activeExamProvider` = the learner's
  choice (device setting `active_exam` in `app_settings`, erased on sign-out) while it is one of
  `studyProfile.examCodes`, else the first. Imported papers, question bank, practice (requests carry
  `exam_code`), mock tests, history (plus older exam-less sessions), bookmarks, questions to revisit and repeats
  show only that exam; uploads default to it. `ExamSwitcher` sits in those app bars and the desktop sidebar.
  Concepts keep their own exam filter. Analytics follow it too (`/analytics/overview?exam=`, counted by each
  question's exam; mocks by session exam).
- Syllabus + revision marks: `POST /exams/{code}/syllabus` (PDF read in the request: text layer or OCR via
  `app.state.ocr_engine`, ≤ 40 pages, temp file deleted, NOTHING saved) → pure `app/domain/syllabus.py` draft
  (headings by ":"/CAPS/Part-Section label/known subject words; bullets, numbers, comma runs, one per line) →
  learner unticks and saves via `/topics/bulk` (≤ 300). `topic_completions` (migration 0020) + `PUT
  /topics/{id}/completion`; `OwnTopicRead.completed`. Mobile: topics screen syllabus card (highlighted while
  the learner has no own topics), "x of y revised" + a checkbox per topic; Imported papers asks "Add the
  syllabus first?" before the first paper of an exam (skip remembered per exam: `syllabus_skipped:<code>`).
  No PDF: `POST /exams/{code}/syllabus/text` (typed/pasted, ≤ 20 000 chars, same parser, `read_by="typed"`).
  Each saved syllabus is a `syllabus_imports` row (migration 0021; name = PDF file name or "Typed syllabus",
  kind pdf|typed; `/topics/bulk` with `source`; `topics.syllabus_import_id`): the topics screen shows one
  section per import; `GET /exams/{code}/syllabus-imports`, `DELETE /syllabus-imports/{id}` removes it and its
  topics. Removing single topics: `POST /topics/bulk-delete` (own only; questions go back to no topic) and the
  "Select" mode.
- Question search (`question_service._text_conditions`): every word (stop words dropped, simple plural
  stem) must appear somewhere in the stem, an option, the passage, the topic or the pattern name. Mobile
  `PaperQuestionsCard` (`features/question_bank/presentation/paper_questions_card.dart`) shows the current
  exam's matching paper questions under the Study search (≥ 2 chars, 350 ms debounce) and on each concept
  page (searched by its title); "See all" opens the question bank with that text. "Search on Google" (no
  match) / "Learn more on Google" (matches; question screen app bar, searched by the stem) open
  `googleSearchUri` in the browser via `linkOpenerProvider` (`core/utils/external_links.dart`,
  url_launcher; overridden in tests). Only on tap; the privacy policy says the text goes to Google.
  No match + AI on: `QuickAnswerPanel` (before the Google button) → `POST /ai/quick-answer` (pure
  `quick_answer_prompt`/`validate_quick_answer`, own system prompt, NOTHING stored, `ai_generations` task
  `quick_answer`, migration 0022). Off until the learner taps "Ask AI" once (`quick_answers_on` device
  setting); then asked after the search stays still ~1 s (`quickAnswerSettle`); labelled "AI-generated · not
  checked"; the Study card is capped at 45 % of the screen height and scrolls.
  RAG (docs/rag-guide.md): `SearchAnswerPanel` at the top of the card → `POST /ai/search-answer`: `RagRetriever`
  (`app/services/rag_service.py`, PostgreSQL `to_tsvector('simple')`/`ts_rank_cd`, OR-prefix tsquery) over
  own pages + visible source questions + synced concepts of one exam, scoped by owner BEFORE ranking; pure
  `app/domain/rag.py` (terms, snippets, S1..Sn prompt, `validate_rag`: unknown [S#] → reject). No sources →
  found=false, no AI call. Not found → general `QuickAnswerPanel`. Task `rag_answer` (migration 0024).
- PrepLoop Plus (docs/plus.md): `subscriptions` (migration 0023, one row per account, source
  test|operator|play|web, `active_until`); `GET /me/plus` (status + AI requests used this UTC month from
  `ai_generations` ok/partial vs `PREPLOOP_PLUS_AI_MONTHLY_ALLOWANCE`, default 300); free test subscriptions
  only with `PREPLOOP_PLUS_TEST_MODE` (refused in staging/prod): `POST/DELETE /me/plus/test`; operator grants
  `python -m app.cli.plus grant|revoke|show EMAIL`. Mobile `features/plus` (Profile card, `/profile/plus`,
  sidebar shortcut). NOT built yet: AI gating by Plus, payments (Play Billing / web / Apple), legal texts.
- Suggestions (`suggestions`, migration 0019): `POST/GET /suggestions` (add/remove/change/other, 10-2000
  chars, 10/day/account); operator reads/marks with `python -m app.cli.suggestions list|mark`. Mobile
  "Suggest a feature" (Profile card, sidebar, Home shortcuts) shows each suggestion's status.
- Documents: upload → validate (magic bytes, PDFium) → `DocumentStorage` → DB-backed queue → worker
  (`app/workers/document_worker.py`, lease + SKIP LOCKED) → per-page text layer or Tesseract OCR
  (`OcrEngine`), uncertain pages flagged. pypdfium2, not PyMuPDF (AGPL). See docs/document-ingestion.md.
- Reading any paper with AI (docs/ai.md "Read a paper"): learner taps "Read with AI" on the review screen (`AiReadCard`,
  polls the parse summary) → `POST /ai/documents/{id}/read` queues `documents.ai_read_status`; the worker
  (`AiPaperReader`, also in `run_once`) sends 3 page images + text per request (`AIProvider.complete_json(images=)`),
  pure `app/domain/ai_reading.py` validates and compares each question with its page text (mismatch / scan →
  review issues `ai_text_mismatch`/`ai_read_unchecked`); `questions.extracted_by` rules|ai (migration 0025).
- Q&A notes (written questions, migration 0026): `answer_type` choice|typed|written, `questions.model_answer`
  (only written; CHECK). When the MCQ segmenter finds mostly option-less questions, the pure
  `app/domain/qa_notes.py` reads "Answer:"-labelled or numbered Q&A (page furniture dropped, two-sentence
  questions kept whole, unclear starts → `ambiguous_boundary`) and `SegmentationService._save_written` stores
  them; the AI reader returns `written_answer` too. Written questions never enter practice/mocks (eligibility
  needs options or a typed answer); the review screen's `WrittenFlashcardsCard` turns verified ones into revision
  cards (back = written answer). Bulk "verify clean" skips open `REVIEW_FIRST_CODES` (AI mismatch/scan,
  unreadable text). RAG answers have two parts: `answer` (cited, from the material) + `simple` (AI, plain words).
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
  answer in Drift `pending_answers` (schema v3; v6 adds typed answers) and replays it. Typed-in (TITA) questions:
  `answer_type`/`typed_answer`, pure `app/domain/typed_answers.py` (numbers by value), practice only (mocks exclude
  them). Offline practice: `GET /practice/offline-pack` (verified, no figures, answers included) saved in Drift
  `offline_questions` (schema v7); without a connection practice starts from it as a local session
  (`offline_sessions`, client UUID, device marking = preview) and is uploaded via
  `POST /practice/offline-sessions` (idempotent by `client_id`, server re-marks, `submit_reason="offline"`).
  Mocks stay online. See docs/practice.md.
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
- Shared bank (`app/services/shared_bank.py`, migration 0017): the operator publishes a reviewed paper with
  `python -m app.cli.shared_bank publish <id> --rights ... --source ...` (rights basis + source required by a
  CHECK; refused while verified questions use private topics). ONE rule `visible_question()` = own questions OR
  verified source questions of shared papers; used by practice (`include_shared`, default on), mocks, question
  read (`read_only`, `shared_source`; publisher file name hidden), figures, history, repeats (`scope=mine|shared|all`).
  Edits/reports/bookmarks stay owner-only. Mobile: "Shared bank" labels, read-only question view, Repeats
  "Shared bank" view. `POST /documents/{id}/questions/verify-clean` verifies questions needing no review.
  See docs/shared-bank.md.
- Legal/privacy guards: sign-up requires `confirms_minimum_age` (Literal[True]; `MINIMUM_AGE = 18`
  in `app/schemas/auth.py`, mobile `minimumAge`), stored as `users.age_confirmed_at` (migration 0016).
  The web app loads nothing from Google: Roboto is bundled, builds use `--no-web-resources-cdn`, and
  `web/flutter_bootstrap.js` points `fontFallbackBaseUrl` at the app (missing glyphs show as boxes).
  No analytics/session replay; emails are transactional only. Keep it that way (privacy policy says so).
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
python website\build.py --out website\_site   # public website (GitHub Pages: .github/workflows/pages.yml)
# Production backend: infra/production (VPS + docker compose + Caddy); steps in docs/deployment.md
powershell -ExecutionPolicy Bypass -File scripts\tunnel.ps1   # public test tunnel to the PC API (updates deploy/public-api-url)
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
- Not deployed yet. Chosen: website + web app on GitHub Pages (`pages.yml`; the owner must enable Pages; the web
  app is built only once `API_BASE_URL` is set) and the backend on a small VPS (`infra/production`, see
  docs/deployment.md). GitHub Pages sends no COOP/COEP headers, so the web app's Drift uses its non-OPFS fallback.
  Docker image/compose and the Android build are verified only by CI (no Docker/Android SDK locally).
- Accounts: no device list or remote session revocation UI. Unverified emails can still use the app.
- Legal texts are DRAFTS with [placeholders] (operator, contact, processors, retention, law, minimum age).
- Launcher icon/splash are provisional (generated); application id `com.preploop.preploop` must be changed
  to the operator's domain before the first Play upload. R8 shrinking is off until verified on a device.
- Sync is last-writer-wins per record (no field merge, no conflict UI). Documents and the question bank are
  server-only. Practice works offline from the saved pack (questions with figures excluded; AI explanations,
  bookmarks and reports need the server); mock tests need a connection. Signing out erases unsent offline sessions.
- The old `/api/v1/concepts` REST API is a separate server store (deprecated); the app syncs concepts via `/sync`.
- Verified exam formats: SSC CHSL 2026 Tier-I (migration 0003) and SSC CGL 2026 Tier-I (migration 0018, F. No.
  HQ-C11018/1/2026-C-1 para 13.8). CGL's 15-minute sectional timers are recorded per section but mocks keep one
  overall timer (the marking note says so). **Every other catalog exam has none** — add only after verifying the
  current official notice (record source in a migration). Without a format: practice, repeats and Radar work;
  timed mocks and count checks don't.
- Question types: multiple-choice, typed-in (TITA) and written (Q&A notes, revised as flashcards; not practised
  or marked). Multi-select is not supported; timed mocks use multiple-choice only. Unnumbered Q&A questions are
  numbered in order by PrepLoop.
  Catalog exams other than SSC/banking/railways start with no shared topics (learners add their own or use
  the AI draft). Own exams/topics never join the Radar.
- Figures are found only from PDF vector/image objects: scanned papers (one image per page), multi-column
  and rotated pages give no crops (flagged `figures_not_extracted`; reviewer uses the source page).
  Topic rules suggested 83/100 on one sample CHSL paper (coverage, not validated accuracy).
- Repeats count the learner's own papers, or the shared bank (empty until the operator publishes papers it has
  the right to share); the app flags samples under 5 papers (`RepeatRules.reliablePapers`). Pattern list is a
  starter set (41/100 sample questions got a pattern); similarity is wording-only. Shared questions can't be
  bookmarked; deleting the operator account would empty the shared bank (use a dedicated account).
  Radar shows nothing until 2 opted-in learners review the same shift (confirmed date + shift).
- Segmenter limits: passages without a stated question range aren't detected (unless a "Question" line
  follows them, as in solutions papers); answer keys are read as
  `1-(3)` pairs or tables (number rows + answer rows, one cell per line, "1 | b"); a table row whose counts
  differ is reported (`answer_key_unmatched`), never shifted; keys numbered per section stay ambiguous;
  bilingual papers keep only the first language's options (rest in issue detail).
  Issue details are English (labels are localised).
- Rate limits are shared via Postgres only when `PREPLOOP_RATE_LIMIT_BACKEND=postgres` (required in staging/prod);
  metrics are per process; PDFs live on a shared volume (no S3 adapter yet); no malware scanning.
- Hindi OCR quality depends on scan quality; low-confidence pages are flagged, never corrected.
- Mock tests need enough *verified* questions per section (CHSL: 25 × 4); with only a few reviewed papers
  the hub shows the shortfall (the shared bank counts toward it). Mocks never use AI questions (by design).
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
