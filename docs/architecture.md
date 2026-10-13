# Architecture

## Overview

```
┌──────────────────────────┐   HTTPS / JSON (OpenAPI contract)   ┌──────────────────────────────┐
│ apps/mobile (Flutter)    │ ──────────────────────────────────▶ │ services/api (FastAPI)       │
│ presentation ─ Riverpod  │                                      │ api/v1 routers               │
│ application  (use cases) │                                      │ services (business logic)    │
│ domain       (entities)  │                                      │ repositories (SQLAlchemy)    │
│ data  ─ Dio / Drift      │                                      │ PostgreSQL · workers · AI    │
└──────────────────────────┘                                      └──────────────────────────────┘
```

PrepLoop is a **modular monolith** with an **offline-capable mobile client**. Both halves live in one
monorepo but have independent dependency management, tooling and tests.

## Decisions

| # | Decision | Rationale |
|---|---|---|
| ADR-1 | Monorepo with `apps/mobile` and `services/api`, strictly separated | One place for the contract and docs; no accidental code sharing |
| ADR-2 | Modular monolith backend, workers only for OCR/AI/long jobs | Lowest operational cost; split later if load demands |
| ADR-3 | Feature-first Clean Architecture on mobile; layers created only when needed | Keeps features isolated without empty abstractions |
| ADR-4 | Riverpod 3 for state and DI; providers overridden in tests | Compile-safe DI and easy fakes (see `test/helpers/pump_app.dart`) |
| ADR-5 | GoRouter `StatefulShellRoute.indexedStack` with 5 tabs | Each tab keeps its own navigation stack and state |
| ADR-6 | Navigation rail at ≥ 840 dp, bottom bar below | Material 3 adaptive guidance; tablets and web |
| ADR-7 | Flutter gen-l10n with ARB files in `lib/core/localization/arb` | Official tooling; generated code committed for analyzer stability |
| ADR-8 | Single error envelope `{"error": {...}}` plus a sealed `AppFailure` on mobile | Predictable handling; no stack traces leak |
| ADR-9 | Build-time config through `--dart-define`; runtime config through `PREPLOOP_*` env vars | No secrets in the app; 12-factor backend |
| ADR-10 | pip + venv + `requirements.lock.txt` (pinned) with ranges in `pyproject.toml` | No extra tooling needed; reproducible installs; can migrate to uv later |
| ADR-11 | Web target kept for development verification only | Lets UI be checked on Windows without the Android SDK; not a product target |
| ADR-12 | Synchronous SQLAlchemy 2 with psycopg 3; FastAPI runs sync endpoints in its threadpool | Simpler code and tests; low concurrency needs; async can be adopted per endpoint later |
| ADR-13 | Services own transactions (one commit per operation); repositories only query and flush | Clear unit-of-work boundary; repositories can be reused inside larger operations |
| ADR-14 | Native PostgreSQL install for local development instead of Docker | Fits 8 GB RAM; Docker stays optional |
| ADR-15 | Offline-first mobile: Drift is the source of truth on the device; client-generated UUIDs; no sync until Phase 10 | Works without a network; IDs never need remapping; sync rules designed first (docs/database.md) |
| ADR-16 | Preferences in a Drift key/value table, loaded before the first frame (3 s timeout) | One storage engine, no flash of the wrong language or theme, never a blank app if storage hangs |
| ADR-17 | Validation limits duplicated on purpose: Pydantic on the server, `ConceptRules` on mobile | The device validates offline; the server re-validates everything it receives |
| ADR-18 | The onboarding gate is a GoRouter redirect driven by a `ValueNotifier` bridged from Riverpod (`refreshListenable`); the rule is a pure function | Redirects re-run when onboarding completes without rebuilding the router; the rule is unit-testable |
| ADR-19 | Onboarding answers are saved as each one is made (no "submit" at the end) | Leaving halfway never loses choices; Skip only marks completion |
| ADR-20 | Exam dates are `CalendarDate` (no time or timezone), and "now" comes from `clockProvider` | Countdowns can't drift across timezones or DST; date logic is testable with a fixed clock |
| ADR-21 | Noto Sans Devanagari is bundled and set as `fontFamilyFallback` | Hindi renders offline and identically everywhere; no runtime font CDN |
| ADR-22 | Concept filter choices come from the learner's own data (facets) | No invented taxonomy; a managed taxonomy can replace this later |
| ADR-23 | pypdfium2 (Apache-2.0/BSD) instead of PyMuPDF (AGPL-3.0) | Avoids copyleft obligations for a network service; has the text-layer and rendering features needed |
| ADR-24 | A database-backed job queue (status, lease, `SKIP LOCKED`) instead of Celery or Redis | No extra infrastructure; survives restarts; several workers can run safely; can move to a broker later |
| ADR-25 | Tesseract via the CLI (stdin → TSV) behind an `OcrEngine` protocol | No wrapper dependency; per-word confidence; tests use a fake engine |
| ADR-26 | Per-page commits; text stored exactly as extracted; uncertain pages flagged with reason codes | Bounded memory, visible progress, honest data for Phase 5 parsing and review |
| ADR-27 | Documents are server-side only; the mobile app reads them over the API and does not cache them yet | OCR needs the server; offline caching of results arrives with sync |
| ADR-28 | Deterministic, rule-based segmenter (a pure module) instead of ML/LLM parsing | Predictable, testable and explainable; every uncertainty becomes a reviewable issue; AI assistance can be layered on later |
| ADR-29 | Exam formats stored as data, only after verification against an official notice (source recorded) | Never invents patterns; formats change per notice; count checks are skipped for unknown formats |
| ADR-30 | Section counts are matched by name, never by position | The SSC notice lists Tier-I parts "not in sequence" |
| ADR-31 | Re-segmentation preserves verified and rejected questions | Human review decisions are never overwritten by a parser re-run |
| ADR-32 | Topic keywords only *suggest*; confirmation needs a human | Avoids false certainty in categorisation |
| ADR-33 | Practice and mock state lives on the server; the mock timer is derived from the server's `deadline_at`, and expiry auto-submits lazily on the next request | Closing the app, reinstalling or changing the device clock can't reset the timer; no scheduler is needed |
| ADR-34 | Answers carry a client sequence number; the server keeps the highest. Submit is idempotent | Offline replays, retries and out-of-order delivery are harmless |
| ADR-35 | Offline answer queue in Drift (`pending_answers`), replayed oldest-first; non-network errors drop the entry | Answers survive connectivity loss without endless retries; starting and opening sessions stay online-only (simple, honest) |
| ADR-36 | Scoring is a pure module using `Decimal`; each session item snapshots its marks and correct answer | Exact marks (e.g. 2.00, −0.50); unit-testable; later edits to a question can't change a past score |
| ADR-37 | Practice answers are final, with immediate feedback; mock answers can change, with no feedback until submission | Mirrors learning (feedback) vs exam (no feedback) conditions; keeps practice accuracy honest |
| ADR-38 | Revision is on the device (Drift v4), with no server tables until sync | Works offline; Phase 10 sync rules cover it like concepts |
| ADR-39 | The revision ladder is a stored setting of "days after adding" (default 1/4/7), with a pure scheduler and documented adaptation rules (Good / Easy / Hard / Forgot) instead of an opaque SM-2 ease factor | The learner can predict and change it; unit-testable; the review log keeps the data needed for a smarter model later |
| ADR-40 | Concept cards read the live concept; question cards snapshot the question | Edits to the learner's own notes show up; question cards work offline and can't change under the learner |
| ADR-41 | One daily reminder with a fixed notification id, re-created only when its fingerprint (time, timezone, wording) changes | Duplicate-free by construction across restarts, resumes and setting changes |
| ADR-42 | Inexact Android alarms; permission asked only when the learner turns reminders on | No exact-alarm permission (Play policy) for a study nudge; a permission prompt in context is accepted more often and is respectful |
| ADR-43 | The server returns raw answer counts; accuracy, thresholds and "weak" are decided on the device by named rules | One place for the rules, and they are shown to the learner; server and device data (flashcards) combine without double logic; no invented ratios |
| ADR-44 | Days are bucketed in the learner's IANA timezone, which the client passes explicitly and PostgreSQL applies | Correct "today" and daily charts across midnight and travel; testable at the boundary |
| ADR-45 | The daily plan is a pure, rule-based function with a reason for every item (no AI) | Predictable and explainable; easy to test; AI suggestions can be added later, labelled |
| ADR-46 | Charts are plain Flutter widgets, not a chart package | Simple needs; no licence or size cost; accessible summaries |

