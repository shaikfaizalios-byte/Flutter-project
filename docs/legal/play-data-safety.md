# Google Play data safety — draft answers

Derived from the actual data flows (docs/accounts-sync.md, docs/ai.md, docs/security.md).
**Review with the operator and legal counsel before submitting.** The privacy policy and terms
drafts live in `apps/mobile/assets/legal/` (shown in the app) and must be published at a public URL
for the Play listing.

## Overview

| Question | Answer |
|---|---|
| Does the app collect or share user data? | Collects: yes. Shares: no (service providers acting for us are not "sharing" under Play's definition) |
| Is data encrypted in transit? | Yes (HTTPS only; non-development builds refuse http) |
| Can users request deletion? | Yes, in the app (Profile → Delete account), and via [contact] |
| Independent security review | No (not yet) |

## Data types

| Play category → type | Collected | Shared | Optional? | Purpose | Notes |
|---|---|---|---|---|---|
| Personal info → Email address | Yes | No | Required | Account management | Sign-in, reset and verification codes |
| Personal info → Name | Yes | No | Optional | Account management | Optional display name |
| Personal info → User IDs | Yes | No | Required | Account management | Internal account id |
| App activity → Other user-generated content | Yes | No | Required for the feature | App functionality | Notes, flashcards, study plan, practice answers |
| Files and docs → Files and docs | Yes | No | Optional | App functionality | Imported question-paper PDFs and text read from them |
| App activity → App interactions | Yes | No | Required | App functionality, analytics (own progress only) | Practice results and revision ratings, shown back to the learner; no third-party analytics |
| App info and performance → Diagnostics | No | — | — | — | No crash reporting or analytics SDK in the app |
| Location, contacts, photos, audio, health, finance, messages, calendar, device ids | No | — | — | — | Not accessed |

**AI assistance:** when a learner uses it, the question text or the chosen concept notes are sent to
the AI provider to produce a result for that learner. This is processing by a service provider on
our behalf, not sharing. It's optional and off unless the server is configured.

## Permissions (Android)

| Permission | Why |
|---|---|
| `INTERNET` | Sync, papers, practice |
| `POST_NOTIFICATIONS` | Daily study reminder, asked for only when the learner turns it on |
| `RECEIVE_BOOT_COMPLETED` | Restores the reminder after a restart |
| (none for exact alarms, location, contacts, storage) | Inexact alarms; the PDF picker uses the system document picker |
