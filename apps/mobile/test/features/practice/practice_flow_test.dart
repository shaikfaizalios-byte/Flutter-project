import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:preploop/core/database/app_database.dart';
import 'package:preploop/features/practice/application/practice_providers.dart';
import 'package:preploop/features/practice/domain/practice_models.dart';
import 'package:preploop/features/question_bank/domain/question.dart';

import '../../helpers/pump_app.dart';

/// Mutable "now" shared by the app clock and the fake server.
class TestClock {
  DateTime now = DateTime(2026, 10, 14, 9);
  DateTime call() => now;
}

const chslMock = MockTestView(
  code: 'SSC_CHSL_2026_TIER1',
  name: 'SSC CHSL 2026 Tier-I',
  available: true,
  totalQuestions: 100,
  durationMinutes: 60,
  negativeMarks: 0.5,
  sections: [SectionAvailabilityView(subject: 'English Language', needed: 25, available: 30)],
);

Future<FakePracticeRepository> pumpPractice(
  WidgetTester tester,
  AppDatabase db, {
  TestClock? clock,
  List<MockTestView> mocks = const [],
  List<BankQuestion>? pool,
  Locale? locale,
}) async {
  final c = clock ?? TestClock();
  final repo = FakePracticeRepository(serverNow: c.call, pool: pool)..mocks = mocks;
  await pumpPrepLoopApp(
    tester,
    db,
    now: c.now,
    deviceLocale: locale,
    clockOverride: c.call,
    practice: repo,
  );
  await tester.tap(
    find.descendant(of: find.byType(NavigationBar), matching: find.byIcon(Icons.quiz_outlined)),
  );
  await tester.pumpAndSettle();
  return repo;
}

Future<void> startPractice(WidgetTester tester) async {
  await tester.tap(find.text('Start practice'));
  await tester.pumpAndSettle();
  await tester.tap(find.widgetWithText(FilledButton, 'Start practice').last);
  await tester.pumpAndSettle();
}

ProviderContainer ref(WidgetTester tester) =>
    ProviderScope.containerOf(tester.element(find.byType(Scaffold).first));

