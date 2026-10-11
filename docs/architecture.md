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

- Phase 2: SQLAlchemy and Alembic with PostgreSQL; Drift for the local store; a readiness probe.
- Phase 4+: background worker (queue chosen then) for OCR and parsing; object-storage interface.
- Phase 9: `AIProvider` interface with a mock implementation for tests.
- Typed Dart client generated from `contracts/openapi/openapi.json` once there are enough endpoints to justify it (Phase 2).
