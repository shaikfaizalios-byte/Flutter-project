# Flashcards, spaced revision and reminders (Phase 7)

Code: mobile `apps/mobile/lib/features/revision/` and `lib/features/reminders/`. Everything in this
phase is on the device (Drift schema v4); there are no new server endpoints. Sync arrives in Phase 10.

## Cards

| Kind | Content | Origin label |
|---|---|---|
| Concept card | The concept's **current** title (front) and notes (back), joined at read time, so edits show up | "Your notes" |
| Question card | A snapshot of a question: passage + stem + options (front), and the correct option + the explanation if the paper had one (back). Kept so it can be revised offline | "From your PDF · file, p. N" |

- **Concept cards** are added from the concept's details page ("Add to revision"). Archiving the concept hides
  its card until the concept is restored. Deleting the concept deletes the card (FK cascade).
- **Question cards** are added from Practice → *Bookmarks* or *Questions to revisit* ("Revise these").
  Only questions that are **verified, from an imported paper (`origin = source`), answered and not
  image-dependent** become cards. Others are counted in the message ("1 not added: …"), never added. AI
  content is never stored as a card. Cards from *Questions to revisit* are tagged "Answered wrong in practice"
  (`reason = incorrect_answer`). Adding the same question twice is a no-op (unique `question_id`).

## Schedule (`domain/revision_schedule.dart`, pure)

The ladder is a stored setting (`app_settings.revision_day_offsets`, default `1,4,7`). It can be edited in
Revision → *Change schedule*: 1–8 strictly increasing days, each 1–365. The numbers are **days after the card was
added**, so the default reviews come on Day 1, Day 4 and Day 7.

| Rating | Effect |
|---|---|
| **Good** | Next ladder day. The gap is the distance between ladder days (1 → 4 → 7 gives gaps of 3 and 3). After the last day the card has "graduated": the gap doubles, at least the last ladder day (7 → 14 → 28 …), capped at 180 days |
| **Easy** | Moves on like Good, with gap × 1.5 rounded up (at least 1 more day) |
| **Hard** | Same step, half the Good gap (at least 1 day) |
| **Forgot** (again) | Back to the start of the ladder (Day 1 from today); counts a lapse |

- Gaps are counted **from the day of the review**, not from a missed due date, so late reviews aren't penalised twice.
- Due dates are `CalendarDate` (`yyyy-MM-dd`, no timezone), and "today" comes from `clockProvider`. A card due
  "today" therefore stays due all day, whatever the timezone or DST.
- Changing the ladder applies to future reviews; cards keep their current due date. If the ladder becomes shorter,
  cards beyond its end count as graduated.
- The rating buttons show where each choice sends the card ("Tomorrow", "In 3 days").
- Every review is logged in `card_reviews` (rating, due before/after, gap) for Phase 8 analytics.

The review screen fixes today's due list when it opens. The learner sees the front, taps *Show answer*, then rates.
A summary shows the counts per rating. The dashboard's "What should I study today?" shows the cards due (and
overdue), or the next review date. It is still not a generated study plan (Phase 8).

## Daily reminder (`features/reminders`)

- **Packages** (added in Phase 7):
  - `flutter_local_notifications` 22 (BSD-3-Clause)
  - `timezone` 0.11 (BSD-2-Clause)
  - `flutter_timezone` 5 (Apache-2.0)
- **One reminder**, at the reminder time from the study profile, repeating daily (`DateTimeComponents.time`). It
  always uses notification id `7001`, so scheduling again replaces it and never adds a second one.
- **Duplicates.** `ReminderController` compares the wanted plan (time, IANA timezone, wording) with the fingerprint
  of what it last scheduled (`app_settings.reminder_scheduled_plan`). It cancels and re-creates the reminder only
  when they differ. Restarts and resumes therefore never duplicate it.
- **When it syncs:** on app start, on resume, and when the reminder time or app language changes.
  - A resume picks up travel to another timezone.
  - It also picks up permission granted or revoked in system settings. A revoked permission cancels the reminder and shows "blocked".
- **Permission in context.** Nothing is asked at start-up (`DarwinInitializationSettings` request flags are
  false). The prompt appears only when the learner turns on *Profile → Daily study reminder*. If they decline,
  the switch stays on, the status explains the problem, and *Open notification settings* is offered; the rest of
  the app works normally. Without a reminder time, the time picker opens first.
- **Time computation** (`nextReminderAt`, pure). The reminder fires at local wall-clock time in the device's IANA
  zone.
  - Across DST it keeps the same local time.
  - A time that doesn't exist on a "spring forward" day moves to just after the gap (02:30 → 03:30).
  - A repeated time on a "fall back" day fires once.
  - Exactly at the reminder time, the next one is tomorrow (no immediate duplicate).
- **Android:**
  - Inexact alarms (`inexactAllowWhileIdle`), so no `SCHEDULE_EXACT_ALARM`/`USE_EXACT_ALARM` permission is needed; the reminder may arrive a few minutes late.
  - `RECEIVE_BOOT_COMPLETED` and the plugin's boot receiver restore the reminder after a reboot.
  - Core-library desugaring is enabled in `android/app/build.gradle.kts`.
- **iOS:** `AppDelegate` sets the notification-centre delegate so reminders also show in the foreground.
- **Web and desktop:** not supported. The switch is disabled and says so.
- **Privacy:** the notification text is generic ("Time to study"). It contains no card content or counts.

## Verified and not verified

- Verified by tests:
  - the scheduler (ladder, adaptation, configuration, dates)
  - repository rules (eligibility, cascade, archive, idempotency, review log)
  - reminder sync (no duplicates across restarts and resumes, time, timezone and language changes, denied and revoked permission, unsupported platforms)
  - DST and timezone maths with the real tz database
  - the widget flows in English and Hindi
- **Not verified on a device.** No Android SDK and no macOS are available, so the native notification
  behaviour hasn't been seen running:
  - the actual delivery
  - the permission dialogs
  - the boot receiver
  - desugaring and the Gradle build

  Check these first once a device is available.
- If the timezone changes while the app stays closed, the reminder keeps the old zone until the app is next opened.
