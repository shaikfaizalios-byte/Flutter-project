# Deployment (Phase 11)

Status: **designed and containerised, not yet deployed anywhere.** Docker isn't installed on the development
machine, so the image and the compose file are built and validated by CI (`container` job), not locally.

## Components

| Component | What runs | Notes |
|---|---|---|
| API | `preploop-api` image: `uvicorn app.main:app` | Stateless; scale horizontally. `PREPLOOP_DOCUMENT_WORKER_IN_PROCESS=false` |
| Worker | Same image: `python -m app.workers.document_worker` | PDF parsing and OCR (PDFium, Tesseract), isolated from the API with CPU and memory limits. Safe to run several (lease + `SKIP LOCKED`) |
| Migrations | Same image: `alembic upgrade head` | A **release step** before new API or worker versions start. Never `create_all`. |
| PostgreSQL 17 | Managed (AWS RDS / Cloud SQL / Azure / Neon…) | Automated daily backups plus point-in-time recovery; TLS; private network only |
| PDF storage | `DocumentStorage` | Today `LocalDocumentStorage` on a persistent volume **shared by the API and worker** (e.g. EFS/Filestore/Azure Files). An object-storage adapter (S3-compatible) can implement the same 4-method interface; it isn't written yet. |
| Email | Any SMTP provider (`PREPLOOP_SMTP_*`) | Required in staging and production (the settings refuse to start otherwise) |
| Edge | Load balancer / reverse proxy with TLS | HTTPS only (HSTS), HTTP→HTTPS redirect, request size limit ≥ upload limit, security headers (below) |

## Image

`services/api/Dockerfile`:
- `python:3.12.10-slim-bookworm` (pinned).
- Tesseract with eng + hin data from Debian.
- Runtime dependencies only, from `requirements.runtime.lock.txt` (`pip install --no-deps`, so the set is exact).
- The non-root user `10001`. Only `/app/var` is writable; compose also runs the container `read_only` with `no-new-privileges`.
- `HEALTHCHECK` on `/api/v1/health`.

**Runtime lock**: regenerate it after changing dependencies:

```powershell
cd services\api
python -m venv $env:TEMP\rt; & $env:TEMP\rt\Scripts\python.exe -m pip install -c requirements.lock.txt .
& $env:TEMP\rt\Scripts\python.exe -m pip freeze --exclude-editable | Select-String -NotMatch '^preploop' > requirements.runtime.lock.txt
```

