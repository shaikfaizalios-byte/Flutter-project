import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:preploop/core/database/app_database.dart';
import 'package:preploop/features/question_bank/domain/question.dart';
import 'package:preploop/features/revision/data/revision_repository.dart';

import '../../helpers/pump_app.dart';
import 'practice_flow_test.dart' show TestClock, startPractice;

/// Two verified paper questions: q1 (right answer 30 = option 2), q2 (right answer option 3).
final verified = [
  bankQuestion(status: VerificationStatus.verified),
  bankQuestion(
    id: 'q2',
    number: 2,
    stem: 'Second?',
    answer: 3,
    status: VerificationStatus.verified,
  ),
];

Future<void> practiseOneRightOneWrong(WidgetTester tester, AppDatabase db) async {
  final clock = TestClock();
  await pumpPrepLoopApp(
    tester,
    db,
    now: clock.now,
    clockOverride: clock.call,
    practice: FakePracticeRepository(serverNow: clock.call, pool: verified),
    questions: FakeQuestionsRepository(verified),
  );
  await tester.tap(
    find.descendant(of: find.byType(NavigationBar), matching: find.byIcon(Icons.quiz_outlined)),
  );
  await tester.pumpAndSettle();
  await startPractice(tester);
  await tester.tap(find.text('30')); // right
  await tester.pumpAndSettle();
  await tester.tap(find.text('Next'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('20')); // wrong
  await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
  await tester.pumpAndSettle();
}

Future<List<RevisionCardRow>> cards(AppDatabase db) => db.select(db.revisionCards).get();

void main() {
  testAppWidgets('a wrong practice answer becomes one revision card, a right one none', (
    tester,
    db,
  ) async {
    await practiseOneRightOneWrong(tester, db);
    final rows = await tester.runAsync(() => cards(db));
    expect(rows!.map((c) => c.questionId), ['q2']);
    expect(rows.single.reason, 'incorrect_answer');

    // Submitting the session again offers the same wrong answer: still one card.
    await tester.tap(find.widgetWithText(FilledButton, 'Finish'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Submit'));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await tester.pumpAndSettle();
    expect((await tester.runAsync(() => cards(db)))!, hasLength(1));
  });

  testAppWidgets('with the setting off, wrong answers stay off the revision ladder', (
    tester,
    db,
  ) async {
    await tester.runAsync(() => RevisionRepository(db).setAddsWrongAnswers(false));
    await practiseOneRightOneWrong(tester, db);
    expect((await tester.runAsync(() => cards(db)))!, isEmpty);
  });
}
