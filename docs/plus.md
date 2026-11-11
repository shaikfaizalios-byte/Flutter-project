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

## Paytm on the website

Plus can be bought in the **web app** with Paytm Payment Gateway. The Android app keeps Google Play
only (Play requires its own billing for subscriptions bought in the app), so the button shows only
in the web build (`webPaymentsSupportedProvider` = `kIsWeb`).

- **One payment, no renewal.** One payment gives `PREPLOOP_PAYTM_PLUS_DAYS` days of Plus for
  `PREPLOOP_PAYTM_PLUS_PRICE`. Paying while Plus is on adds the days after the current end. Nothing
  is charged again; the learner pays again when they want more (UPI AutoPay would be a separate
  Paytm product and approval).
- **Flow.** `POST /billing/paytm/orders` (signed in) makes a `web_payments` row (price and days
  copied from the settings), calls Paytm's Initiate Transaction API and returns `pay_path`, a link
  valid for 15 minutes. The app opens it in the same tab; that page posts mid, orderId and txnToken
  to Paytm's payment page. Paytm then posts the result to `POST /billing/paytm/callback`, which
  sends the browser to `PREPLOOP_PAYTM_RETURN_URL` (`{order}` replaced). The app's
  `/profile/plus/paytm?order=...` screen asks `GET /billing/paytm/orders/{id}` every 3 seconds for
  up to 2 minutes.
- **What counts.** Never the callback or webhook form: each only says which order to ask about. The
  server asks Paytm's Transaction Status API and adds Plus only on `TXN_SUCCESS` for this MID, this
  order and this amount (else `mismatch`, refused and recorded). Applied once per order (row lock).
  A full refund (`refundAmt` ≥ the amount) takes the order's days back off a web subscription.
  Refund webhooks (`POST /billing/paytm/refund-webhook`, "refund accepted" and "refund done") name
  the order and the refund's `refId`; the server asks Paytm's Refund Status API and takes the days
  back only when Paytm reports a successful refund whose total covers the whole amount, for this
  MID and order (partial or failed refunds change nothing). Without a `refId` it asks the order
  status instead.
  Failed orders are final; unpaid ones stay `created`. Checksums follow Paytm's published algorithm
  (`app/domain/paytm.py`, checked against Paytm's own library in `tests/test_paytm.py`); a callback
  with a bad checksum is recorded as such.
- **Audit.** `billing_events` provider `paytm`, kinds order / callback / webhook / status, with a
  hash of the order id and no payment details. `web_payments` is the learner's data (exported, and
  deleted with the account).
- **Test and real money stay apart.** A production server must use Paytm's production environment
  and any other server the staging one (refused at start otherwise); each row records its
  environment and the app labels test payments.

### Setting it up

1. In the Paytm dashboard (Developer settings → API keys), use the **Test** keys first.
2. Server settings (private `.env`, never committed):

   ```
   PREPLOOP_PAYTM_ENVIRONMENT=staging            # production only on the production server
   PREPLOOP_PAYTM_MID=...                        # from the dashboard
   PREPLOOP_PAYTM_MERCHANT_KEY=...               # from the dashboard; never in the app or git
   PREPLOOP_PAYTM_PLUS_PRICE=99.00
   PREPLOOP_PAYTM_PLUS_DAYS=30
   PREPLOOP_PAYTM_CALLBACK_URL=https://<api host>/api/v1/billing/paytm/callback
   PREPLOOP_PAYTM_RETURN_URL=https://<web app>/#/profile/plus/paytm?order={order}
   # PREPLOOP_PAYTM_WEBSITE_NAME=...             # only if Paytm gave you one (default WEBSTAGING / DEFAULT)
   ```

   Use the return URL form that matches how the web app's addresses look (with or without `#/`).
3. In the dashboard, set the **Payment Status webhook** to
   `https://<api host>/api/v1/billing/paytm/webhook` (port 443 only). Without it a learner who
   closes the tab still gets Plus when the app next asks, but not before.
   Set the **Refund Notification URL** (and Paytm's refund-success webhook, if your dashboard offers
   it) to `https://<api host>/api/v1/billing/paytm/refund-webhook`, so a refund you make in the
   dashboard ends that payment's Plus days by itself.
4. Pay with Paytm's test instruments, then check `web_payments` and `billing_events`.
5. For real money, switch to the production MID and key and `PREPLOOP_PAYTM_ENVIRONMENT=production`
   on the production server only.

## Razorpay on the website

The other way to pay on the website, built because Paytm's test keys took too long. **Only one of
Paytm and Razorpay may be configured** (the server refuses to start with both); `web_offer.provider`
tells the app which, and the app's buttons name it ("Pay with Razorpay"). The app always uses
`POST /billing/web/orders` and `GET /billing/web/orders/{id}`, which go to the configured provider
(an order is always read back through the provider that made it). The Paytm-only order endpoints
are kept but deprecated.

