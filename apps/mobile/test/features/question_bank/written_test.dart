import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:preploop/features/question_bank/domain/question.dart';

import '../../helpers/pump_app.dart';
import 'ai_read_test.dart' show openPaper, summary;

BankQuestion written({
  String id = 'w1',
  VerificationStatus status = VerificationStatus.verified,
  String answer = 'A struct is a value type and is copied on assignment.',
}) => bankQuestion(
  id: id,
  stem: 'What is the difference between a struct and a class?',
  options: const [],
  answer: null,
  answerType: 'written',
  modelAnswer: answer,
  status: status,
  documentId: 'doc1',
);

void main() {
  testAppWidgets('verified Q&A notes become flashcards with the written answer behind', (
    tester,
    db,
  ) async {
    final questions = FakeQuestionsRepository([
      written(),
      written(id: 'w2', status: VerificationStatus.unverified),
    ])..summary = summary(found: 2);
    await openPaper(tester, db, questions: questions);

    expect(find.text('Flashcards from these notes'), findsOneWidget);
    expect(find.textContaining('1 verified questions have written answers'), findsOneWidget);
    await tester.tap(find.text('Make flashcards'));
    await tester.pumpAndSettle();

    final cards = await db.select(db.revisionCards).get();
    expect(cards, hasLength(1)); // only the verified one
    expect(cards.single.front, 'What is the difference between a struct and a class?');
    expect(cards.single.back, 'A struct is a value type and is copied on assignment.');
  });

  testAppWidgets('unverified Q&A notes ask to be verified first', (tester, db) async {
    final questions = FakeQuestionsRepository([written(status: VerificationStatus.unverified)])
      ..summary = summary(found: 1);
    await openPaper(tester, db, questions: questions);
    expect(find.textContaining('Verify them to revise them as flashcards'), findsOneWidget);
    expect(find.text('Make flashcards'), findsNothing);
  });

  testAppWidgets('a written question is edited with its written answer, not options', (
    tester,
    db,
  ) async {
    final questions = FakeQuestionsRepository([written(status: VerificationStatus.unverified)])
      ..summary = summary(found: 1);
    await openPaper(tester, db, questions: questions);
    await scrollTo(tester, find.textContaining('struct and a class'));
    await tester.tap(find.textContaining('struct and a class'));
    await tester.pumpAndSettle();

    final answerField = find.widgetWithText(TextField, 'Answer (as written in the notes)');
    expect(answerField, findsOneWidget);
    expect(find.widgetWithText(TextField, 'Option 1'), findsNothing); // no option fields
    await tester.enterText(answerField, 'Structs are copied; classes are shared.');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    final (_, json) = questions.edits.last;
    expect(json['answer_type'], 'written');
    expect(json['model_answer'], 'Structs are copied; classes are shared.');
    expect(json.containsKey('options'), isFalse);
  });
}
