# API

Base path: `/api/v1`. The contract is in [`contracts/openapi/openapi.json`](../contracts/openapi/openapi.json).
Regenerate it with `scripts/export-openapi.ps1` after every API change. Interactive docs are at `/docs`, except in production.

> **No authentication yet (until Phase 10).** All data is single-tenant. Do not deploy this API publicly before accounts and ownership checks exist.

## Conventions

- JSON only. Every response has an `X-Request-ID` header. A caller may send its own ID (`[A-Za-z0-9._-]{1,64}`).
- Errors:

```json
{ "error": { "code": "validation_error", "message": "The request is invalid.",
             "request_id": "…", "details": [{ "field": "body.title", "message": "…" }] } }
```

  | Status | `code` | When |
  |---|---|---|
  | 404 | `not_found` | Unknown route or entity |
  | 405 | `method_not_allowed` | |
  | 422 | `validation_error` | Request body, query or path is invalid (`details` lists the fields) |
  | 422 | `invalid_reference` | References an unknown or inactive entity, e.g. `exam_code` |
  | 503 | `service_unavailable` | Database not configured |
  | 503 | `database_unavailable` | Database unreachable |
  | 500 | `internal_error` | Unexpected; details are only in server logs |

- Unknown request fields are rejected (`extra="forbid"`).
- Timestamps are ISO-8601 with a timezone. IDs are UUIDs.

## Health

| Method | Path | Description |
|---|---|---|
| GET | `/health` | Root liveness, for load balancers |
| GET | `/api/v1/health` | Liveness: `{"status":"ok","service","version","environment"}` |
| GET | `/api/v1/health/ready` | Readiness: `200 {"status":"ready","checks":{"database":"ok"}}`, or `503` with `database` set to `unavailable` or `not_configured` |

## Exams

| Method | Path | Description |
|---|---|---|
| GET | `/api/v1/exams` | Active exams, `[{"code","name"}]` |

## Concepts

| Method | Path | Description |
|---|---|---|
| GET | `/api/v1/concepts` | Search and list (see the query parameters below) → `ConceptPage` |
| POST | `/api/v1/concepts` | Create → `201 ConceptRead` |
| GET | `/api/v1/concepts/{id}` | Fetch one |
| PATCH | `/api/v1/concepts/{id}` | Partial update. Only the fields sent are changed. `subtopic` and `source_reference` can be cleared with `null`; required fields cannot be null. |
| POST | `/api/v1/concepts/{id}/archive` | Archive. Repeat calls keep the first timestamp. |
| POST | `/api/v1/concepts/{id}/unarchive` | Restore |
| DELETE | `/api/v1/concepts/{id}` | Permanent delete → `204`. Use only on an explicit user request. |

**List query parameters:**

| Parameter | Behaviour |
|---|---|
| `q` | Case-insensitive substring over title, notes, topic and subtopic. `%` and `_` are matched literally. |
| `exam`, `language` | Exact match |
| `subject`, `topic` | Case-insensitive exact match |
| `tag` | Exact match; tags are stored lower-cased |
| `include_archived` | Default `false` |
| `limit` | 1–100, default 20 |
| `offset` | 0–100000 |

Results are ordered by `updated_at desc, id`. The response is
`{"items": [...], "total", "limit", "offset"}`.

**Create body:**

```json
{
  "exam_code": "SSC_CGL",
  "title": "Percentage basics",
  "subject": "Quantitative Aptitude",
  "topic": "Percentage",
  "language": "en",
  "notes": "",
  "subtopic": null,
  "tags": ["formula"],
  "source_reference": null
}
```

**Limits and normalisation:**
- `title`: 1–200 characters, trimmed.
- `subject` and `topic`: 1–100 characters.
- `notes`: at most 20,000 characters.
- `tags`: at most 20, each 1–50 characters. They are lower-cased and de-duplicated.
- `subtopic` and `source_reference`: a blank value is stored as `null`.
- `language`: `en` or `hi`.

The mobile app applies the same rules locally (`ConceptRules`) so data stays consistent once sync exists.

## Documents (Phase 4)

See [document-ingestion.md](document-ingestion.md) for the processing pipeline.

| Method | Path | Description |
|---|---|---|
| POST | `/api/v1/documents` | `multipart/form-data` with `file` (PDF), `exam_code` and `language` (`en`/`hi`) → `201 DocumentRead` (`status: "queued"`). Rate-limited. |
| GET | `/api/v1/documents` | `?status=&limit=1–100&offset=` → `{"items", "total", "limit", "offset"}`, newest first |
| GET | `/api/v1/documents/{id}` | Status, `page_count`, `pages_processed` (progress), `needs_review_count`, `extraction_summary`, `error_code` |
| GET | `/api/v1/documents/{id}/pages` | `?limit&offset` → per page: `page_number`, `method` (`text`/`ocr`/`none`), `text`, `ocr_confidence`, `needs_review`, `review_reasons` |
| DELETE | `/api/v1/documents/{id}` | `204`. Permanently removes the record, its pages and the original file. |

