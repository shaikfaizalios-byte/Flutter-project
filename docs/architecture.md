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
- Phase 4+: background worker (queue chosen then) for OCR and parsing; object-storage interface.
- Phase 9: `AIProvider` interface with a mock implementation for tests.
- Typed Dart client generated from `contracts/openapi/openapi.json` when the app first calls the concepts API (sync, Phase 10). Until then the app only calls `/health`.
