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

## Required before the relevant phases ship

- Upload validation by content (magic bytes), plus size, page and time limits, and path-traversal-safe storage (Phase 4).
- Authentication, secure token storage (`flutter_secure_storage`), and ownership checks in services and repositories (Phase 10).
- Rate limiting on expensive endpoints (upload, OCR, AI) (Phases 4 and 9).
- Server-side entitlement verification for subscriptions (Phase 10).
- HTTPS termination and security headers at the deployment edge (Phase 11).
