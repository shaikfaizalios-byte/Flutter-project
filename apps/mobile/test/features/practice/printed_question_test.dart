import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:preploop/core/database/app_database.dart';
import 'package:preploop/features/question_bank/domain/question.dart';

import '../../helpers/pump_app.dart';
import 'practice_flow_test.dart' show TestClock, startPractice;

const printed = QuestionFigure(
  id: 'f1',
  kind: FigureKind.original,
  pageNumber: 29,
  width: 400,
  height: 120,
);

Future<void> practise(WidgetTester tester, AppDatabase db, List<BankQuestion> pool) async {
  final clock = TestClock();
  await pumpPrepLoopApp(
    tester,
    db,
    now: clock.now,
    clockOverride: clock.call,
    practice: FakePracticeRepository(serverNow: clock.call, pool: pool),
    questions: FakeQuestionsRepository(pool),
  );
}

void main() {
  testAppWidgets('a question that did not read in full shows as printed, text on request', (
    tester,
    database,
  ) async {
    await practise(tester, database, [
      bankQuestion(stem: 'If f(x) garbled', figures: const [printed]),
      bankQuestion(id: 'q2', number: 2, stem: 'Second?', answer: 3),
    ]);
    await tester.tap(
      find.descendant(of: find.byType(NavigationBar), matching: find.byIcon(Icons.quiz_outlined)),
    );
    await tester.pumpAndSettle();
    await startPractice(tester);

    expect(find.textContaining('Shown as printed in the paper'), findsOneWidget);
    expect(find.text('If f(x) garbled'), findsNothing);
    await tester.tap(find.text('Show the text as read'));
    await tester.pumpAndSettle();
    expect(find.text('If f(x) garbled'), findsOneWidget);

    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    expect(find.text('Second?'), findsOneWidget); // reads fine: shown as text
    expect(find.text('Show the text as read'), findsNothing);
  });

  testAppWidgets('wrong answers on unreviewed questions say why they are not in revision', (
    tester,
    database,
  ) async {
    await practise(tester, database, [
      bankQuestion(), // unreviewed by default; right answer is option 2 ("30")
      bankQuestion(id: 'q2', number: 2, stem: 'Second?', answer: 3),
    ]);
    await tester.tap(
      find.descendant(of: find.byType(NavigationBar), matching: find.byIcon(Icons.quiz_outlined)),
    );
    await tester.pumpAndSettle();
    await startPractice(tester);
    await tester.tap(find.text('20')); // wrong
    await tester.pumpAndSettle();
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('20'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Finish'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Submit'));
    await tester.pumpAndSettle();
    expect(find.textContaining('2 wrong answers were not added to revision'), findsOneWidget);
  });
}
