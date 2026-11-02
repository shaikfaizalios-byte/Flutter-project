# Global Phase 1 — Release safety: acceptance report

Scope from [audit-and-roadmap.md](audit-and-roadmap.md) §5 "Phase 1". Branch
`claude/global-product-716ab9`, 1 Nov 2026. Four vertical slices, one commit each.

| Slice | Commit | Migration |
|---|---|---|
| Mocks never fill a missing format fact with a default | `d1f274a` | — |
| Account export covers every learner table (guard test) | `670af35` | — |
| Signed-in devices and remote sign-out | `c06893f` | `0029_device_sessions` |
| AI prompts keep paper text as data; exam-neutral system prompt | `99f9a8f` | — |

## 1. Exam-format integrity

- **What changed:** pure `app/domain/exam_format.py` `format_problems()`; `PracticeService`
  lists problems in `MockAvailability.format_problems` (`available: false`) and refuses to start
  with `422 format_incomplete`. The `negative_marks_per_wrong or 0.0` and "1 mark a question"
  defaults are gone. App: "missing official details" line, Start disabled (EN + HI).
- **API:** additive field `format_problems: string[]` (older apps ignore it; the app treats a
  missing field as complete).
- **Tests:** `tests/test_exam_format.py` (rules, both seeded formats complete, incomplete format
  listed and refused); `practice_flow_test.dart` (parsing, card state).
- **Not changed:** the two verified formats (CGL, CHSL) are complete, so learners see no change.

## 2. Complete data export and deletion

- **What changed:** `app/services/account_data.py` lists every table as owned, child (linked
  only through the account's own parents) or not exported (with a reason). The export adds own
  exams, topics, patterns, syllabus imports, revised topics, page text, passages, issues, figure
  metadata (no image bytes), AI explanations, bookmarks and session items.
- **Tests:** `tests/test_account_data.py`: every table classified once; every owned/child link is
  `ON DELETE CASCADE`; a fully filled account exports one row per table, no other account's rows
  (including a shared-bank owner never receiving other learners' answers), and deletion removes
  exactly the account's rows.
- **Limits:** the PDFs themselves and figure images are not in the JSON export; nightly backups
  keep deleted data up to 14 days (stated in `docs/security.md`; the privacy policy must say so).

## 3. Signed-in devices and remote sign-out

- **Data:** migration `0029` adds `refresh_tokens.platform` (CHECK: android, ios, web, windows,
  macos, linux). No device name/model is collected. Reversible (downgrade drops the column).
- **Backend:** access tokens carry `sid` (the family); `get_current_user` refuses a token whose
  family is revoked, so sign-out, remote sign-out, password reset and token reuse end access at
  once (one indexed lookup per request on `ix_refresh_tokens_family`). Old tokens without `sid`
  keep working until they expire (≤ 15 min). Endpoints: `GET /auth/sessions`,
  `DELETE /auth/sessions/{id}` (other accounts → 404), `POST /auth/sessions/sign-out-others`.
- **App:** login/registration send the platform; Profile → "Signed-in devices" (list, sign out
  one, sign out all others; a 401 refreshes once and retries). EN + HI strings.
- **Tests:** `tests/test_device_sessions.py` (7), `test/features/auth/devices_test.dart` (5).

## 4. AI untrusted-input boundary

- **What changed:** `app/domain/untrusted.py` (`material()`, `UNTRUSTED_RULE`); every prompt
  builder wraps paper/notes/search/source text; every system prompt ends with the rule; the
  general system prompt no longer names SSC; notes-based question generation names the learner's
  exam. `PROMPT_VERSION` → `p10` (stored with new AI items; old items keep `p9.5`).
- **Tests:** `tests/test_prompt_injection.py` (every builder, tag neutralising, an obeyed
  injection still rejected by `validate_rag`); existing AI tests updated to the wrapped wording.
- **Limits:** this reduces, not removes, prompt-injection risk. No real provider call has been
  made yet (no key), so model behaviour against injected papers is unmeasured.

## Verification run

- Backend: ruff, mypy (strict, 172 files), full pytest on PostgreSQL 17 (migrations up → down →
  up including 0029) — all passing; `alembic check` clean against the test database.
- Mobile: `flutter analyze` clean; `flutter test` 404 passing (includes ARB parity).
- OpenAPI exported (`contracts/openapi/openapi.json`).

## Not tested / remaining risks

- Real devices: platform reporting and the devices screen were exercised only in widget tests.
- Sync conflicts, payments and legal texts are later phases (roadmap Phases 3–4; counsel).
- `get_current_user` now does one extra query per authenticated request; fine at current scale,
  revisit with a short cache if request volume grows.

## How to verify by hand

1. `.\scripts\check.ps1`
2. Run the API and app; sign in on two browsers; Profile → Signed-in devices on one; sign the
   other out; the other's next request returns to sign-in at once.
3. `GET /api/v1/auth/me/export` on a learner with papers: every table above is present.
