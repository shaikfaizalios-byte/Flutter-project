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

### Schema (revision `0002`): documents

**`documents`**: one row per uploaded PDF. It has an `exam_code` foreign key (RESTRICT) and `language` (CHECK `en`/`hi`).
- `original_filename` is sanitised display text. `storage_key` is internal and unique (`documents/<uuid>.pdf`).
- `size_bytes`, `sha256` (indexed) and `page_count` are recorded at upload.
- `status` is one of queued, processing, completed or failed (CHECK). `pages_processed` and `needs_review_count` track progress.
- `extraction_summary` is text, ocr, mixed or none. `error_code` is set when processing fails.
- Worker bookkeeping: `attempts`, `lease_expires_at`, `processing_started_at` and `processing_finished_at`.
- Index `(status, created_at)` supports claiming the next document.

**`document_pages`**: primary key `(document_id, page_number)`. `page_number` is 1-based, the same as in the source PDF. It has a foreign key with
`ON DELETE CASCADE`.
- `method` is text, ocr or none (CHECK).
- `text` is normalised extracted text, and `char_count` its length.
- `ocr_confidence` (0–100) is set for OCR pages only.
- `needs_review` and `review_reasons` (varchar[]) record why a page needs a human look. The reason codes are listed in document-ingestion.md.

Original files are **not** stored in the database. They live in `DocumentStorage` (local disk at
`PREPLOOP_UPLOAD_DIR`). Back up both together.

### Schema (revision `0003`): question bank

- **`exam_formats`** holds only verified formats. Columns: code (unique), exam, tier, name, `sections` JSONB (part, subject, questions, max marks), `sections_in_fixed_order`, total questions, duration, negative marks, and `source_title`/`source_url`/`source_reference`/`source_published_on`/`verified_on`. It is seeded with SSC CHSL 2026 Tier-I (see question-bank.md).
- **`topics`**: subject, name and keywords (an editable taxonomy). It is seeded with a small starter set.
- **`passages`**: shared directions or reading passages per document, with the question range and source pages.
- **`questions`**:
  - `origin` is `source` or `ai` (CHECK). Source rows must have `document_id` and `source_question_number` (CHECK).
  - Exam, optional format, section, subject, `topic_id` with `topic_status` (unassigned/suggested/confirmed), stem and language.
  - `source_pages` (int[]) and `passage_id`.
  - `correct_option_position` with `answer_source`, plus `explanation` and `image_dependent`.
  - `verification_status` (unverified/verified/rejected) with `verified_at`.
  - Foreign keys: document (CASCADE); format, topic and passage (SET NULL).
- **`question_options`**: primary key (question, position); the label as printed, and the text.
- **`question_issues`**: code, detail and `resolved`. `question_id` is null for document-level issues. Cascades from both the question and the document.
- `documents` gains `exam_format_id`, `segmentation_status`, `questions_found` and `segmented_at`.

### Schema (revision `0004`): practice sessions

