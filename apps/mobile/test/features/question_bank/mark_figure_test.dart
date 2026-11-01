import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:preploop/features/question_bank/domain/question.dart';
import 'package:preploop/features/question_bank/presentation/mark_figure_screen.dart';

import '../../helpers/pump_app.dart';
import '../documents/documents_screen_test.dart' show FakeDocumentsRepository, overridesFor;
import 'question_bank_test.dart' show openPractice, openQuestion;

void main() {
  test('a dragged box becomes page fractions, in order and on the page', () {
    const size = Size(400, 800);
    expect(regionFromDrag(const Offset(300, 400), const Offset(100, 200), size), [
      0.25,
      0.25,
      0.75,
      0.5,
    ]);
    expect(regionFromDrag(const Offset(-20, -20), const Offset(200, 400), size), [0, 0, 0.5, 0.5]);
    expect(regionFromDrag(const Offset(10, 10), const Offset(12, 300), size), isNull); // too thin
    expect(regionFromDrag(Offset.zero, const Offset(10, 10), Size.zero), isNull);
  });

  testAppWidgets('the reviewer opens the page to mark a figure', (tester, db) async {
    final documents = FakeDocumentsRepository();
    await pumpPrepLoopApp(
      tester,
      db,
      questions: FakeQuestionsRepository([bankQuestion()]),
      extraOverrides: overridesFor(documents),
    );
    await openPractice(tester);
    await openQuestion(tester, 'What is 20%');

    await scrollTo(tester, find.text('Mark a figure on the page'));
    await tester.tap(find.text('Mark a figure on the page'));
    await tester.pumpAndSettle();

    expect(find.text('Mark the figure'), findsOneWidget);
    expect(documents.pageRequests, [('doc1', 1)]);
    final keep = tester.widget<TextButton>(find.widgetWithText(TextButton, 'Keep'));
    expect(keep.onPressed, isNull); // nothing marked yet
  });

  testAppWidgets('a figure the reviewer marked can be removed', (tester, db) async {
    final questions = FakeQuestionsRepository([
      bankQuestion(
        figures: const [
          QuestionFigure(
            id: 'f1',
            kind: FigureKind.stem,
            pageNumber: 1,
            width: 100,
            height: 50,
            byReviewer: true,
          ),
        ],
      ),
    ]);
    await pumpPrepLoopApp(tester, db, questions: questions);
    await openPractice(tester);
    await openQuestion(tester, 'What is 20%');

    await scrollTo(tester, find.text('Figure you marked (page 1)'));
    await tester.tap(find.byTooltip('Remove this figure'));
    await tester.pumpAndSettle();

    expect(questions.questions['q1']!.figures, isEmpty);
    expect(find.text('Figure you marked (page 1)'), findsNothing);
  });
}