**Upload errors** (standard envelope):

| Status | `code` | When |
|---|---|---|
| 413 | `file_too_large` | Over `PREPLOOP_MAX_UPLOAD_BYTES`. Checked against the declared length before parsing and again while streaming. |
| 415 | `unsupported_file_type` | The content is not a PDF, whatever the filename or MIME type says |
| 422 | `empty_file`, `invalid_pdf`, `encrypted_pdf`, `too_many_pages` | Structural checks |
| 422 | `invalid_reference` | Unknown or inactive `exam_code` |
| 429 | `rate_limited` | Too many uploads. A `Retry-After` header gives the seconds to wait. |

`DocumentRead` never exposes the storage location. `original_filename` is sanitised display text.

## Question bank (Phase 5)

See [question-bank.md](question-bank.md) for segmentation rules, issue codes and the review workflow.

| Method | Path | Description |
|---|---|---|
| GET | `/api/v1/questions` | Filters: `q` (stem text, LIKE-escaped), `exam`, `section`, `subject`, `topic_id`, `language`, `document_id`, `status` (unverified/verified/rejected), `has_issues`, `image_dependent`, `origin` (source/ai), `limit`, `offset` |
| GET | `/api/v1/questions/{id}` | Full question: options, answer and its source (`answer_key`/`inline`/`manual`), explanation, passage, topic and `topic_status`, provenance (`document_id`, `document_filename`, `source_pages`, `source_question_number`), `origin`, issues |
| PATCH | `/api/v1/questions/{id}` | Review edits: `stem`, `options` (2–6 `{label, text}`), `correct_option_position` (null clears), `explanation`, `section`, `subject`, `topic_id` (null clears), `image_dependent`, `verification_status`. Approving while content issues are open → `422 cannot_verify`. |
| GET | `/api/v1/topics` | Taxonomy (`?subject=`) |
| GET | `/api/v1/exam-formats` | Verified formats (`?exam=`), each with its official source (title, URL, reference, dates) |
| GET | `/api/v1/documents/{id}/parse-summary` | Segmentation status, counts (found, verified, rejected, with open issues, missing answers, image-dependent), sections, linked format, document-level issues |
| POST | `/api/v1/documents/{id}/segment` | Re-run segmentation, keeping verified and rejected questions. `409 document_not_ready` until extraction has completed. |
| PUT | `/api/v1/documents/{id}/exam-format` | `{"exam_format_code": "SSC_CHSL_2026_TIER1" \| null}`. The format must belong to the document's exam. |

`POST /api/v1/documents` also accepts an optional `exam_format_code` form field. `DocumentRead` now
includes `exam_format_id`, `segmentation_status` and `questions_found`.

## Practice and mock tests (Phase 6)

See [practice.md](practice.md) for selection rules, the timer, idempotency, scoring and the offline queue.

| Method | Path | Description |
|---|---|---|
| POST | `/api/v1/practice/sessions` | Untimed practice: `{exam_code?, subject?, section?, topic_id?, include_unverified=false, count=10 (1–100)}` → `201 SessionRead`. `422 no_questions_available` if nothing eligible matches. |
| GET | `/api/v1/practice/mock-tests` | Verified formats (`?exam=`) with `available`, duration, negative marks and per-section `needed`/`available` |
| POST | `/api/v1/practice/mock-tests` | `{exam_format_code}` → `201 SessionRead` with `deadline_at`. `422 not_enough_questions` (message names the short sections); `422 invalid_reference` for an unknown format. |
| GET | `/api/v1/practice/sessions` | History, newest first (`limit`, `offset`): mode, status, format, counts, score |
| GET | `/api/v1/practice/sessions/{id}` | Items (question, options, source label, selection, feedback when allowed), `server_now`, `deadline_at`, result when submitted. Auto-submits an expired mock first. |
| PUT | `/api/v1/practice/sessions/{id}/answers/{position}` | `{selected_position: 1–6 \| null, client_seq ≥ 0, time_spent_ms?}` → `AnswerAck {position, selected_position, applied, feedback}`. Older `client_seq` → `applied: false`. Practice answers are final. `409 session_closed` after submission or expiry; `422 invalid_answer` for a bad position/option. |
| POST | `/api/v1/practice/sessions/{id}/submit` | Idempotent. Returns the scored session (totals, sections, topics, explanation, marking note). |
| PUT / DELETE | `/api/v1/questions/{id}/bookmark` | Add or remove a bookmark (`204`, idempotent) |
| GET | `/api/v1/questions/{id}/history` | Attempts, correct count, last result and when |
| GET | `/api/v1/practice/bookmarks` | Bookmarked questions (`QuestionList`) |
| GET | `/api/v1/practice/incorrect` | Questions whose latest answer was wrong (`QuestionList`) |

