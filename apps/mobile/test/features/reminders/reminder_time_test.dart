import 'package:flutter_test/flutter_test.dart';
import 'package:preploop/features/reminders/domain/reminder_plan.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

void main() {
  setUpAll(tzdata.initializeTimeZones);

  tz.TZDateTime at(String zone, int y, int m, int d, int h, [int min = 0]) =>
      tz.TZDateTime(tz.getLocation(zone), y, m, d, h, min);

  String local(tz.TZDateTime t) => '${t.toIso8601String()} ${t.timeZoneName}';

  test('later today when the time is still ahead, otherwise tomorrow', () {
    final morning = at('Asia/Kolkata', 2026, 10, 12, 6);
    expect(local(nextReminderAt(morning, 7 * 60 + 30)), '2026-10-12T07:30:00.000+0530 IST');

    final evening = at('Asia/Kolkata', 2026, 10, 12, 21);
    expect(local(nextReminderAt(evening, 7 * 60 + 30)), '2026-10-13T07:30:00.000+0530 IST');
  });

  test('exactly at the reminder time schedules the next day (no immediate duplicate)', () {
    final now = at('Asia/Kolkata', 2026, 10, 12, 7, 30);
    expect(nextReminderAt(now, 7 * 60 + 30).day, 13);
  });

  test('month and year boundaries', () {
    final now = at('Asia/Kolkata', 2026, 12, 31, 23);
    expect(local(nextReminderAt(now, 30)), '2027-01-01T00:30:00.000+0530 IST');
  });

  test('the same wall-clock time in another timezone is a different instant', () {
    final india = nextReminderAt(at('Asia/Kolkata', 2026, 10, 12, 6), 8 * 60);
    final london = nextReminderAt(at('Europe/London', 2026, 10, 12, 6), 8 * 60);
    expect(india.hour, 8);
    expect(london.hour, 8);
    expect(london.toUtc().difference(india.toUtc()), const Duration(hours: 4, minutes: 30));
  });

  test('keeps the local time across daylight-saving changes', () {
    // Europe/London leaves BST on 25 Oct 2026: 08:00 stays 08:00 local, UTC shifts.
    final before = nextReminderAt(at('Europe/London', 2026, 10, 24, 9), 8 * 60);
    expect(local(before), '2026-10-25T08:00:00.000+0000 GMT');
    final summer = nextReminderAt(at('Europe/London', 2026, 10, 23, 9), 8 * 60);
    expect(local(summer), '2026-10-24T08:00:00.000+0100 BST');
  });

  test('a time skipped by "spring forward" moves to just after the gap', () {
    // America/New_York: 14 Mar 2027 02:00 → 03:00.
    final next = nextReminderAt(at('America/New_York', 2027, 3, 13, 23), 2 * 60 + 30);
    expect(next.day, 14);
    expect(local(next), '2027-03-14T03:30:00.000-0400 EDT');
  });

  test('a repeated time on "fall back" day fires once', () {
    // America/New_York: 7 Nov 2027 02:00 → 01:00 (01:30 happens twice).
    final first = nextReminderAt(at('America/New_York', 2027, 11, 6, 23), 90);
    expect(first.day, 7);
    final afterFirst = first.add(const Duration(minutes: 1));
    expect(nextReminderAt(afterFirst, 90).day, 8);
  });

  test('plans with the same content are equal (no reschedule needed)', () {
    const a = ReminderPlan(
      minutes: 450,
      timezone: 'Asia/Kolkata',
      title: 't',
      body: 'b',
      channelName: 'c',
    );
    const b = ReminderPlan(
      minutes: 450,
      timezone: 'Asia/Kolkata',
      title: 't',
      body: 'b',
      channelName: 'c',
    );
    const moved = ReminderPlan(
      minutes: 450,
      timezone: 'Europe/London',
      title: 't',
      body: 'b',
      channelName: 'c',
    );
    expect(a, b);
    expect(a.key, b.key);
    expect(a == moved, isFalse);
  });
}
