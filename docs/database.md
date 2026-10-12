# Database

PrepLoop has two independent stores. They share **no schema code**: data crosses between them only
through the API schemas.

| | Server (`services/api`) | Device (`apps/mobile`) |
|---|---|---|
| Engine | PostgreSQL 17 | SQLite through Drift (native), or Drift WASM (web dev) |
| Access | SQLAlchemy 2, routing → service → repository | Repositories in `features/*/data` |
| Schema changes | Alembic (`services/api/migrations`) | Drift `schemaVersion` + `drift_schemas/` snapshots |
| Source of truth | Account-based data (once accounts exist) | The user's device until sync exists |

## Server: PostgreSQL

### Local setup (Windows, native install)

1. Install PostgreSQL 17, for example: `winget install PostgreSQL.PostgreSQL.17`. It runs as the `postgresql-x64-17` service on port 5432.
2. Create a dedicated role and two databases. Generate your own password:

   ```sql
   CREATE ROLE preploop LOGIN PASSWORD '<generated>';
   CREATE DATABASE preploop OWNER preploop ENCODING 'UTF8';
   CREATE DATABASE preploop_test OWNER preploop ENCODING 'UTF8';
   ```

3. Put the URLs in `services/api/.env` (gitignored; see `.env.example`):
   `PREPLOOP_DATABASE_URL` and `PREPLOOP_TEST_DATABASE_URL`.
4. Apply the migrations by running `.\.venv\Scripts\alembic.exe upgrade head` from `services/api`. `scripts/setup.ps1` does this too.

The `preploop` role is not a superuser. The tests drop and recreate the `public` schema of
**`preploop_test` only**. Never point `PREPLOOP_TEST_DATABASE_URL` at a database whose data you need.

Docker is not required. An `infra/docker/docker-compose.yml` can be added later if a containerised setup is preferred.

### Schema (revision `0001`)

**`exams`**: reference data. Exams are data, not code.

| Column | Type | Notes |
|---|---|---|
| code | varchar(32) PK | `SSC_CGL`, `SSC_CHSL` (seeded by the migration) |
| name | varchar(100) | Official exam name |
| is_active | bool | Inactive exams cannot receive new concepts |
| created_at | timestamptz | |

Sections, tiers and marking schemes are **not** stored yet. They will be added as separate, verified configuration and are never invented.

**`concepts`**

| Column | Type | Notes |
|---|---|---|
| id | uuid PK | |
| exam_code | FK → exams.code | `ON DELETE RESTRICT` |
| title | varchar(200) | Check: not blank |
| notes | text | Default `''`; the API caps it at 20,000 characters |
| subject, topic | varchar(100) | Free text for now; a managed taxonomy comes later |
| subtopic | varchar(100) null | |
| language | varchar(8) | Check: `en` or `hi` |
| tags | varchar(50)[] | Lower-cased and de-duplicated; GIN index |
| source_reference | varchar(500) null | e.g. book or page |
| archived_at | timestamptz null | Archive is reversible; delete is permanent and explicit |
| created_at, updated_at | timestamptz | `updated_at` is bumped on every ORM update |

Indexes: `(exam_code, archived_at)` and a GIN index on `tags`.

**Not yet:** an `owner_id` column. Accounts arrive in Phase 10, and ownership checks will be enforced in the repository layer then. Until that point the concept API is a single-tenant development API: **do not expose it publicly.**

### Migration workflow

```powershell
cd services/api
.\.venv\Scripts\alembic.exe revision --autogenerate -m "describe change"   # draft
# Review and edit the generated file. Autogenerate misses data migrations and some type changes.
.\.venv\Scripts\alembic.exe upgrade head
.\.venv\Scripts\alembic.exe check          # fails if models and migrations disagree
```

- The URL comes from `PREPLOOP_DATABASE_URL`. `alembic.ini` contains no credentials.
- Every migration must have a working `downgrade()`. The test suite runs `upgrade → downgrade → upgrade` on every run.
- Production never uses `create_all`. Tables are created only through migrations.

## Device: Drift / SQLite

Defined in `apps/mobile/lib/core/database/`.

| Table | Purpose |
|---|---|
| `concepts` | Same fields as the server table, with a client-generated UUID `id`. Tags are a JSON array; datetimes are ISO-8601 text in UTC. |
| `app_settings` | Key/value device settings (`language`, `theme_mode`) |

### Migration strategy

1. Change the tables and increment `schemaVersion` in `app_database.dart`.
2. Run `dart run drift_dev make-migrations`. This saves a snapshot in `drift_schemas/` and generates step helpers and migration tests in `test/drift/`.
3. Implement the step in `MigrationStrategy.onUpgrade`, then run the generated tests.
4. Released schema versions are never edited. Every version's snapshot stays committed.

Regenerate code after changing tables by running `dart run build_runner build`.

### Web

Drift on web needs `web/sqlite3.wasm` and `web/drift_worker.js`. Both come from the
[drift 2.35.2 release](https://github.com/simolus3/drift/releases/tag/drift-2.35.2), and their SHA-256 digests were checked against the release:

- `sqlite3.wasm`: `fbcd2e8214f9231ea961e1b7706a22dd1194cfbfe6f26f13841b5aa7a0be1a1f`
- `drift_worker.js`: `191fc9db018d2bbecb1723e81118fcf2c5c094df8644c2fcba2ed51df061e90a`

Update both files together whenever the `drift` package is upgraded.

Serve the app **cross-origin isolated** (COOP `same-origin` + COEP) so Drift can use OPFS storage. `scripts/dev-mobile.ps1` passes `--cross-origin-isolation`, and `scripts/serve_web.py` does the same for built output.

**Known limitation:** the Claude desktop app's embedded browser pane cannot fetch from web workers, so the web database never opens there. The app still renders (startup storage access times out after 3 s), but the concept list cannot load. Use Chrome or Edge to try web persistence. Android and iOS use native SQLite and are unaffected.

## Sync rules (designed; not implemented)

Phase 2 is **local-only**: concepts created on the device stay on the device, and nothing is uploaded. These rules govern the sync work in Phase 10:

1. **Identity:** the client generates UUIDs, and the server accepts them, so no ID remapping is needed.
2. **Direction:** each device pushes its local changes, then pulls server changes made since its last sync cursor (server `updated_at` plus `id` as tiebreaker).
3. **Conflicts:** last-writer-wins per record using server-assigned `updated_at`. Archive and unarchive are ordinary field updates. Deletes become tombstones that win over concurrent edits.
4. **Ownership:** sync endpoints only ever return the authenticated user's rows.
5. **Offline:** all reads and writes go to the local database first, so the UI never waits for the network.
6. **Before enabling sync:** add `owner_id` and tombstones on the server, sync metadata (`dirty`, `server_updated_at`) on the device, and tests for each conflict case.
