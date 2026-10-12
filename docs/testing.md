# Testing

Run everything with `.\scripts\check.ps1`.

## Backend (`services/api/tests`, pytest)

| File | Covers |
|---|---|
| `test_health.py` | `/health` and `/api/v1/health`; generating, echoing and sanitising request IDs |
| `test_readiness.py` | `/health/ready` when the database is reachable (200), unreachable (503) or not configured (503); database endpoints return the 503 envelope; credentials never leak |
| `test_errors.py` | 404, 405, 422 and 500 envelopes; no internal detail leaks |
| `test_config_and_cors.py` | Env parsing, production safety checks, docs disabled in production, CORS allow and deny |
| `test_concepts_api.py` | Concept CRUD, archive and unarchive, delete, validation (blank, too long, bad language, extra fields, too many tags), unknown exam, 404 and malformed ID, filters, Hindi search, literal LIKE wildcards, pagination bounds |
| `test_concept_repository.py` | Server defaults, archived filtering, tag array matching, database CHECK and foreign-key constraints |
| `test_concept_service.py` | Archive idempotency, exam validation on create and update, inactive exams, `updated_at`, not-found paths |

**The database tests use real PostgreSQL** (`PREPLOOP_TEST_DATABASE_URL`, read from `services/api/.env`):

- Once per run, the `public` schema of the test database is dropped. The migrations then run `upgrade → downgrade → upgrade`, which also tests that they are reversible.
- Each test runs inside a transaction that is rolled back afterwards. Service commits become savepoints (`join_transaction_mode="create_savepoint"`).
- If the URL is not set, the database tests are **skipped**, not failed.

Apps are built with `create_app(Settings(_env_file=None, ...), engine=...)`, so a developer's `.env` doesn't affect the tests.

## Mobile (`apps/mobile/test`, flutter_test)

| File | Covers |
|---|---|
| `core/config/app_config_test.dart` | Build config validation (https enforced outside development) |
| `core/errors/app_failure_test.dart` | Mapping Dio errors to `AppFailure`, reading the backend error envelope |
| `app/app_shell_test.dart` | Dashboard questions, 5-tab navigation, rail on wide screens, accessibility guidelines (tap targets, labels, contrast) |
| `features/settings/settings_screen_test.dart` | Server online, offline and retry states; switching to Hindi; following the device locale; dark theme |
| `features/settings/preferences_persistence_test.dart` | Preferences defaults, round-trip, upsert, unknown values, survival across a "restart" (new provider container, same database) |
| `features/concepts/local_concepts_repository_test.dart` | Normalisation, validation without writing, ordering, search (including Hindi and literal wildcards), archive and undo, stream re-emission |
| `features/concepts/concept_flow_test.dart` | Empty state, create flow (form is full screen, data stored), required-field validation, search with no results, archive and undo, Hindi UI |

Tests use an in-memory Drift database (`NativeDatabase.memory()`) and a fake server-status repository, so they never touch the network.

Widget tests that pump the whole app must use **`testAppWidgets`** (`test/helpers/pump_app.dart`), not `testWidgets`. The wrapper creates the database, flushes Drift's stream-cancel timer before teardown, and closes the database outside fake async. Without it, tests fail with "A Timer is still pending" or hang. Seed data with `seed(tester, ...)`, which runs real I/O outside fake async.

## Not yet covered

- Integration tests (`integration_test/`) need a device or emulator. They start in Phase 3 with onboarding.
- Android and iOS builds have not been verified (no Android SDK; iOS needs macOS).
- Web persistence has not been verified in a real browser yet (see the limitation in docs/database.md).
- Drift migration tests are generated once schema version 2 exists.
