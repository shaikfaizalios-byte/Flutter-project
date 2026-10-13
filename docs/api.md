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
