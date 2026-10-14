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

## Implemented (Phase 7: reminders)

- Notification permission is requested only when the learner turns on the daily reminder, never at start-up. Declining is respected.
- Reminder text is generic. No card content, counts or personal data appear on the lock screen.
- Android uses inexact alarms, so the app requests no `SCHEDULE_EXACT_ALARM`/`USE_EXACT_ALARM` permission. The only added permission is `RECEIVE_BOOT_COMPLETED` (restores the reminder after a reboot). Notification receivers are not exported.

## Implemented (Phase 9: AI)

- The provider key (`PREPLOOP_AI_API_KEY`) is a `SecretStr` that lives only in the server's gitignored `.env`. It is never returned (`/ai/status` exposes only enabled, provider and model) and never logged. The app embeds no AI key.
- Only the minimum is sent to the provider: one verified question and its answer, or the concept the learner chose (they are told first). No account or device data is sent.
- The AI audit log (`ai_generations`) stores reason codes and token counts, never prompt or output text. Learner notes are not stored on the server.
- Model output is untrusted. It is schema-constrained, validated before storage, stored unverified or as a draft, and labelled everywhere. Topic suggestions are limited to the existing taxonomy.
- Calls that reach the provider are rate-limited (default 30 per hour per client) and limited in size (max 5 questions, notes ≤ 4000 characters, output tokens capped). Provider timeouts and errors map to `502 ai_unavailable` without details.

## Implemented (Phase 10: accounts and ownership)

- **Passwords:**
  - Argon2id hashes, re-hashed when parameters change.
  - 10–128 characters, and not equal to the email.
  - The same error and similar timing for unknown emails (dummy hash).
  - Sign-in and registration are rate-limited per client and email.
- **Access tokens** are 15-minute HS256 JWTs. They check issuer, audience, type and expiry. `PREPLOOP_AUTH_SECRET` (32+ characters) is required in staging and production.
- **Refresh tokens** are opaque, stored only as SHA-256, and rotate on every use. Reusing a rotated token revokes the whole family. Logout revokes it too.
- **Phone storage:** the session lives in the platform keystore (`flutter_secure_storage`). Signing out or switching account erases the previous learner's data from the device. Signing out warns about unsynced changes first.
- **Ownership** is enforced in every service as well as at the router. Another account's data looks exactly like a missing record (404). Tests cover each route family, including AI and sync.
- **Rate limits:** uploads and AI calls are limited per account.
- **Privacy:** account deletion removes every owned row by cascade, plus the stored PDF files. The export returns everything the server holds for the account (no password hash).
- **Sync records** are validated per entity with the app's limits, and rejected one by one. Pushes are serialised per account.

## Known gaps (accepted for now)

- The rate limiter is per process and keyed by client IP. Behind a proxy it needs trusted forwarded-for handling, and when scaled out it needs a shared store such as Redis.
- Uploaded files are not malware-scanned. They are only ever parsed by PDFium and never served back to clients. Add scanning if originals are ever made downloadable.
- PDFium parses untrusted input in-process. A dedicated worker process (`python -m app.workers.document_worker`) limits the impact of a parser crash. Container sandboxing is planned for Phase 11.
- No password reset or email verification yet (needs an email provider). Accounts can't be recovered if the password is lost.
- No list of signed-in devices or remote session revocation in the app (logout and reuse detection revoke sessions).
- The on-device database is not encrypted. It holds study notes only (no credentials). Revisit if sensitive data is ever stored locally.

## Required before the relevant phases ship

- Password reset and email verification through an email provider (before public release).
- Upload and AI rate limiting exist per process; move them to a shared store before scaling out. Review the AI provider's data-retention terms before enabling AI in production.
- Worker process isolation (separate container, limited memory and CPU) for PDF parsing and OCR (Phase 11).
- Server-side entitlement verification for subscriptions (Phase 10).
- HTTPS termination and security headers at the deployment edge (Phase 11).
