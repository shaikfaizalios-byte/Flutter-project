# Global Phase 3 — Conflict-aware sync: acceptance report

Scope from [audit-and-roadmap.md](audit-and-roadmap.md) §5 "Phase 3". Branch
`claude/global-product-716ab9`, 1 Nov 2026.

## What changed

- **Server (no migration):** `Change.base_seq` (optional). Per-entity policy in
  `app/schemas/sync.py`: notes (`concept`) are conflict-checked — an edit made from an older
  version is not applied and the server's version is returned in `PushResult.conflicts`; card
  reviews are append-only; cards, study profile and settings stay last-writer-wins.
  `PushResult.seqs` returns each accepted record's version. Changes without `base_seq` (older
  apps) behave exactly as before. Deletes still win.
- **Device (Drift v8):** `concepts.server_seq` remembers the version each note was synced from and
  is sent as `base_seq`. On a conflict the engine keeps this device's text as a new note tagged
  `sync-conflict` (uploaded on the next sync) and takes the server's version for the original, so
  neither edit is lost. The v7→v8 migration resets the sync cursor once so the next sync re-pulls
  everything and learns the versions.
- **Visible state:** Profile's sync line adds "n notes were changed on two devices; both versions
  were kept"; a conflict copy's page explains what happened and what to do. EN + HI.

## Tests

- Server `tests/test_sync.py`: stale edit returned as conflict and not applied; up-to-date edit
  applied with a new version; no `base_seq` keeps last-writer-wins; reviews append-only; existing
  round-trip/tombstone/replay/ownership tests still pass.
- Device `test/features/sync/sync_engine_test.dart` (two simulated devices on one fake server):
  both versions kept on both devices; offline edit made from an old version kept beside the newer
  one; an edit on top of the latest version uploads normally; profile stays last-writer-wins.
  `sync_conflict_ui_test.dart`: banner on the copy, Profile message after a real conflict.
  `migration_test.dart`: v7→v8 keeps notes and resets only the cursor.
- Full runs: backend pytest, ruff, mypy all passing; mobile analyze clean, 420 tests passing.

## Behaviour changes to know

- Two devices editing the same note before syncing used to end with the later upload silently
  winning. Now the learner sees two notes (one tagged `sync-conflict`) and chooses.
- First sync after updating the app re-downloads all synced records once (cursor reset).

## Not done / risks

- Conflict detection covers notes only. Revision cards are last-writer-wins (their schedule is
  recomputed from reviews, which are now append-only); profile and settings are single choices.
- A delete made on one device still removes a note edited on another (tombstones win, unchanged).
- No field-level merge; no side-by-side compare screen (the learner opens both notes).
- Not run on two real devices (no devices here); covered by the two-database engine tests.
- Backup restore drill (planned in the roadmap for this phase) not done: it needs the production
  VPS/Docker, which aren't available locally. `infra/production/backup.sh` is unchanged.
