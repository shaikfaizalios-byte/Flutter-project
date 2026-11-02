import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:preploop/core/database/app_database.dart';
import 'package:preploop/features/practice/domain/practice_models.dart';
import 'package:preploop/features/insights/domain/repeats.dart';

import '../../helpers/pump_app.dart';
import '../documents/documents_screen_test.dart' show FakeDocumentsRepository, overridesFor;

Future<FakePracticeRepository> pumpNewLearner(
  WidgetTester tester,
  AppDatabase db, {
  int starterQuestions = 2,
}) async {
  final practice = FakePracticeRepository(serverNow: () => testNow)
    ..starterCheckQuestions = starterQuestions;
  final insights = FakeInsightsRepository()
    ..sharedSummary = const [SharedBankExam(examCode: 'SSC_CHSL', papers: 1, questions: 2)];
  await pumpPrepLoopApp(
    tester,
    db,
    practice: practice,
    insights: insights,
    studyProfile: onboardedProfile.copyWith(examCodes: ['SSC_CHSL']),
    extraOverrides: overridesFor(FakeDocumentsRepository()), // no papers of their own
  );
  return practice;
}

void main() {
  test('the starter check is test-like: answers change and are marked after submitting', () {
    expect(SessionMode.fromCode('diagnostic'), SessionMode.diagnostic);
    expect(SessionMode.diagnostic.testLike, isTrue);
    expect(SessionMode.practice.testLike, isFalse);
  });

  testAppWidgets('a new learner takes the starter check from Home and sees where to start', (
    tester,
    db,
  ) async {
    await pumpNewLearner(tester, db);

    await scrollTo(tester, find.text('Take a starter check (2 questions)'));
    await tester.tap(find.text('Take a starter check (2 questions)'));
    await tester.pumpAndSettle();

    expect(find.text('Starter check'), findsOneWidget);
    expect(find.text('Explanation 1.'), findsNothing); // no feedback before submitting
    await tester.tap(find.text('30'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Submit'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Submit'));
    await tester.pumpAndSettle();

    expect(find.text('Where to start'), findsOneWidget);
    expect(find.textContaining('not an exam score'), findsOneWidget);
  });

  testAppWidgets('no starter check button when no shared paper allows it', (tester, db) async {
    await pumpNewLearner(tester, db, starterQuestions: 0);

    expect(find.text('Starter papers'), findsOneWidget);
    expect(find.textContaining('Take a starter check'), findsNothing);
  });
}
