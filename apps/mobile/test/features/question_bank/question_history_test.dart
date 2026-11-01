import 'package:flutter_test/flutter_test.dart';
import 'package:preploop/features/question_bank/domain/question.dart';

import '../../helpers/pump_app.dart';
import 'question_bank_test.dart' show openPractice, openQuestion;

QuestionRevision revision(String action, {String actor = 'rules', int answer = 2}) =>
    QuestionRevision(
      id: 'r-$action',
      action: action,
      actor: actor,
      changed: action == 'edited' ? const ['correct_option_position', 'answer_source'] : const [],
      snapshot: QuestionSnapshot(
        stem: 'What is 20% of 150?',
        options: const [('1', '20'), ('2', '30'), ('3', '40'), ('4', '50')],
        answerType: 'choice',
        correctPosition: answer,
      ),
      createdAt: DateTime.utc(2026, 11, 1, 9),
    );

void main() {
  testAppWidgets('an answer read from the key says so, and approving is not official', (
    tester,
    db,
  ) async {
    await pumpPrepLoopApp(tester, db, questions: FakeQuestionsRepository([bankQuestion()]));
    await openPractice(tester);
    await openQuestion(tester, 'What is 20%');

    await scrollTo(tester, find.textContaining("paper's answer key"));
    expect(find.text("Answer from the paper's answer key, as PrepLoop read it."), findsOneWidget);
    expect(find.textContaining('not an official answer key'), findsOneWidget);
  });

  testAppWidgets("a reviewer's answer shows what the paper said", (tester, db) async {
    final question = bankQuestion(
      answer: 3,
      answerOrigin: 'reviewer',
      paperAnswer: const PaperAnswer(
        source: 'answer_key',
        optionPosition: 2,
        optionLabel: 'b',
        optionText: '30',
      ),
    );
    await pumpPrepLoopApp(tester, db, questions: FakeQuestionsRepository([question]));
    await openPractice(tester);
    await openQuestion(tester, 'What is 20%');

    await scrollTo(tester, find.textContaining('You set this answer'));
    expect(find.text('You set this answer. The paper said (b) 30.'), findsOneWidget);
  });

  testAppWidgets('an unknown original is said to be unknown, never guessed', (tester, db) async {
    final question = bankQuestion(answer: 3, answerOrigin: 'reviewer');
    await pumpPrepLoopApp(tester, db, questions: FakeQuestionsRepository([question]));
    await openPractice(tester);
    await openQuestion(tester, 'What is 20%');

    await scrollTo(tester, find.textContaining('was not recorded'));
    expect(find.textContaining('What the paper said was not recorded'), findsOneWidget);
  });

  testAppWidgets('the edit history lists the reading and each change', (tester, db) async {
    final repo = FakeQuestionsRepository([bankQuestion(answer: 3, answerOrigin: 'reviewer')])
      ..revisionsById['q1'] = [
        revision('extracted'),
        revision('edited', actor: 'reviewer', answer: 3),
      ];
    await pumpPrepLoopApp(tester, db, questions: repo);
    await openPractice(tester);
    await openQuestion(tester, 'What is 20%');

    await scrollTo(tester, find.text('Edit history'));
    await tester.tap(find.text('Edit history'));
    await tester.pumpAndSettle();
    await scrollTo(tester, find.text('Changed in review: answer'));

    expect(find.text('Read from the paper by PrepLoop'), findsOneWidget);
    expect(find.text('Changed in review: answer'), findsOneWidget);
    await tester.tap(find.text('Read from the paper by PrepLoop'));
    await tester.pumpAndSettle();
    expect(find.text('Answer: (2)'), findsOneWidget);
  });
}