- **Same offer.** One payment of `PREPLOOP_RAZORPAY_PLUS_PRICE` gives `PREPLOOP_RAZORPAY_PLUS_DAYS`
  days, added after any current Plus; no renewal. Granting and refunds share the Paytm code
  (`grant_days`, `take_back` in `web_billing_service.py`).
- **Flow.** The order endpoint makes a `web_payments` row (provider `razorpay`, our `PLUS-...` id
  as Razorpay's `receipt`, Razorpay's `order_...` id in `provider_order_id`) with the Orders API
  and returns `pay_path` (30 minutes). That page (`GET /billing/razorpay/pay/{id}`) loads Razorpay's
  `checkout.js` with the key id and order (never the secret) in redirect mode: after paying,
  Razorpay posts to `POST /billing/razorpay/callback`, which sends the browser to
  `PREPLOOP_RAZORPAY_RETURN_URL`; closing the checkout goes back there too. The app's
  `/profile/plus/payment?order=...` screen asks every 3 seconds for up to 2 minutes.
- **What counts.** Only Razorpay's list of the order's payments (`GET /v1/orders/{id}/payments`):
  a captured payment of the whole amount in INR (pure `app/domain/razorpay.py` `outcome`).
  Authorized-not-captured = pending; failed attempts = failed but **not final** (the learner may
  retry on the same order, and a later webhook still counts); a full refund (`amount_refunded` ≥
  the amount) takes the days back and is final; a partial refund changes nothing; another order,
  amount or currency = `mismatch`, refused and recorded. The checkout's signature
  (HMAC-SHA256 of `order_id|payment_id` with the key secret) is checked and recorded, never relied on.
- **Webhooks** (`POST /billing/razorpay/webhook`): refused (401) unless `X-Razorpay-Signature` is
  the HMAC-SHA256 of the raw body with the webhook secret. `payment.*`, `order.paid` and `refund.*`
  events all name the order (refunds through their payment), and the server then asks the Orders API
  as above. Unknown orders are ignored; Razorpay down = 502 so Razorpay retries.
- **Test and real money stay apart.** Test keys (`rzp_test_`) on any server but production; live
  keys (`rzp_live_`) on production only (refused at start otherwise). Rows record `staging` /
  `production`, and the app labels test payments.
- **Audit.** `billing_events` provider `razorpay` (migration 0062), the same kinds and order id hash.

### Setting it up

1. Sign up at razorpay.com and stay in **Test mode** (no KYC needed for test keys). Dashboard →
   Account & Settings → API Keys → generate a test key.
2. Server settings (private `.env`, never committed; leave every `PREPLOOP_PAYTM_*` unset):

   ```
   PREPLOOP_RAZORPAY_KEY_ID=rzp_test_...          # rzp_live_... only on the production server
   PREPLOOP_RAZORPAY_KEY_SECRET=...               # never in the app or git
   PREPLOOP_RAZORPAY_WEBHOOK_SECRET=...           # the secret you type when adding the webhook
   PREPLOOP_RAZORPAY_PLUS_PRICE=99.00
   PREPLOOP_RAZORPAY_PLUS_DAYS=30
   PREPLOOP_RAZORPAY_CALLBACK_URL=https://<api host>/api/v1/billing/razorpay/callback
   PREPLOOP_RAZORPAY_RETURN_URL=https://<web app>/#/profile/plus/payment?order={order}
   ```

3. Dashboard → Webhooks → add `https://<api host>/api/v1/billing/razorpay/webhook` with the
   secret above and the events `payment.captured`, `payment.failed`, `order.paid`,
   `refund.processed`.
4. Keep **automatic capture** on (Razorpay's default; Account & Settings → Payment capture).
   Uncaptured payments are returned by Razorpay after 3 days and never give Plus.
5. Pay with Razorpay's test instruments (UPI `success@razorpay` / `failure@razorpay`, or its test
   cards), then check `web_payments` and `billing_events`.
6. For real money: finish Razorpay's KYC (the individual / unregistered route takes a personal
   PAN), then use the live key on the production server only.

## Not built yet

1. **Other payments.** Apple in-app purchase for iOS (the same `subscriptions` row). Google Play,
   Paytm and Razorpay are built (above) but have never run against the real Play API, Paytm or
   Razorpay (no keys here yet); automatic monthly renewal on the website is not built.
2. **Legal.** Terms of sale are drafted in `apps/mobile/assets/legal/terms.md` ("PrepLoop Plus"), with
   [placeholders] for the refund policy, GST, outages, grievance officer and seller details; GST
   invoicing in India is not built; privacy
   policy: Google Play and Paytm as payment processors, what `play_purchases`/`web_payments`/
   `billing_events` keep and for how long.
3. **Account deletion with an active Play subscription.** Deleting the account does not cancel
   billing in Google Play; the app should tell the learner to cancel in Play first.
