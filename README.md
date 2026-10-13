# PrepLoop — Personalized Exam Preparation

PrepLoop helps SSC CGL and SSC CHSL aspirants turn scattered PDFs, previous-year papers and notes into a
personalised study loop: practise, find weak topics, revise on schedule, and track real progress.

> **Status:** Phase 4 (document ingestion). Onboarding, a dashboard built on real data and offline concept
> management work in English and Hindi. PDFs (previous-year papers or notes) can be imported. The
> server validates them, extracts text page by page (embedded text, or Tesseract OCR for scans) and
> flags pages it cannot read reliably. Question parsing arrives in Phase 5. See [CLAUDE.md](CLAUDE.md)
> and [docs/document-ingestion.md](docs/document-ingestion.md).

## Repository layout

| Path | Contents |
|---|---|
| [`apps/mobile`](apps/mobile) | Flutter app (Android, iOS, web for development) |
| [`services/api`](services/api) | FastAPI backend (Python 3.12) |
| [`contracts/openapi`](contracts/openapi) | Exported OpenAPI schema |
| [`docs`](docs) | Architecture, API, security and testing docs |
| [`scripts`](scripts) | PowerShell helpers for setup, running and checks |

## Prerequisites

- Git
- Python **3.12**
- Flutter **3.47.x stable** (Dart 3.13)
- For Android: Android Studio + Android SDK (`flutter doctor --android-licenses`)
- For iOS: macOS with Xcode (cannot be built on Windows)
- Tesseract 5 with English and Hindi data for OCR (optional; see docs/document-ingestion.md)
- PostgreSQL 17 for the backend database. See [docs/database.md](docs/database.md) for the role and database setup.

Check with `flutter doctor` and `python --version`.

## Setup (Windows PowerShell, from the repo root)

```powershell
.\scripts\setup.ps1
```

This creates `services/api/.venv`, installs the pinned backend dependencies from
`requirements.lock.txt`, copies `services/api/.env.example` to `.env`, and runs `flutter pub get` and
`flutter gen-l10n`.

## Run

Start the backend:

```powershell
.\scripts\dev-api.ps1
```

- Liveness: <http://127.0.0.1:8000/health> and <http://127.0.0.1:8000/api/v1/health>
- Interactive docs (non-production only): <http://127.0.0.1:8000/docs>

Start the mobile app in a second terminal:

```powershell
.\scripts\dev-mobile.ps1                          # Chrome
.\scripts\dev-mobile.ps1 -Device emulator-5554    # Android emulator → API at http://10.0.2.2:8000
```

On a physical phone, pass your PC's LAN address: `-Device <id> -ApiBaseUrl http://192.168.x.x:8000`.
Also start the API with `--host 0.0.0.0` and allow it through the firewall.

In VS Code, use the **Run and Debug** configurations, including the compound **PrepLoop: API + Mobile (Chrome)**.

## Configuration

| Where | Variable | Purpose |
|---|---|---|
| `services/api/.env` | `PREPLOOP_ENVIRONMENT` | `development` / `test` / `staging` / `production` |
| | `PREPLOOP_CORS_ORIGINS` | Comma-separated exact origins |
| | `PREPLOOP_CORS_ORIGIN_REGEX` | Dev-only regex; rejected in production |
| | `PREPLOOP_LOG_LEVEL` | `INFO` by default |
| `--dart-define` | `API_BASE_URL` | Backend base URL (https is required unless `FLAVOR=development`) |
| | `FLAVOR` | `development` / `staging` / `production` |
| | `APP_NAME` | Display name override |

The application ID `com.preploop.preploop` is a placeholder. Change it before the first store upload.

## Quality checks

```powershell
.\scripts\check.ps1
```

This runs ruff (format + lint), mypy (strict), pytest, `dart format`, `flutter analyze` and `flutter test`.

## API contract

After changing endpoints, run `.\scripts\export-openapi.ps1` and commit `contracts/openapi/openapi.json`.

## Database migrations

From `services/api`:

```powershell
.\.venv\Scripts\alembic.exe upgrade head     # apply all migrations
.\.venv\Scripts\alembic.exe check            # verify models and migrations match
```

The database URL comes from `PREPLOOP_DATABASE_URL` in `services/api/.env`. For creating migrations and
for the mobile (Drift) schema workflow, see [docs/database.md](docs/database.md).

## Build

- Web (development check): `cd apps/mobile; flutter build web --dart-define=API_BASE_URL=...`
- Android App Bundle: `flutter build appbundle --dart-define=FLAVOR=production --dart-define=API_BASE_URL=https://...`
  This needs the Android SDK and release signing, which are configured in Phase 11.
- iOS: requires macOS + Xcode (Phase 11).

## Known limitations

See the "Current phase" section of [CLAUDE.md](CLAUDE.md).
