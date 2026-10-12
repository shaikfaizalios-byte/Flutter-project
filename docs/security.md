# Security

## Implemented (Phase 1)

- No secrets in the repository. `.gitignore` covers `.env*` (except examples), keys, keystores, service-account files, DBs and uploads.
- The mobile app embeds no secrets. Non-development builds refuse a non-HTTPS `API_BASE_URL` at startup.
- Android cleartext HTTP is enabled **only** in the debug manifest, for the local dev API.
- CORS uses explicit origins. A dev-only origin regex is rejected when `PREPLOOP_ENVIRONMENT=production`. Credentials are not allowed.
- Interactive docs and the OpenAPI endpoint are disabled in production.
- Error responses never include stack traces or exception messages. Details are logged server-side with the request ID.
- The request log records method, path (no query string), status and duration.
- Incoming `X-Request-ID` values are validated before they are logged or echoed.

## Implemented (Phase 2)

- The database URL is a `SecretStr`. It is never logged or returned, and `alembic.ini` contains no credentials.
- When the database or readiness check fails, only the exception class is logged (driver messages can contain host and user names). Clients get a generic 503.
- The app connects as a non-superuser role (`preploop`) that owns only its own databases. Local passwords are randomly generated and stored only in the gitignored `services/api/.env`.
- All queries go through the SQLAlchemy ORM with bound parameters. User search text is LIKE-escaped.
- Constraints are also enforced in the database (CHECK on language and blank titles; foreign key on exam), not only in Pydantic.
- Request bodies reject unknown fields, and every length is bounded (`extra="forbid"`, explicit max lengths, max 20 tags).
- Mobile: local data stays on the device (nothing is sent to the server). Logs never include user content.

## Known gaps (accepted for now)

- **No authentication or ownership on `/api/v1/concepts`.** It is single-tenant and must not be deployed publicly before Phase 10.
- The on-device database is not encrypted. It holds study notes only (no credentials). Revisit if sensitive data is ever stored locally.

## Required before the relevant phases ship

- Upload validation by content (magic bytes), plus size, page and time limits, and path-traversal-safe storage (Phase 4).
- Authentication, secure token storage (`flutter_secure_storage`), and ownership checks in services and repositories (Phase 10).
- Rate limiting on expensive endpoints (upload, OCR, AI) (Phases 4 and 9).
- Server-side entitlement verification for subscriptions (Phase 10).
- HTTPS termination and security headers at the deployment edge (Phase 11).