## Mobile layout (`apps/mobile/lib`)

```
main.dart → bootstrap.dart         config + ProviderScope
app/        app.dart, router.dart, app_shell.dart, theme/
core/       config/ network/ errors/ localization/ widgets/
features/   dashboard/ study/ practice/ analytics/ settings/   (more added per phase)
```

## Backend layout (`services/api/app`)

```
main.py            create_app(settings) factory: middleware, handlers, routers
core/              config, logging (JSON), middleware (request ID), errors
api/v1/            router + endpoints/
schemas/           Pydantic request/response models
(services/, repositories/, models/, database/, workers/, integrations/ arrive with their phases)
```

## Planned evolution

- Phase 2 (done): SQLAlchemy and Alembic with PostgreSQL; Drift for the local store; a readiness probe.
- Phase 3 (done): onboarding, a dashboard built on real data, concept details, editing and filters, a bundled Hindi font, and Drift schema v2.
- Phase 4 (done): document upload, validation and storage; per-page text and OCR extraction worker; mobile import screen.
- Phase 5 (done): question segmentation, question bank, verified exam formats, review workflow, question browser.
- Phase 6 (done): practice sessions, timed mock tests from verified formats, scoring with explanations, offline answer queue, bookmarks, incorrect-answer review and history.
- Phase 7 (done): flashcards from concepts and verified questions, a configurable Day 1/4/7 revision ladder with adaptive follow-up, due counts on the dashboard, and a daily reminder notification.
- Phase 8 (done): analytics endpoint (timezone-aware raw counts), weak-topic rules combining practice and flashcard recall, the Progress screen, and a deterministic daily study plan.
- Phase 4+: background worker (queue chosen then) for OCR and parsing; object-storage interface.
- Phase 9: `AIProvider` interface with a mock implementation for tests.
- Typed Dart client generated from `contracts/openapi/openapi.json` when the app first calls the concepts API (sync, Phase 10). Until then the app only calls `/health`.
