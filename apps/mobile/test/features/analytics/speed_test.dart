import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:preploop/core/utils/calendar_date.dart';
import 'package:preploop/features/analytics/domain/analytics_models.dart';
import 'package:preploop/features/analytics/domain/speed.dart';

import '../../helpers/pump_app.dart';

import 'package:preploop/features/analytics/presentation/progress_screen.dart';

import 'progress_flow_test.dart' show openProgress, scrollProgress;

const percent = TypeSpeed(
  patternId: 'pat1',
  name: 'Percent of a number',
  answered: 8,
  correct: 6,
  timedAnswered: 8,
  timeSpentMs: 8 * 42000,
  slowCorrect: 2,
  targetSeconds: 36,
);

/// Some practice, so Progress shows its cards rather than the empty state.
PracticeAnalytics someAnswers() => PracticeAnalytics(
  timezone: 'Asia/Kolkata',
  today: CalendarDate(2026, 11, 12),
  days: 30,
  recentDays: 14,
  total: const AnswerCounts(answered: 8, correct: 6),
  sessions: 1,
);

Future<void> tapInProgress(WidgetTester tester, Finder finder) async {
  final target = find.descendant(of: find.byType(ProgressScreen), matching: finder);
  await tester.ensureVisible(target);
  await tester.pumpAndSettle();
  await tester.tap(target);
}

void main() {
  test('a drill uses the type\'s own target, else the paper\'s', () {
    const report = SpeedReport(
      slowFactor: 1.5,
      target: SpeedTarget(fromFormat: true, seconds: 40),
      types: [percent],
    );
    expect(report.drillSeconds(percent), 36);
    expect(
      report.drillSeconds(const TypeSpeed(patternId: 'p', name: 'x', answered: 1, correct: 1)),
      40,
    );
    expect(
      const SpeedReport(slowFactor: 1.5)
          .drillSeconds(const TypeSpeed(patternId: 'p', name: 'x', answered: 1, correct: 1)),
      isNull,
    );
    expect(percent.secondsPerAnswer, 42);
  });

  testAppWidgets('speed per question type, from the verified format, with a timed drill', (
    tester,
    db,
  ) async {
    final analytics = FakeAnalyticsRepository(data: someAnswers())
      ..speedReport = const SpeedReport(
        slowFactor: 1.5,
        target: SpeedTarget(fromFormat: true, formatName: 'Sample Tier-I', seconds: 36),
        types: [percent],
      );
    final practice = FakePracticeRepository(serverNow: () => DateTime(2026, 11, 12, 9));
    await pumpPrepLoopApp(
      tester,
      db,
      analytics: analytics,
      practice: practice,
      studyProfile: onboardedProfile.copyWith(examCodes: ['SSC_CHSL']),
    );
    await openProgress(tester);
    await scrollProgress(tester, find.text('Speed by question type'));
    expect(
      find.text('Target: 36 s a question, from the verified format (Sample Tier-I).'),
      findsOneWidget,
    );
    expect(find.text('75% right of 8 · 42 s a question · 2 right but slow'), findsOneWidget);
    expect(find.text('Set my target'), findsNothing); // a format's target can't be replaced

    await tapInProgress(tester, find.text('Timed drill'));
    await tester.pumpAndSettle();
    final request = practice.practiceRequests.single;
    expect(request.patternId, 'pat1');
    expect(request.perQuestionSeconds, 36);
    expect(request.count, drillQuestions);
    expect(find.text('36 s left of 36 s'), findsOneWidget);
  });

  testAppWidgets('without a format the learner sets their own target', (tester, db) async {
    final analytics = FakeAnalyticsRepository(data: someAnswers());
    await pumpPrepLoopApp(
      tester,
      db,
      analytics: analytics,
      studyProfile: onboardedProfile.copyWith(examCodes: ['SSC_CHSL']),
    );
    await openProgress(tester);
    await scrollProgress(tester, find.text('Set my target'));
    expect(find.textContaining('no verified format'), findsWidgets);
    await tapInProgress(tester, find.text('Set my target'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '3');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.text('Enter a number from 5 to 600.'), findsOneWidget);
    await tester.enterText(find.byType(TextField), '45');
    await tester.tap(find.text('Save'));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await tester.pumpAndSettle();
    expect(analytics.requestedOwnTargets.last, 45);
  });
}