(Add the two comment lines back at the top. Windows-only packages don't appear for these dependencies; check the diff.)

Pin base images by digest (`image@sha256:…`) in the production registry once you start pushing images.

## Local full stack

```powershell
copy infra\compose.env.example infra\compose.env   # set PREPLOOP_AUTH_SECRET
docker compose -f infra/docker-compose.yml up --build
```

This starts PostgreSQL, migrations, the API on :8000, the worker and **Mailpit**. Mailpit catches reset and verification emails, with
a UI on :8025. Local SMTP is unencrypted (`PREPLOOP_SMTP_SECURITY=none`), which staging and production refuse.

## Small server with docker compose (chosen set-up)

One Ubuntu 24.04 server (2 vCPU / 4 GB RAM is comfortable for OCR) runs everything from
`infra/production/`: Caddy (HTTPS from Let's Encrypt, security headers) → API, the document worker,
PostgreSQL and the shared PDF volume. Only ports 22, 80 and 443 are open.

1. **Create the server** at a provider of your choice (Ubuntu 24.04, your SSH key). Note its IP.
2. **Name**: without a domain use `<ip-with-dashes>.sslip.io` (e.g. `203-0-113-10.sslip.io`), a free
   wildcard DNS name that points at the IP. With a domain, add an `A` record (e.g. `api.example.com`).
3. **Email**: create SMTP credentials at an email provider. Production refuses to start without SMTP
   over TLS, because password reset and verification codes must reach people.
4. **Set up** (as root on the server):
   ```bash
   curl -fsSL https://raw.githubusercontent.com/shaikfaizalios-byte/Flutter-project/main/infra/production/setup-server.sh -o setup.sh
   bash setup.sh
   cp /opt/preploop/infra/production/.env.example /opt/preploop/infra/production/.env
   nano /opt/preploop/infra/production/.env      # API_DOMAIN, secrets, SMTP, CORS origin
   bash /opt/preploop/infra/production/deploy.sh
   ```
   `deploy.sh` pulls, builds, runs migrations (the API and worker wait for them), restarts and waits for
   `/api/v1/health/ready`. Run it again for every update.
5. **Web app**: set `API_BASE_URL` in `.github/workflows/pages.yml` to `https://<API_DOMAIN>` and push; the
   web app is then published at `https://shaikfaizalios-byte.github.io/Flutter-project/app/`. The API's
   `PREPLOOP_CORS_ORIGINS` must contain `https://shaikfaizalios-byte.github.io`.
6. **First account**: register your own account first. The first account claims any data without an owner.
7. **Backups**: `setup-server.sh` installs a nightly job (`/usr/local/bin/preploop-backup`, 14 days, in
   `/var/backups/preploop`). Copy that folder off the server as well (provider snapshots or object storage);
   a backup on the same disk does not survive losing the server. Test a restore:
   `docker compose ... exec -T db pg_restore -U preploop -d preploop --clean < db-<stamp>.dump`.

Updates: OS security updates install automatically (unattended-upgrades); reboot when the kernel asks.

## Production configuration

Secrets come from the platform's secret store, never from files in the image:

| Variable | Value |
|---|---|
| `PREPLOOP_ENVIRONMENT` | `production` (disables `/docs` and the OpenAPI endpoint; enforces the rules below) |
| `PREPLOOP_DATABASE_URL` | Managed Postgres URL (TLS, e.g. `?sslmode=require`) |
| `PREPLOOP_AUTH_SECRET` | 32+ random characters (**required**). Rotating it signs everyone out of their access tokens; refresh tokens keep working. |
| `PREPLOOP_RATE_LIMIT_BACKEND` | `postgres` (**required**: limits shared by all instances) |
| `PREPLOOP_EMAIL_BACKEND`, `PREPLOOP_SMTP_HOST`, `_PORT`, `_USERNAME`, `_PASSWORD`, `_FROM`, `_SECURITY` | SMTP with `starttls` or `ssl` (**required**; `none` is refused) |
| `PREPLOOP_CORS_ORIGINS` | Explicit origins only (wildcards and regexes are refused) |
| `PREPLOOP_UPLOAD_DIR` | The shared persistent volume |
| `PREPLOOP_METRICS_TOKEN` | Optional; enables `/api/v1/metrics` for your Prometheus scraper |
| `PREPLOOP_AI_API_KEY` | Optional; enables AI assistance (review the provider's data terms first) |
| `FORWARDED_ALLOW_IPS` | The proxy's address, so client IPs (rate limits, logs) are taken from `X-Forwarded-For` only when the proxy sets it |

**Security headers** (set at the edge):
- `Strict-Transport-Security: max-age=31536000; includeSubDomains`
- `X-Content-Type-Options: nosniff`
- `Referrer-Policy: no-referrer`
- `Content-Security-Policy: default-src 'none'; frame-ancestors 'none'` (API responses only; JSON)

**Probes:**
- liveness: `GET /api/v1/health`
- readiness: `GET /api/v1/health/ready` (checks the database; 503 when it's unreachable)

## Release procedure

1. CI is green on `main`. That covers lint, types, tests on Postgres, the migration drift check, OpenAPI drift, the mobile tests, the Android build and the image build.
2. Build and push the image, tagged with the git SHA.
3. Run `alembic upgrade head` as a one-off task with the new image. Migrations are additive or backward-compatible, so old API instances keep working.
4. Roll out the API and worker. Readiness gates traffic.
5. Smoke-test: health/ready, sign in, upload a sample paper, check the worker processes it.
6. Rollback: redeploy the previous image. Only downgrade migrations if a migration itself is at fault (`alembic downgrade -1`, tested in CI on every run).

## Backups and data retention

- Postgres: automated backups (≥ 7 days) and point-in-time recovery; restore drills each quarter.
- PDF volume: daily snapshots with the same retention.
- Account deletion removes rows and files immediately. Backups age out within the retention window, as the privacy policy says.

## Observability (no personal data)

- **Logs:** JSON lines with the request ID, method, path (never the query string), status and duration. There are no tokens, passwords, codes, document text or notes in logs.
- **Metrics:** `/api/v1/metrics` exposes per-process request counts and durations by route (ids replaced) and status class.
- **Error reporting:** not installed. If a service such as Sentry is added, it is **opt-in, server-side first**, with personal data scrubbing and no request bodies, and it must be documented in the privacy policy before it's enabled. The mobile app sends no telemetry.
