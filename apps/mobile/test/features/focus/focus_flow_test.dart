import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:preploop/features/focus/domain/quotes.dart';
import 'package:preploop/core/utils/calendar_date.dart';

import '../../helpers/pump_app.dart';

class TestClock {
  TestClock(this.now);

  DateTime now;

  DateTime call() => now;
}

void main() {
  testAppWidgets('Home shows momentum and a quote; a focus session is timed and counted', (
    tester,
    db,
  ) async {
    final clock = TestClock(DateTime(2026, 10, 25, 9));
    await pumpPrepLoopApp(
      tester,
      db,
      clockOverride: clock.call,
      studyProfile: onboardedProfile.copyWith(dailyStudyMinutes: () => 50),
    );

    expect(find.text('Start your streak today'), findsOneWidget);
    expect(find.text('0 of 50 min focused today'), findsOneWidget);
    final quote = quoteFor(CalendarDate(2026, 10, 25));
    expect(find.text(quote.en), findsOneWidget);
    expect(find.text('— ${quote.author}'), findsOneWidget);

    // Start 25 minutes of revision: the bar shows the time left on every screen.
    await tester.tap(find.text('Start a focus session'));
    await tester.pumpAndSettle();
    expect(find.textContaining('5-minute break'), findsOneWidget); // the learning tip
    await tester.tap(find.text('Revise flashcards'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Focus · 25:00 left'), findsOneWidget);

    clock.now = clock.now.add(const Duration(minutes: 10));
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Focus · 15:00 left'), findsOneWidget);

    // Time is up: the minutes are logged and the learner is congratulated.
    clock.now = clock.now.add(const Duration(minutes: 15));
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(find.text('Focus session complete'), findsOneWidget);
    expect(
      find.text('You focused for 25 minutes. Take a short break, then come back.'),
      findsOneWidget,
    );
    expect(find.text('Today: 25 of 50 min.'), findsOneWidget);
    await tester.tap(find.text('Back to studying'));
    await tester.pumpAndSettle();
    expect(find.textContaining('left'), findsNothing); // the bar is gone

    await tester.tap(find.byTooltip('Back')); // Revision sits on top of the Study tab
    await tester.pumpAndSettle();
    await tester.tap(find.descendant(of: find.byType(NavigationBar), matching: find.text('Home')));
    await tester.pumpAndSettle();
    expect(find.text('25 of 50 min focused today'), findsOneWidget);
    expect(find.text('1-day streak'), findsOneWidget); // focus time counts as activity

    // Another quote on request.
    await tester.ensureVisible(find.text('Another'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Another'));
    await tester.pumpAndSettle();
    expect(find.text(quoteFor(CalendarDate(2026, 10, 25), offset: 1).en), findsOneWidget);
  });

  testAppWidgets('ending a session early still counts the minutes focused', (tester, db) async {
    final clock = TestClock(DateTime(2026, 10, 25, 9));
    await pumpPrepLoopApp(tester, db, clockOverride: clock.call);
    await tester.tap(find.text('Start a focus session'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('45 min'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Practise questions'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    clock.now = clock.now.add(const Duration(minutes: 12));
    await tester.pump(const Duration(seconds: 1));
    await tester.tap(find.widgetWithText(TextButton, 'End'));
    await tester.pumpAndSettle();
    expect(find.text("You've focused for 12 min. That time still counts."), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'End'));
    await tester.pumpAndSettle();

    await tester.tap(find.descendant(of: find.byType(NavigationBar), matching: find.text('Home')));
    await tester.pumpAndSettle();
    expect(find.text('12 min focused today'), findsOneWidget); // no goal set
    expect(find.text('Set a daily goal'), findsOneWidget);
  });
}
