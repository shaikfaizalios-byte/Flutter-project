import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:preploop/features/question_bank/domain/question.dart';

import '../../helpers/pump_app.dart';
import '../question_bank/question_bank_test.dart' show openPractice, openQuestion;
import 'practice_flow_test.dart' show TestClock, pumpPractice, startPractice;

BankQuestion typedQuestion({String answer = '2.5'}) => bankQuestion(
  id: 'tita',
  stem: 'What is the ratio as a decimal?',
  options: const [],
  answer: null,
  answerType: 'typed',
  typedAnswer: answer,
  status: VerificationStatus.verified,
);

void main() {
  testAppWidgets('typed-in question: number keyboard, answer by value, expected answer shown', (
    tester,
    db,
  ) async {
    final repo = await pumpPractice(tester, db, pool: [typedQuestion()]);
    await startPractice(tester);

    expect(find.text('What is the ratio as a decimal?'), findsOneWidget);
    final field = find.widgetWithText(TextField, 'Your answer');
    expect(field, findsOneWidget);
    expect(
      tester.widget<TextField>(field).keyboardType,
      const TextInputType.numberWithOptions(decimal: true, signed: true),
    );

    await tester.enterText(field, '2.50');
    await tester.tap(find.text('Save answer'));
    await tester.pumpAndSettle();

    expect(find.text('Correct'), findsOneWidget);
    expect(find.text('Correct answer: 2.5'), findsOneWidget);
    expect(repo.sessions.values.single.typed[1], '2.50');
    // Practice answers are final: the box is locked and the button gone.
    expect(tester.widget<TextField>(field).enabled, isFalse);
    expect(find.text('Save answer'), findsNothing);
  });

  testAppWidgets('a wrong typed answer and the result list', (tester, db) async {
    final clock = TestClock();
    await pumpPractice(
      tester,
      db,
      clock: clock,
      pool: [typedQuestion(answer: '3421')],
    );
    await startPractice(tester);

    await tester.enterText(find.widgetWithText(TextField, 'Your answer'), '3412');
    await tester.tap(find.text('Save answer'));
    await tester.pumpAndSettle();
    expect(find.text('Incorrect'), findsOneWidget);
    expect(find.text('Correct answer: 3421'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Finish'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Submit'));
    await tester.pumpAndSettle();
    await scrollTo(tester, find.text('Your answer: 3412'));
    expect(find.text('Your answer: 3412'), findsOneWidget);
  });

  testAppWidgets('review: switch to a typed answer and save it', (tester, db) async {
    final repo = FakeQuestionsRepository([bankQuestion()]);
    await pumpPrepLoopApp(tester, db, questions: repo);
    await openPractice(tester);
    await openQuestion(tester, 'Q.1');

    await scrollTo(tester, find.text('Typed answer'));
    await tester.tap(find.text('Typed answer'));
    await tester.pumpAndSettle();
    expect(find.text('Correct answer'), findsNothing); // option answer chips hidden
    await tester.enterText(find.widgetWithText(TextField, 'Correct typed answer'), ' 12 ');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    final sent = repo.edits.last.$2;
    expect(sent['answer_type'], 'typed');
    expect(sent['typed_answer'], '12');
    expect(sent.containsKey('options'), isFalse);
    expect(sent.containsKey('correct_option_position'), isFalse);
  });
}