- **`practice_sessions`**: `mode` (practice/mock), exam, `exam_format_id` (mocks), `selection` JSONB (filters, or the format code and random seed), `status` (active/submitted), `started_at`, `deadline_at` (mocks; the timer's only source), `submitted_at`, `submit_reason` (user/time_up), `score`, `max_score`, and the `result` JSONB (total, sections, topics, explanations, marking note).
- **`session_items`**: primary key (session, position). Links to `question_id`, plus a snapshot of section, subject, topic, `correct_position`, `option_count`, `marks_correct`, `marks_wrong` and `question_verified`, so later edits to a question can't change a scored session.
- **`session_answers`**: primary key (session, position). Holds `question_id`, `selected_position` (null = cleared), `is_correct`, `client_seq` (only a larger value overwrites), `time_spent_ms` and `answered_at`.
- **`bookmarks`**: one row per question (unique), with `created_at`.
- Deleting a question (or its document) keeps past sessions and scores: `session_items.question_id` and `session_answers.question_id` become NULL, while the snapshot stays. Bookmarks cascade. Exams and formats used by sessions are `RESTRICT`.

### Schema (revision `0005`): AI assistance

- **`questions`** gains:
  - `topic_suggested_by` (`keywords`/`ai`; existing suggestions were backfilled to `keywords`)
  - `ai_provider`, `ai_model`, `ai_prompt_version`
  - `ai_source_question_id` (FK to questions, SET NULL)
  - `ai_source_note` (e.g. "Concept: <title>"; never the notes themselves)

  CHECK `ai_has_provenance`: `origin = 'ai'` requires provider, model and prompt version.
- **`ai_explanations`**: AI explanation drafts for source questions, kept apart from `questions.explanation`:
  - text and language
  - `model_confident`
  - provider, model and prompt version
  - `status` (draft/approved/rejected), `edited` and `reviewed_at`

  It cascades with the question.
- **`ai_generations`**: one row per AI call, for auditing and cost:
  - task (explanation/questions/topic) and outcome (ok/partial/invalid/error)
  - reason-code detail
  - input and output tokens
  - items created and rejected
  - the question (SET NULL)

  It never stores prompt or output text.

### Schema (revisions `0006` and `0007`): accounts, ownership and sync

- **`users`**: email (unique, CHECK lower-case), Argon2id `password_hash`, `display_name`, `created_at` and `last_login_at`.
- **`refresh_tokens`**:
  - `user_id` (CASCADE) and `family_id`
  - `token_hash` (SHA-256, unique)
  - `expires_at`, `used_at` and `revoked_at`
- **`owner_id`** (FK `users`, `ON DELETE CASCADE`, indexed) on `documents`, `questions`, `practice_sessions`, `concepts`
  and `ai_generations`. Pre-account rows stay NULL until the first account claims them.
- **`sync_items`** (0007):
  - primary key (`owner_id`, `entity`, `item_id`)
  - `data` JSONB (NULL when deleted) and the `deleted` tombstone
  - `seq` BIGINT from the `sync_seq` sequence, and `updated_at`
  - index (`owner_id`, `seq`)

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
| `app_settings` | Key/value device settings: `language`, `theme_mode`, `revision_day_offsets` (e.g. `1,4,7`), `reminders_enabled`, `reminder_scheduled_plan` (fingerprint of the scheduled reminder) |
| `study_profiles` (v2) | A single row (`id = 1`, enforced by CHECK) with the onboarding answers: `exam_codes` (JSON array), `target_exam_date` (`yyyy-MM-dd` text, so it never shifts with the timezone), `daily_study_minutes` (5–720), `reminder_minutes` (minutes after local midnight), `onboarding_completed_at`, `updated_at`. Unknown exam codes and out-of-range values are ignored when reading. |

Schema history: **v1** has concepts and app_settings. **v2** adds study_profiles (migration `from1To2`
creates the table). **v3** adds `pending_answers`, the offline answer queue for practice sessions (primary key
(session_id, position); selected option or null, `client_seq`, `time_spent_ms`, `created_at`). The migration `from2To3` creates it.
**v4** adds the flashcards (migration `from3To4`; see [revision.md](revision.md)):

- **`revision_cards`**:
  - `kind` is `concept` or `question`.
  - `concept_id` is unique, and the FK cascades on concept delete. `question_id` (the server id) is unique.
  - Question-card snapshot: `front`, `back`, `source_filename`, `source_page`, `exam_code`, `subject` and `topic`.
  - `reason` is `added` or `incorrect_answer`.
  - Schedule: `step`, `gap_days`, `due_on` (`yyyy-MM-dd`), `review_count`, `lapse_count` and `last_reviewed_at`.
- **`card_reviews`**: one row per review (`rating`, `due_before`, `due_after`, `gap_days`, `reviewed_at`). It cascades with the card.

Snapshots of every version are in `drift_schemas/`. The generated tests in `test/drift/app_database/` upgrade
every version to every later one and compare the result with the snapshot. Custom tests check that v1→v2 keeps
concepts and settings, v3→v4 keeps concepts and queued answers, and v4→v5 keeps cards and reviews and gives
reviews a sync id.

**v5** (migration `from4To5`) adds **`sync_outbox`** (primary key (`entity`, `entity_id`), `version`, `changed_at`), which lists the
records changed on the device that still need uploading. It also adds **`card_reviews.sync_id`** (a stable id across devices,
with a unique index; existing rows get random ids).

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

## Sync rules (implemented in Phase 10)

These rules were designed in Phase 2 and are now implemented; see [accounts-sync.md](accounts-sync.md) for details. The cursor
is a server sequence number rather than `updated_at` + `id`, because it is monotonic and needs no tiebreaker:

1. **Identity:** the client generates UUIDs, and the server accepts them, so no ID remapping is needed.
2. **Direction:** each device pushes its local changes, then pulls server changes made since its last sync cursor (server `updated_at` plus `id` as tiebreaker).
3. **Conflicts:** last-writer-wins per record using server-assigned `updated_at`. Archive and unarchive are ordinary field updates. Deletes become tombstones that win over concurrent edits.
4. **Ownership:** sync endpoints only ever return the authenticated user's rows.
5. **Offline:** all reads and writes go to the local database first, so the UI never waits for the network.
6. **Before enabling sync:** add `owner_id` and tombstones on the server, sync metadata (`dirty`, `server_updated_at`) on the device, and tests for each conflict case.
