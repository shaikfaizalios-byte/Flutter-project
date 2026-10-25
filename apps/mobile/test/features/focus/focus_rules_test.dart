import 'package:flutter_test/flutter_test.dart';
import 'package:preploop/core/utils/calendar_date.dart';
import 'package:preploop/features/focus/domain/focus.dart';
import 'package:preploop/features/focus/domain/quotes.dart';

final today = CalendarDate(2026, 10, 25);
Set<CalendarDate> daysAgo(Iterable<int> offsets) => {for (final d in offsets) today.addDays(-d)};

void main() {
  test('a streak counts days in a row; today stays open until midnight', () {
    expect(currentStreak({}, today), 0);
    expect(currentStreak(daysAgo([0, 1, 2]), today), 3);
    expect(currentStreak(daysAgo([1, 2]), today), 2); // nothing yet today: still alive
    expect(currentStreak(daysAgo([2, 3]), today), 0); // yesterday and today missed
  });

  test('one rest day a week keeps the streak; a second one within 7 days ends it', () {
    expect(currentStreak(daysAgo([0, 1, 3, 4]), today), 4); // day 2 is a rest day
    expect(currentStreak(daysAgo([0, 2, 4, 5]), today), 2); // second miss 2 days later
    expect(currentStreak(daysAgo([0, 1, 3, 4, 5, 6, 7, 8, 9, 10, 12]), today), 11); // 7+ apart
    expect(currentStreak(daysAgo([0, 3, 4]), today), 1); // two days in a row missed
  });

  test('focus minutes add up per day and old days are dropped', () {
    final log = addFocusMinutes({today.addDays(-200): 30}, today, 25, today);
    expect(addFocusMinutes(log, today, 15, today), {today: 40});
  });

  test('a session knows its time left and the whole minutes focused', () {
    final session = FocusSession(startedAt: DateTime.utc(2026, 10, 25, 9), minutes: 25);
    final later = DateTime.utc(2026, 10, 25, 9, 10, 30);
    expect(session.remaining(later), const Duration(minutes: 14, seconds: 30));
    expect(session.elapsedMinutes(later), 10);
    expect(session.isOver(DateTime.utc(2026, 10, 25, 9, 26)), isTrue);
    expect(session.elapsedMinutes(DateTime.utc(2026, 10, 25, 11)), 25); // capped
    expect(FocusSession.fromJson(session.toJson()).endsAt, session.endsAt);
  });

  test('the quote of the day is the same all day and changes on request', () {
    expect(quoteFor(today), quoteFor(today));
    expect(quoteFor(today), isNot(quoteFor(today.addDays(1))));
    expect(quoteFor(today, offset: 1), quoteFor(today.addDays(1)));
    expect(quotes.every((q) => q.en.isNotEmpty && q.hi.isNotEmpty && q.author.isNotEmpty), isTrue);
  });
}
