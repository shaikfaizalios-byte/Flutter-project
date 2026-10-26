# PrepLoop Plus

A subscription for the AI features. Studying stays free: importing papers, the question bank,
practice, mock tests, revision, reminders and progress never need Plus.

## Status (built)

- `subscriptions` (migration 0023): one row per account — `plan` (`plus`), `source`
  (`test` | `operator` | `play` | `web`), `active_until`, optional `note`. Deleted with the
  account, included in the account export. Active means `active_until > now`.
- `GET /api/v1/me/plus` → `active`, `source`, `active_until`, `ai_used_this_month`,
  `ai_monthly_allowance` (`PREPLOOP_PLUS_AI_MONTHLY_ALLOWANCE`, default 300), `period_resets_at`
  (next calendar month, UTC), `test_mode`, `purchases_available` (false: no store yet).
- AI use is counted from `ai_generations` (outcome `ok`/`partial`, this calendar month, UTC);
  failed requests don't count. No text is stored, as for every AI call.
- Test mode (`PREPLOOP_PLUS_TEST_MODE=true`, development only — staging/production settings
  refuse it): `POST /api/v1/me/plus/test {days: 1-31}` starts a free test subscription,
  `DELETE /api/v1/me/plus/test` ends it. A test never replaces an operator or store subscription.
- Operator grants (e.g. beta testers):
  `python -m app.cli.plus grant EMAIL --days 30 --note "beta"`, `revoke EMAIL`, `show EMAIL`.
  Store purchases are never changed by the CLI.
- **Gating** (`PREPLOOP_PLUS_REQUIRED_FOR_AI`, default true; false only in development):
  every endpoint that calls the AI provider (`guard_ai` in `app/api/v1/endpoints/ai.py`: search
  answers, quick answers, explanations, generated questions, topic drafts/suggestions, reading a
  paper) first checks `PlusService.check_ai_allowed()`: no active subscription → 403
  `plus_required`; allowance used this month → 429 `ai_allowance_used` with `Retry-After` until the
  month resets. Nothing reaches the provider then. Without a provider the endpoints still answer 503
  `ai_disabled`. Reading a paper is checked when it is queued; the worker's page calls then count
  against the allowance. `GET /ai/status` adds `requires_plus`, `plus_active`,
  `ai_left_this_month`. App: `AiStatus.needsPlus` → `PlusPrompt` ("See Plus") in place of the
  search's AI panel and the "Read with AI" button; other AI actions explain the error with a
  "See Plus" snackbar action. Starting/ending a test refreshes the AI status.
- App: `features/plus` — Profile `PlusCard`, `PlusScreen` (`/profile/plus`, also in the
  sidebar/Home shortcuts): plan, what Plus includes, "x of y AI requests used", the free list,
  a "Start a 7-day test" button only when the server is in test mode, otherwise "can't be bought
  yet". The app never decides entitlement itself.

## Not built yet

1. **Payments.** Google Play Billing on Android (required for digital subscriptions sold in the
   app), a payment provider for the web app, Apple in-app purchase for iOS. Each needs server-side
   receipt/webhook verification that sets `source` play/web and `active_until`. The operator
   needs the store/payment accounts first.
2. **Legal.** Terms: price, renewal, cancellation, refunds; GST invoicing in India; privacy
   policy: payment processor as a recipient.