void main() {
  testAppWidgets('hub shows practice, mock availability and review tools', (tester, db) async {
    await pumpPractice(
      tester,
      db,
      mocks: [
        chslMock,
        const MockTestView(
          code: 'X',
          name: 'Unavailable format',
          available: false,
          totalQuestions: 100,
          durationMinutes: 60,
          sections: [
            SectionAvailabilityView(subject: 'General Awareness', needed: 25, available: 3),
          ],
        ),
      ],
    );

    expect(find.text('Practice questions'), findsOneWidget);
    expect(find.text('SSC CHSL 2026 Tier-I'), findsOneWidget);
    expect(find.textContaining('100 questions · 60 min · −0.50 per wrong answer'), findsOneWidget);
    expect(find.textContaining('General Awareness: 3 of 25'), findsOneWidget);
    await scrollTo(tester, find.text('Questions to revisit'));
    expect(find.text('Bookmarks'), findsOneWidget);
    expect(find.text('Questions to revisit'), findsOneWidget);
  });

  testAppWidgets('practice setup sends the chosen options', (tester, db) async {
    final repo = await pumpPractice(tester, db);

    await tester.tap(find.text('Start practice'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('20'));
    await tester.tap(find.text('Include questions not yet reviewed'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Start practice').last);
    await tester.pumpAndSettle();

    final request = repo.practiceRequests.single;
    expect((request.count, request.includeUnverified, request.subject), (20, true, null));
    expect(find.text('Question 1 of 2'), findsOneWidget);
  });

  testAppWidgets('no reviewed questions is explained', (tester, db) async {
    final repo = await pumpPractice(tester, db);
    repo.startFailureCode = 'no_questions_available';

    await startPractice(tester);

    expect(find.textContaining('No reviewed questions match'), findsOneWidget);
  });

  testAppWidgets('practice: immediate feedback, final answers, result with explanation', (
    tester,
    db,
  ) async {
    final repo = await pumpPractice(tester, db);
    await startPractice(tester);

    // Q1: correct answer is option 2.
    await tester.tap(find.text('30'));
    await tester.pumpAndSettle();
    expect(find.text('Correct'), findsOneWidget);
    expect(find.text('Correct answer: (2)'), findsOneWidget);
    expect(find.text('Explanation 1.'), findsOneWidget);

    // Answers are final in practice.
    await tester.tap(find.text('20'));
    await tester.pumpAndSettle();
    expect(repo.sessions.values.single.answers[1], 2);

    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('20')); // Q2 correct is 3 -> wrong
    await tester.pumpAndSettle();
    expect(find.text('Incorrect'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Finish'));
    await tester.pumpAndSettle();
    expect(find.text('All questions are answered.'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Submit'));
    await tester.pumpAndSettle();

    expect(find.text('Result'), findsOneWidget);
    expect(find.text('1 of 2'), findsOneWidget);
    expect(find.text('1 correct · 1 wrong · 0 unattempted'), findsOneWidget);
    expect(find.text('Accuracy 50%'), findsOneWidget);
    expect(find.text('How this score was calculated'), findsOneWidget);
    expect(find.textContaining('no negative marking'), findsOneWidget);
  });

  testAppWidgets('unreviewed questions are labelled during practice', (tester, db) async {
    await pumpPractice(tester, db, pool: [bankQuestion(status: VerificationStatus.unverified)]);
    await startPractice(tester);

    expect(find.text('Not yet reviewed'), findsOneWidget);
    expect(find.text('From your PDF'), findsOneWidget);
  });

  testAppWidgets('offline answers are saved on the device', (tester, db) async {
    final repo = await pumpPractice(tester, db);
    await startPractice(tester);
    repo.offline = true;

    await tester.tap(find.text('30'));
    await tester.pumpAndSettle();

    expect(find.text('Feedback will appear when you are back online.'), findsOneWidget);
  });

  testAppWidgets('mock: no feedback during the test, answers can change, timer from server', (
    tester,
    db,
  ) async {
    final clock = TestClock();
    final repo = await pumpPractice(tester, db, clock: clock, mocks: [chslMock]);

    await tester.tap(find.widgetWithText(FilledButton, 'Start mock test'));
    await tester.pumpAndSettle();
    expect(find.text('Start the mock test?'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Start mock test').last);
    await tester.pumpAndSettle();

    expect(find.text('1:00:00'), findsOneWidget);
    await tester.tap(find.text('20'));
    await tester.pumpAndSettle();
    expect(find.text('Correct'), findsNothing);
    expect(find.text('Incorrect'), findsNothing);
    await tester.tap(find.text('30')); // change the answer
    await tester.pumpAndSettle();
    expect(repo.sessions.values.single.answers[1], 2);

    clock.now = clock.now.add(const Duration(minutes: 10, seconds: 5));
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('49:55'), findsOneWidget);
  });

  testAppWidgets('mock: reopening keeps the server deadline (no timer reset)', (tester, db) async {
    final clock = TestClock();
    final repo = await pumpPractice(tester, db, clock: clock, mocks: [chslMock]);
    await tester.tap(find.widgetWithText(FilledButton, 'Start mock test'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Start mock test').last);
    await tester.pumpAndSettle();
    final id = repo.sessions.keys.single;

    // Leave the test and come back 20 minutes later ("app restart").
    await tester.pageBack();
    await tester.pumpAndSettle();
    clock.now = clock.now.add(const Duration(minutes: 20));
    ref(tester).invalidate(sessionHistoryProvider);
    await tester.pumpAndSettle();
    await scrollTo(tester, find.text('Mock: SSC CHSL 2026 Tier-I'));
    await tester.tap(find.text('Mock: SSC CHSL 2026 Tier-I'));
    await tester.pumpAndSettle();

    expect(repo.sessions.keys.single, id);
    expect(find.text('40:00'), findsOneWidget);
  });

  testAppWidgets('mock: time up submits automatically with saved answers', (tester, db) async {
    final clock = TestClock();
    final repo = await pumpPractice(tester, db, clock: clock, mocks: [chslMock]);
    await tester.tap(find.widgetWithText(FilledButton, 'Start mock test'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Start mock test').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('30'));
    await tester.pumpAndSettle();

    clock.now = clock.now.add(const Duration(minutes: 60));
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    expect(repo.submits, isNotEmpty);
    expect(find.text('Result'), findsOneWidget);
    expect(find.text('1 correct · 0 wrong · 1 unattempted'), findsOneWidget);
  });

  testAppWidgets('bookmarks from a session appear in the bookmarks list', (tester, db) async {
    await pumpPractice(tester, db);
    await startPractice(tester);

    await tester.tap(find.byTooltip('Bookmark'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Remove bookmark'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    await scrollTo(tester, find.text('Bookmarks'));
    await tester.tap(find.text('Bookmarks'));
    await tester.pumpAndSettle();

    expect(find.textContaining('What is 20% of 150?'), findsOneWidget);
  });

  testAppWidgets('practice screens are localised in Hindi', (tester, db) async {
    await pumpPractice(tester, db, locale: const Locale('hi'), mocks: [chslMock]);

    expect(find.text('प्रश्नों का अभ्यास'), findsOneWidget);
    expect(find.text('मॉक टेस्ट शुरू करें'), findsOneWidget);
  });
}
