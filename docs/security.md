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

## Implemented (Phase 4: uploads)

- File type is checked by content (`%PDF-` magic bytes), not by extension or MIME type. Then PDFium opens the file to reject damaged, encrypted, empty and over-long PDFs before anything is stored.
- Size limit: oversized declared bodies are rejected before parsing, and the size is enforced again while streaming. Page limits and per-page OCR timeouts apply, plus a whole-document processing budget.
- Path traversal: stored files get generated names. User filenames are sanitised display text only. `LocalDocumentStorage` also refuses any key that resolves outside `documents/`.
- Uploads are rate-limited per client address (in-process sliding window, `429` with `Retry-After`).
- Tesseract runs as a subprocess with a fixed executable and argument list, no shell, a timeout and stdin input. No user-controlled strings reach the command line.
- Logs record document IDs, sizes and page counts, never document text or filenames.
- Deletion is explicit and complete: row, pages and original file.

## Known gaps (accepted for now)

- **No authentication on `/api/v1/documents`.** Anyone who can reach the API can list, read and delete uploads. Never expose it publicly before Phase 10 adds accounts and ownership checks.
- The rate limiter is per process and keyed by client IP. Behind a proxy it needs trusted forwarded-for handling, and when scaled out it needs a shared store such as Redis.
- Uploaded files are not malware-scanned. They are only ever parsed by PDFium and never served back to clients. Add scanning if originals are ever made downloadable.
- PDFium parses untrusted input in-process. A dedicated worker process (`python -m app.workers.document_worker`) limits the impact of a parser crash. Container sandboxing is planned for Phase 11.
- **No authentication or ownership on `/api/v1/concepts`.** It is single-tenant and must not be deployed publicly before Phase 10.
- The on-device database is not encrypted. It holds study notes only (no credentials). Revisit if sensitive data is ever stored locally.

## Required before the relevant phases ship

- Authentication, secure token storage (`flutter_secure_storage`), and ownership checks in services and repositories, covering concepts and documents (Phase 10).
- Rate limiting on AI endpoints (Phase 9). Upload rate limiting exists; move it to a shared store before scaling out.
- Worker process isolation (separate container, limited memory and CPU) for PDF parsing and OCR (Phase 11).
- Server-side entitlement verification for subscriptions (Phase 10).
- HTTPS termination and security headers at the deployment edge (Phase 11).
