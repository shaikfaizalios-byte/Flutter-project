# API

Base path: `/api/v1`. The contract is in [`contracts/openapi/openapi.json`](../contracts/openapi/openapi.json)
(regenerate with `scripts/export-openapi.ps1`). Interactive docs are at `/docs`, except in production.

## Conventions

- JSON only. Every response has an `X-Request-ID` header. A caller may send its own ID (`[A-Za-z0-9._-]{1,64}`).
- Errors:

```json
{ "error": { "code": "validation_error", "message": "The request is invalid.",
             "request_id": "…", "details": [{ "field": "query.count", "message": "…" }] } }
```

  `code` is a stable snake_case value: `not_found`, `method_not_allowed`, `validation_error` or `internal_error`.

## Endpoints

| Method | Path | Description |
|---|---|---|
| GET | `/health` | Root liveness (for load balancers) |
| GET | `/api/v1/health` | Liveness: `{"status":"ok","service","version","environment"}` |

Readiness (`/api/v1/health/ready`, with dependency checks) is added in Phase 2 with the database.
