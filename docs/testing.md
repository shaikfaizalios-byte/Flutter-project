# Testing

Run everything with `.\scripts\check.ps1`.

## Backend (`services/api/tests`, pytest)

| File | Covers |
|---|---|
| `test_health.py` | `/health` and `/api/v1/health`; generating, echoing and sanitising request IDs |
| `test_errors.py` | 404, 405, 422 and 500 envelopes; no internal detail leaks |
| `test_config_and_cors.py` | Env parsing, production safety checks, docs disabled in production, CORS allow and deny |

Tests build the app through `create_app(Settings(_env_file=None, ...))`, so a local `.env` has no effect on them.

## Mobile (`apps/mobile/test`, flutter_test)

| File | Covers |
|---|---|
| `core/config/app_config_test.dart` | Build config validation (https enforced outside development) |
| `core/errors/app_failure_test.dart` | Mapping Dio errors to `AppFailure`, reading the backend error envelope |
| `app/app_shell_test.dart` | Dashboard questions, 5-tab navigation, rail on wide screens, accessibility guidelines (tap targets, labels, contrast) |
| `features/settings/settings_screen_test.dart` | Server online, offline and retry states; switching to Hindi; following the device locale; dark theme |

Widget tests override `serverStatusRepositoryProvider` with a fake, so they never touch the network.

## Not yet covered

- Integration tests (`integration_test/`) need a device or emulator. They start in Phase 3 with onboarding.
- Android and iOS builds have not been verified (no Android SDK; iOS needs macOS).
