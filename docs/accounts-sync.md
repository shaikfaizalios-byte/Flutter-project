# Accounts, ownership and sync (Phase 10)

Code:
- Backend:
  - `app/core/security.py`, `app/services/auth_service.py`, `app/api/deps.py`, `app/api/v1/endpoints/auth.py`
  - `app/services/sync_service.py`, `app/api/v1/endpoints/sync.py`
- Mobile:
  - `lib/features/auth/`, `lib/core/network/auth_interceptor.dart`
  - `lib/features/sync/`, `lib/core/database/sync_outbox.dart`

## Accounts

| Item | Choice |
|---|---|
| Sign-in | Email + password, hosted by our own server (no third-party identity service). Emails are stored trimmed and lower-case (unique). |
| Passwords | 10–128 characters with no composition rules (NIST SP 800-63B), and not equal to the email. Hashed with **Argon2id** (`argon2-cffi`, MIT) and re-hashed on login if the parameters change. Unknown emails are checked against a dummy hash, so timing and error text are the same ("Email or password is not correct"). |
| Access token | HS256 JWT (`PyJWT`, MIT) signed with `PREPLOOP_AUTH_SECRET`. Lifetime `PREPLOOP_ACCESS_TOKEN_MINUTES` (15). Checks issuer, audience, `type=access` and `exp`. |
| Refresh token | 48 random bytes, opaque. Only its **SHA-256** is stored. Lifetime `PREPLOOP_REFRESH_TOKEN_DAYS` (30). **Rotates on every use.** Using a token that was already rotated (theft or replay) revokes its whole family (all of that device's sessions). Logout revokes the family. |
| Secret | Required (32+ characters) in staging and production; the settings refuse to start without it. In development a random secret is generated per process, so sign-ins end on restart. |
| Brute force | `PREPLOOP_AUTH_RATE_LIMIT` attempts per `PREPLOOP_AUTH_RATE_WINDOW_SECONDS` (default 10 per 15 min) per client address + email, for sign-in and registration |
| Phone storage | `flutter_secure_storage` (BSD-3): Android Keystore / iOS Keychain. The session is loaded before the first frame. |
| Expiry | The app adds the access token to every request (`AuthInterceptor`). On a 401 it refreshes **once**, with concurrent requests sharing one refresh, and retries. If the refresh is refused, the app returns to sign-in and says the session ended. Offline refresh failures keep the session. |

Endpoints:
- `/api/v1/auth/register`, `/login`, `/refresh`, `/logout`
- `/me` (the account)
- `/me/export` (everything the server holds for the account)
- `/me/delete` (password required). This deletes every owned row by cascade **and the stored PDF files**.

## Ownership

- **Required sign-in.** Every learner route (`/concepts`, `/documents`, `/questions`, `/practice`, `/analytics`, `/ai`, `/sync`)
  requires a signed-in account at the router level.
- **Owner checks in services.** Every service also takes the account id and scopes **every** query (defence in depth).
  Another account's record behaves exactly like a missing one (404), so ids don't leak existence.
- **Owned tables** (`owner_id`, FK `ON DELETE CASCADE`):
  - documents
  - questions (source questions inherit the document's owner; AI questions belong to the requester)
  - practice sessions
  - concepts
  - AI usage log
  - sync items

  Session items and answers, bookmarks and AI explanations belong to their session or question.
- **Shared reference data:** exams, exam formats and topics.
- **Rate limits:** uploads and AI calls are rate-limited **per account**.
- **Pre-account data:** rows created before accounts existed have `owner_id` NULL and are invisible. **The first account to
  register claims them** (the single-tenant to multi-user migration).

## Sync (device data)

Synced entities:
- concepts
- the study profile
- revision cards
- card reviews
- the revision-ladder setting

Device preferences (language, theme, reminder switch) stay per device. Documents, questions and practice already live on the server.

**Server** (`sync_items`, Alembic 0007):
- **Storage:** one row per (account, entity, client id) with the latest JSON, a `deleted` tombstone flag and `seq` from the
  `sync_seq` sequence. Each entity has a strict schema with the same limits as the app; invalid records are rejected **one by one**, with a reason.
- **Push:** applies changes in order. **Last writer wins** (each accepted change gets a new `seq`). **Deleted records stay
  deleted** (later edits are ignored and reported back). Replays are harmless. Pushes for one account are serialised
  with an advisory lock, so `seq` order equals commit order and a cursor can't skip a change.
- **Pull:** `?cursor=<seq>` returns the account's changes after the cursor, oldest first, in pages of 500.

**Device** (Drift schema v5):
- **Outbox:** every local write also marks the record in `sync_outbox` (entity, id, `version`), in the same transaction.
  Repeated edits coalesce. Deleting a concept also marks its cascaded revision card.
- **Push:** uploads each outbox record's **current** state (or a deletion if it's gone). An outbox row is cleared only if
  its `version` didn't change meanwhile, so an edit made during an upload is kept for the next sync. Rejected records are dropped and
  logged (never retried forever). Records the server kept deleted are deleted locally too.
- **Pull:** fetches every page after the stored cursor, keeps the newest version of each record, and **skips records with a
  pending local change** (the local change wins and is pushed next). It applies everything in one transaction, parents
  before children, with foreign keys checked at commit. Pulled data is never marked dirty.
- **When:** after sign-in, on app start and resume, 3 s after local changes, and from *Profile → Sync now*. The app works
  fully offline; sync catches up later. Profile shows pending changes, the last sync and offline or error states.

**Account changes on a device:**
- *First account on a device* (or after sign-out): existing local data is adopted and uploaded (`markAllDirty`).
- *Different account than last time*: the previous learner's data is **erased first**, so nothing leaks between accounts.
- *Sign out*: syncs first. If changes are still pending (offline), the app warns how many will be lost. Then it erases
  the learner's data from the device and revokes the session.
- *Expired session*: the data stays on the device, because the same learner signs in again.

## Not covered yet

- No password reset or email verification (that needs an email provider; planned for release).
- No multi-device conflict UI: last writer wins per record, silently. Field-level merging isn't implemented.
- No list of signed-in devices in the app. Revoking a single session happens only through logout or token reuse detection.
- Rate limits are per process (shared store needed before scaling out).
- The older `/api/v1/concepts` REST API is a separate server-side store kept for API clients (marked deprecated). The
  app syncs concepts through `/sync`.