All timestamps are UTC (the database session timezone is forced to UTC).

## Analytics (Phase 8)

See [analytics.md](analytics.md) for what counts and how judgements are made.

| Method | Path | Description |
|---|---|---|
| GET | `/api/v1/analytics/overview` | `timezone` (IANA, **required**), `days` (1–365, default 30), `recent_days` (1–90, default 14). Returns raw counts: `answered`, `correct`, `sessions`; `subjects[]` and `topics[]` with `answered`, `correct`, `recent_answered`, `recent_correct`; `daily[]` (local dates); and `mocks[]` (last 20 submitted: format, local date, score, max score, marking note, submit reason). `422 invalid_timezone` for an unknown zone. |

`GET /api/v1/practice/mock-tests` items now include `exam_code`.

## AI assistance (Phase 9)

See [ai.md](ai.md). AI is off unless the server has `PREPLOOP_AI_API_KEY`. Calls that reach the provider are rate-limited (`429 rate_limited` + `Retry-After`).

| Method | Path | Description |
|---|---|---|
| GET | `/api/v1/ai/status` | `enabled`, `provider`, `model`, `features` (no secrets) |
| POST | `/api/v1/ai/questions/{id}/explanation` | `201 AIExplanationRead` (`status: draft`, provider, model, prompt version, `model_confident`). Only for a verified source question without an explanation: `422 not_eligible`, `409 explanation_exists` |
| PATCH | `/api/v1/ai/explanations/{id}` | `{status: approved\|rejected, text?}`. Approved explanations appear in practice feedback with `explanation_origin: "ai"` |
| POST | `/api/v1/ai/questions/generate` | `{exam_code, language: en\|hi, count: 1–5, source_question_id \| concept: {title, notes, subject, topic}}` → `201 {created: QuestionRead[], rejected, rejection_reasons}`. Created questions are `origin: ai` and unverified |
| POST | `/api/v1/ai/questions/{id}/topic-suggestion` | `{question, suggested}`. The topic comes from the existing taxonomy only. `409 topic_already_set` |
| POST | `/api/v1/questions/{id}/report` | `{reason: wrong_answer\|unclear\|incorrect_content\|other, note ≤ 300}` → the question with an open `learner_report` issue. A verified question becomes unverified |

AI errors: `503 ai_disabled`, `502 ai_unavailable` (retryable). `QuestionRead` gains `topic_suggested_by`, `ai`
(provenance for AI questions) and `ai_explanation` (the latest non-rejected draft). `PracticeCreate` gains `include_ai`
(default false; mocks never use AI questions). Practice `Feedback` gains `explanation_origin` (`source`/`ai`).

## Accounts and sync (Phase 10)

See [accounts-sync.md](accounts-sync.md). Every learner route needs `Authorization: Bearer <access_token>`.
Without it, or with an expired, forged or unknown token, the response is `401 unauthorized` with `WWW-Authenticate: Bearer`.
Another account's records answer `404`. Public routes: `/health`, `/ready`, `/exams` and `/auth/register|login|refresh|logout`.

| Method | Path | Description |
|---|---|---|
| POST | `/api/v1/auth/register` | `{email, password (10–128), display_name?}` → `201 TokenPair` (`access_token`, `refresh_token`, `expires_in`, `user`). `409 email_taken`. The first account claims data created before accounts. |
| POST | `/api/v1/auth/login` | `{email, password}` → `TokenPair`. `401 invalid_credentials` (same for an unknown email); `429 rate_limited` |
| POST | `/api/v1/auth/refresh` | `{refresh_token}` → new `TokenPair` (rotation). Reusing a rotated token → `401` and the whole session family is revoked |
| POST | `/api/v1/auth/logout` | `{refresh_token}` → `204`; revokes this device's session family |
| GET | `/api/v1/auth/me` | The signed-in account |
| GET | `/api/v1/auth/me/export` | `{exported_at, user, data: {concepts, documents, questions, question_options, practice_sessions, session_answers, ai_generations, sync_items}}` |
| POST | `/api/v1/auth/me/delete` | `{password}` → `204`; deletes the account, all owned data and the stored PDFs. `401 invalid_credentials` |
| POST | `/api/v1/sync/push` | `{changes: [{entity, id, deleted?, data?}]}` (max 500). Entities: `concept`, `study_profile` (id `profile`), `revision_card`, `card_review`, `setting` (id `revision_day_offsets`). → `{accepted, ignored_deleted: ["entity:id"], rejected: {"entity:id": reason}}` |
| GET | `/api/v1/sync/pull` | `?cursor=<int>&limit=<1–500>` → `{changes: [{entity, id, deleted, data, seq, updated_at}], cursor, has_more}` |

The `/api/v1/concepts` routes are **deprecated**. They are a separate server-side store; the app syncs concepts through `/sync`.
