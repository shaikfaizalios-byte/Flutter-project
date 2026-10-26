import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:preploop/core/database/app_database.dart';
import 'package:preploop/core/utils/calendar_date.dart';
import 'package:preploop/features/analytics/domain/analytics_models.dart';
import 'package:preploop/features/focus/application/focus_controller.dart';
import 'package:preploop/features/weekly_review/application/weekly_review_providers.dart';
import 'package:preploop/features/weekly_review/domain/weekly_review.dart';

import '../../helpers/pump_app.dart';

final today = CalendarDate(2026, 10, 25);

void main() {
  group('buildWeeklyReview', () {
    test('sums the last 7 days and the 7 before, from real data only', () {
      final review = buildWeeklyReview(
        today: today,
        focusLog: {
          today: 25,
          today.addDays(-6): 15, // first day of this week
          today.addDays(-7): 40, // last day of the week before
          today.addDays(-14): 99, // older: not counted
        },
        recallLog: {today: 2},
        reviewsByDay: {today.addDays(-1): 8, today.addDays(-10): 3},
        activeDays: {today, today.addDays(-1), today.addDays(-7)},
        practiceDaily: [
          DailyStats(date: today, answered: 10, correct: 7),
          DailyStats(date: today.addDays(-8), answered: 4, correct: 1),
        ],
      );

      expect(review.start, today.addDays(-6));
      expect(review.thisWeek.focusMinutes, 40);
      expect(review.lastWeek.focusMinutes, 40);
      expect(review.thisWeek.activeDays, 2);
      expect(review.lastWeek.activeDays, 1);
      expect(review.thisWeek.reviews, 8);
      expect(review.lastWeek.reviews, 3);
      expect(review.thisWeek.recallChecks, 2);
      expect((review.thisWeek.answered, review.thisWeek.accuracy), (10, 0.7));
      expect(review.lastWeek.answered, 4);
    });

    test('without practice statistics answers are unknown, not zero', () {
      final review = buildWeeklyReview(today: today);
      expect(review.thisWeek.answered, isNull);
      expect(review.thisWeek.accuracy, isNull);
      expect(buildWeeklyReview(today: today, practiceDaily: const []).thisWeek.accuracy, isNull);
    });
  });

  group('reflections', () {
    test('one per day, newest first, only the last 12 kept', () {
      var all = <WeeklyReflection>[];
      for (var i = 0; i < 14; i++) {
        all = addReflection(all, WeeklyReflection(savedOn: today.addDays(-7 * i)));
      }
      all = addReflection(all, WeeklyReflection(savedOn: today, nextWeek: 'More mocks'));
      expect(all, hasLength(WeeklyReviewRules.keptReflections));
      expect(all.first.nextWeek, 'More mocks');
      expect(all.where((r) => r.savedOn == today), hasLength(1));
    });

    test('a review is due after 7 days, only once something was done', () {
      final last = WeeklyReflection(savedOn: today.addDays(-6));
      expect(reviewDue(today: today, last: null, activeDaysThisWeek: 0), isFalse);
      expect(reviewDue(today: today, last: null, activeDaysThisWeek: 1), isTrue);
      expect(reviewDue(today: today, last: last, activeDaysThisWeek: 3), isFalse);
      expect(reviewDue(today: today.addDays(1), last: last, activeDaysThisWeek: 3), isTrue);
    });
  });

  testAppWidgets('Home suggests the review; it shows the week and saves a reflection', (
    tester,
    db,
  ) async {
    await seed(
      tester,
      () => db
          .into(db.appSettings)
          .insert(AppSettingsCompanion.insert(key: focusLogKey, value: '{"2026-10-24": 30}')),
    );
    final analytics = FakeAnalyticsRepository(
      data: PracticeAnalytics(
        timezone: 'Asia/Kolkata',
        today: today,
        days: 30,
        recentDays: 14,
        total: const AnswerCounts(answered: 20, correct: 15),
        sessions: 2,
        daily: [DailyStats(date: today, answered: 20, correct: 15)],
      ),
    );
    await pumpPrepLoopApp(
      tester,
      db,
      analytics: analytics,
      clockOverride: () => DateTime(2026, 10, 25, 9),
    );

    await scrollTo(tester, find.text('Your weekly review is ready'));
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(find.text('Weekly review'), findsOneWidget);
    expect(find.text('2 of 7'), findsOneWidget); // focus yesterday, practice today
    expect(find.text('30 min'), findsOneWidget);
    expect(find.text('20 · 75% correct'), findsOneWidget);

    await scrollTo(tester, find.text('Save'));
    await tester.enterText(
      find.widgetWithText(TextField, 'What will you do differently next week?'),
      'Practise Analogy every day',
    );
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.text('Saved. See you next week.'), findsOneWidget);
    final stored = await (db.select(
      db.appSettings,
    )..where((s) => s.key.equals(weeklyReflectionsKey))).getSingle();
    expect(stored.value, contains('Practise Analogy every day'));

    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    expect(find.text('Your weekly review is ready'), findsNothing);
  });

  testAppWidgets('a week later the review is due again and shows the plan made then', (
    tester,
    db,
  ) async {
    await seed(
      tester,
      () => db
          .into(db.appSettings)
          .insert(
            AppSettingsCompanion.insert(
              key: weeklyReflectionsKey,
              value: '[{"saved_on": "2026-10-18", "next_week": "Practise Analogy every day"}]',
            ),
          ),
    );
    await seed(
      tester,
      () => db
          .into(db.appSettings)
          .insert(AppSettingsCompanion.insert(key: focusLogKey, value: '{"2026-10-24": 30}')),
    );
    await pumpPrepLoopApp(tester, db, clockOverride: () => DateTime(2026, 10, 25, 9));
    await scrollTo(tester, find.text('Your weekly review is ready'));

    await tester.tap(
      find.descendant(of: find.byType(NavigationBar), matching: find.text('Progress')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Weekly review'));
    await tester.pumpAndSettle();
    expect(find.text('Last time you planned'), findsOneWidget);
    expect(find.text('Practise Analogy every day'), findsOneWidget);
    // Offline-safe: without practice answers nothing is made up.
    expect(find.text('0'), findsWidgets);
  });
}
