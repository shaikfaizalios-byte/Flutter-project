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

## Google Play (global Phase 4)

Built, **off until the operator configures it**. The server is the only judge: a purchase counts
after the Play Developer API confirms it, never because the app or a notification says so.

**Flow.** `GET /me/plus` adds `purchases_available`, `play_product_ids` and `play_account_id`
(HMAC of the account id with the server secret, `app/domain/billing.py`). The Android app shows
Play's products with **Play's own price** (`in_app_purchase`, `features/plus/data/play_store.dart`)
and buys with `applicationUserName = play_account_id`. Every purchase update goes to
`POST /billing/play/verify` (`app/services/billing_service.py`): read the token with
`purchases.subscriptionsv2.get`; refuse unless it is one of our products, its
`obfuscatedExternalAccountId` is this account's and no other account holds the token; store it
(`play_purchases`, migration 0031), acknowledge it, and set `subscriptions` (source `play`,
`active_until` = expiry). Only then does the app complete the purchase with Play; a purchase the
server couldn't check (offline, Google down → 502 `store_unavailable`) stays uncompleted, and Play
delivers it again. The purchase listener starts with the app (purchases finished while it was
closed are checked on start).

**Entitlement** (pure rules): active, in grace period, or canceled-but-paid → Plus until the
expiry; pending, on hold, paused, expired → no Plus; refunded/charged back (`VOIDED`) → ends now and
stays ended. An upgrade or resubscription replaces the old purchase (`linkedPurchaseToken`). A
longer operator grant or test subscription is not shortened.

**Notifications.** Real-time developer notifications arrive as Pub/Sub push at
`POST /api/v1/billing/play/rtdn` (not in the OpenAPI schema). The OIDC token must be signed by
Google, for `PREPLOOP_PLAY_RTDN_AUDIENCE`, from `PREPLOOP_PLAY_RTDN_SERVICE_ACCOUNT` (else 401).
Each message is applied once (`billing_events.event_key = rtdn:<messageId>`); the purchase is read
again from Google. Errors reaching Google return 502 so Pub/Sub retries.

**Audit.** `billing_events` records every check and notification: kind, outcome, Play state or
refusal reason, SHA-256 of the token (never the token), account (cleared on account deletion).

**Operator setup** (all needed; without them `purchases_available` is false):
1. Play Console: create the subscription product(s) and base plan(s) with prices per country (the
   app shows Play's price; no price is in our code). Upload a build with billing to a test track.
2. Google Cloud: a service account with access to the app in Play Console (Users and permissions:
   view financial data, manage orders and subscriptions); download its JSON key **to the server
   only** (never into the repo).
3. Server env: `PREPLOOP_PLAY_PACKAGE_NAME`, `PREPLOOP_PLAY_SUBSCRIPTION_IDS` (comma-separated
   product ids), `PREPLOOP_PLAY_SERVICE_ACCOUNT_FILE` (path to the key).
4. Notifications: a Pub/Sub topic set in Play Console (Monetization setup), a **push** subscription
   to `https://<api>/api/v1/billing/play/rtdn` with authentication on; set
   `PREPLOOP_PLAY_RTDN_AUDIENCE` and `PREPLOOP_PLAY_RTDN_SERVICE_ACCOUNT` to that subscription's
   audience and service account. Send a test notification from Play Console; it appears in
   `billing_events` as kind `test`.
5. License testers in Play Console buy without being charged (`test_purchase` is recorded).

## Not built yet

1. **Other payments.** A payment provider for the web app and Apple in-app purchase for iOS (the
   same `subscriptions` row; `billing_events.provider` would gain values). Google Play is built
   (above) but has never run against the real Play API (no Play Console here).
2. **Legal.** Terms: price, renewal, cancellation, refunds; GST invoicing in India; privacy
   policy: Google Play as payment processor, what `play_purchases`/`billing_events` keep and for how long.
3. **Account deletion with an active Play subscription.** Deleting the account does not cancel
   billing in Google Play; the app should tell the learner to cancel in Play first.
