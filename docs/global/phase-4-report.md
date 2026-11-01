# Global Phase 4 — Google Play payments and entitlements: acceptance report

Scope from [audit-and-roadmap.md](audit-and-roadmap.md) §5 "Phase 4". Branch
`claude/global-product-716ab9`, 1 Nov 2026. Details and operator setup: [docs/plus.md](../plus.md)
"Google Play".

## What changed

- **Data:** migration `0031_play_billing`: `play_purchases` (one row per purchase token, owned by
  one account, as last read from Google) and `billing_events` (audit of every check and
  notification, token hash only, idempotency key, account link cleared on deletion). Reversible.
- **Backend:** pure rules `app/domain/billing.py` (state → entitlement, obfuscated account id,
  refusals); `app/integrations/play_billing.py` (service-account sign-in and Play Developer API
  over the standard library; Google OIDC push-token check); `app/services/billing_service.py`;
  `POST /billing/play/verify`, `POST /billing/play/rtdn` (Pub/Sub, not in OpenAPI);
  `GET /me/plus` adds `play_product_ids` and `play_account_id`, and `purchases_available` is now
  real. Off unless `PREPLOOP_PLAY_*` settings are present.
- **App:** `in_app_purchase` plugin behind a `PlayStore` interface; `PlayPurchaseController`
  listens from app start, sends every purchase to the server, completes it with Play only after the
  server confirms; Plus screen shows Play's products and prices, Subscribe, Restore, pending /
  refused / retry messages, and "Manage or cancel in Google Play". Web and iOS show that Plus is
  bought in the Android app. EN + HI.
- **Dependencies (new):** server `cryptography` 47 (Apache-2.0 OR BSD-3-Clause; RS256 for the
  Google tokens; `cffi`/`pycparser` were already locked); app `in_app_purchase` 3.3.1 (+ android
  0.5.5, storekit 0.4.16, platform interface 1.4.1; BSD-3, Flutter team).
- **Docs:** docs/plus.md (flow, rules, notifications, operator setup), Play data-safety draft
  (purchase history, BILLING permission), CLAUDE.md.

## Tests

- `tests/test_billing.py` (15, fake Play API): entitlement per state; refusals (other account,
  other product, unknown token, token held by another account); verify turns Plus on, acknowledges
  once, audits without the token; Google down → 502 for retry; longer operator grant kept; not
  configured → 503; renewal notification extends from Google's answer; a message applied once;
  on hold / recovered / refund (final); upgrade replaces the old purchase; push token and package
  checked.
- `tests/test_play_client.py` (8, no network): the service-account assertion is RS256-signed with
  the right scope and reused; URL-encoded tokens; push tokens refused for wrong audience, expired,
  wrong issuer, wrong or unverified sender; a valid token passes.
- `test/features/plus/play_purchase_test.dart` (8): offer with Play's price; buy → server check →
  complete; server can't check → not completed; refused → explained; pending payment; purchase
  delivered at start is checked; no Play → Android-app message.
- Full runs: backend pytest (all passing, migrations up → down → up incl. 0031), ruff, mypy,
  `alembic check`; mobile analyze clean, 428 tests passing; `flutter build web` succeeds (the plugin
  is not used on web).

## Not done / risks

- **Never run against the real Google Play API or on a device** (no Play Console, service
  account or Android SDK here). Needs an internal test track with license testers before release.
- `AppFeatures.learnStart` stays off: turn it on only after real purchases work in a release build.
- Web payments and Apple in-app purchase are not built.
- Deleting an account does not cancel billing in Google Play; the app doesn't warn yet.
- Legal: terms (renewal, cancellation, refunds), GST invoicing, privacy policy (Google Play as
  processor, retention of `play_purchases`/`billing_events`) need counsel.
- No scheduled re-check of purchases: entitlement relies on notifications plus the stored expiry
  (Plus ends at the stored expiry if a renewal notification is missed, until the app restores).
