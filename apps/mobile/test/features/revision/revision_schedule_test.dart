import 'package:flutter_test/flutter_test.dart';
import 'package:preploop/core/utils/calendar_date.dart';
import 'package:preploop/features/revision/domain/revision_schedule.dart';

void main() {
  const settings = RevisionSettings();
  final added = CalendarDate(2026, 10, 1);

  CardSchedule reviewOnDue(
    CardSchedule card,
    RecallRating rating, [
    RevisionSettings s = settings,
  ]) => RevisionScheduler.review(card, rating, card.dueOn, s);

  group('default Day 1 / 4 / 7 ladder', () {
    test('a new card is due on Day 1', () {
      final card = RevisionScheduler.initial(added, settings);
      expect(card.dueOn, CalendarDate(2026, 10, 2));
      expect((card.step, card.gapDays, card.reviewCount), (0, 1, 0));
    });

    test('remembering every time follows Day 1, 4, 7, then growing gaps', () {
      var card = RevisionScheduler.initial(added, settings);
      final dueDays = <int>[added.daysUntil(card.dueOn)];
      for (var i = 0; i < 5; i++) {
        card = reviewOnDue(card, RecallRating.good);
        dueDays.add(added.daysUntil(card.dueOn));
      }
      expect(dueDays, [1, 4, 7, 14, 28, 56]);
      expect(card.reviewCount, 5);
      expect(card.lapseCount, 0);
    });

    test('gaps never exceed the maximum', () {
      var card = RevisionScheduler.initial(added, settings);
      for (var i = 0; i < 20; i++) {
        card = reviewOnDue(card, RecallRating.easy);
      }
      expect(card.gapDays, RevisionScheduler.maxGapDays);
    });
  });

  group('adaptive follow-up', () {
    final day4 = reviewOnDue(RevisionScheduler.initial(added, settings), RecallRating.good);

    test('forgetting (Again) restarts the ladder and counts a lapse', () {
      final next = reviewOnDue(day4, RecallRating.again);
      expect((next.step, next.gapDays, next.lapseCount), (0, 1, 1));
      expect(next.dueOn, day4.dueOn.addDays(1));
    });

    test('Hard keeps the step with a shorter gap', () {
      final next = reviewOnDue(day4, RecallRating.hard);
      expect(next.step, day4.step);
      expect(next.gapDays, 1); // half of the Good gap (3), at least 1
    });

    test('Easy moves on with a longer gap than Good', () {
      final gaps = RevisionScheduler.previewGaps(day4, settings);
      expect(gaps, {
        RecallRating.again: 1,
        RecallRating.hard: 1,
        RecallRating.good: 3,
        RecallRating.easy: 5,
      });
      expect(reviewOnDue(day4, RecallRating.easy).step, day4.step + 1);
    });

    test('graduated cards: Hard halves and Again restarts', () {
      var card = RevisionScheduler.initial(added, settings);
      for (var i = 0; i < 4; i++) {
        card = reviewOnDue(card, RecallRating.good); // gaps 3, 3, 7, 14
      }
      expect(card.gapDays, 14);
      expect(RevisionScheduler.previewGaps(card, settings), {
        RecallRating.again: 1,
        RecallRating.hard: 14,
        RecallRating.good: 28,
        RecallRating.easy: 42,
      });
    });

    test('late reviews count the gap from the review day, not the missed due date', () {
      final late = day4.dueOn.addDays(5);
      final next = RevisionScheduler.review(day4, RecallRating.good, late, settings);
      expect(next.dueOn, late.addDays(3));
    });
  });

  group('configurable ladder', () {
    test('a custom ladder is followed', () {
      const custom = RevisionSettings(dayOffsets: [2, 5, 10, 20]);
      var card = RevisionScheduler.initial(added, custom);
      final dueDays = <int>[added.daysUntil(card.dueOn)];
      for (var i = 0; i < 4; i++) {
        card = reviewOnDue(card, RecallRating.good, custom);
        dueDays.add(added.daysUntil(card.dueOn));
      }
      expect(dueDays, [2, 5, 10, 20, 40]);
    });

    test('shortening the ladder graduates cards beyond its end', () {
      var card = RevisionScheduler.initial(
        added,
        const RevisionSettings(dayOffsets: [1, 2, 3, 4, 5]),
      );
      for (var i = 0; i < 3; i++) {
        card = reviewOnDue(
          card,
          RecallRating.good,
          const RevisionSettings(dayOffsets: [1, 2, 3, 4, 5]),
        );
      }
      expect(card.step, 3);
      final next = reviewOnDue(card, RecallRating.good); // now Day 1/4/7
      expect(next.step, 3);
      expect(next.gapDays, 7); // max(2 × 1, last ladder day 7)
    });

    test('validation, normalisation and storage format', () {
      expect(RevisionSettings.isValid([1, 4, 7]), isTrue);
      expect(RevisionSettings.isValid([]), isFalse);
      expect(RevisionSettings.isValid([4, 1]), isFalse);
      expect(RevisionSettings.isValid([0, 3]), isFalse);
      expect(RevisionSettings.isValid([1, 400]), isFalse);
      expect(RevisionSettings.isValid([1, 2, 3, 4, 5, 6, 7, 8, 9]), isFalse);
      expect(RevisionSettings.normalize([7, 1, 4, 4]), [1, 4, 7]);
      expect(RevisionSettings.normalize([0]), isNull);
      expect(RevisionSettings.parse('2, 6,12').dayOffsets, [2, 6, 12]);
      expect(RevisionSettings.parse('x').dayOffsets, RevisionSettings.defaultDayOffsets);
      expect(RevisionSettings.parse('5,3').dayOffsets, RevisionSettings.defaultDayOffsets);
      expect(RevisionSettings.parse(null).dayOffsets, RevisionSettings.defaultDayOffsets);
      expect(const RevisionSettings(dayOffsets: [1, 3]).serialize(), '1,3');
    });
  });

  group('calendar dates', () {
    test('due status', () {
      final card = CardSchedule(step: 0, gapDays: 1, dueOn: CalendarDate(2026, 10, 5));
      expect(card.isDue(CalendarDate(2026, 10, 4)), isFalse);
      expect(card.isDue(CalendarDate(2026, 10, 5)), isTrue);
      expect(card.isOverdue(CalendarDate(2026, 10, 5)), isFalse);
      expect(card.isOverdue(CalendarDate(2026, 10, 6)), isTrue);
    });

    test('adding days crosses months, leap days and DST dates exactly', () {
      expect(CalendarDate(2026, 10, 30).addDays(3), CalendarDate(2026, 11, 2));
      expect(CalendarDate(2028, 2, 28).addDays(1), CalendarDate(2028, 2, 29));
      expect(CalendarDate(2027, 3, 13).addDays(1), CalendarDate(2027, 3, 14)); // US DST start
      expect(CalendarDate(2026, 10, 25).addDays(-1), CalendarDate(2026, 10, 24)); // EU DST end
    });
  });
}
