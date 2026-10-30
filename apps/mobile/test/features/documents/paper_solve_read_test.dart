import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:preploop/core/database/app_database.dart';
import 'package:preploop/features/ai/data/ai_repository.dart';
import 'package:preploop/features/documents/domain/paper_solve.dart';
import 'package:preploop/features/documents/presentation/paper_read_screen.dart';
import 'package:preploop/features/documents/presentation/paper_solve_screen.dart';
import 'package:preploop/features/question_bank/domain/question.dart';
import 'package:preploop/features/question_bank/presentation/document_review_screen.dart';

import '../../helpers/pump_app.dart';
import 'documents_screen_test.dart' show FakeDocumentsRepository, doc, openDocuments, overridesFor;

const paperName = 'iOS interview.pdf';

final paperQuestions = [
  bankQuestion(
    id: 'q3',
    number: 3,
    stem: 'Explain optional binding.',
    answerType: 'written',
    options: const [],
    answer: null,
    modelAnswer: 'It unwraps an optional with if let.',
  ),
  bankQuestion(id: 'q1', number: 1, stem: 'What is 20% of 150?', explanation: '150 × 0.2 = 30.'),
  bankQuestion(
    id: 'q2',
    number: 2,
    stem: 'Type 15% of 200.',
    answerType: 'typed',
    options: const [],
    answer: null,
    typedAnswer: '30',
  ),
  bankQuestion(id: 'q4', number: 4, stem: 'A rejected copy', status: VerificationStatus.rejected),
  bankQuestion(id: 'other', number: 1, stem: 'Another paper', documentId: 'd2'),
]; // fmt: skip

Future<(FakeDocumentsRepository, FakeAiRepository)> openPaper(
  WidgetTester tester,
  AppDatabase db, {
  bool ai = true,
}) async {
  final repo = FakeDocumentsRepository()
    ..listResponses = [
      [
        doc(
          id: 'doc1',
          filename: paperName,
          exam: 'SSC_CHSL',
          pages: 2,
          processed: 2,
          segmentation: 'done',
          questions: 4,
        ),
      ],
    ];
  final fakeAi = FakeAiRepository(enabled: ai);
  await pumpPrepLoopApp(
    tester,
    db,
    studyProfile: onboardedProfile.copyWith(examCodes: ['SSC_CHSL']),
    questions: FakeQuestionsRepository(paperQuestions),
    ai: fakeAi,
    extraOverrides: overridesFor(repo),
  );
  await openDocuments(tester, repo);
  await tester.tap(find.text(paperName));
  await tester.pumpAndSettle();
  return (repo, fakeAi);
}

Future<void> next(WidgetTester tester) async {
  await tester.tap(find.text('Next'));
  await tester.pumpAndSettle();
}

void main() {
  test('a paper is solved in printed order, without rejected questions', () {
    final questions = solvableQuestions(paperQuestions.where((q) => q.documentId == 'doc1'));

    expect([for (final q in questions) q.id], ['q1', 'q2', 'q3']);
    expect(
      [for (final q in questions) solveKind(q)],
      [SolveKind.choice, SolveKind.typed, SolveKind.written],
    );
    expect(choiceCorrect(questions[0], 2), isTrue);
    expect(typedCorrect(questions[1], ' 30.0 '), isTrue);
    expect(typedCorrect(questions[2], 'anything'), isNull); // written: no typed answer
  });

  testAppWidgets('tapping a paper offers solve, read and review', (tester, db) async {
    await openPaper(tester, db);

    expect(find.text('Solve this paper'), findsOneWidget);
    expect(find.text('Read this paper'), findsOneWidget);
    await tester.tap(find.text('Review and correct questions'));
    await tester.pumpAndSettle();
    expect(find.byType(DocumentReviewScreen), findsOneWidget);
  });

  testAppWidgets('reading shows every page of the PDF as uploaded', (tester, db) async {
    final (repo, _) = await openPaper(tester, db);

    await tester.tap(find.text('Read this paper'));
    await tester.pumpAndSettle();

    expect(find.byType(PaperReadScreen), findsOneWidget);
    expect(find.text('Read: $paperName'), findsOneWidget);
    expect(find.text('Page 1 of 2'), findsOneWidget);
    expect(repo.pageRequests, contains(('doc1', 1)));
  });

  testAppWidgets('solving marks options, typed answers and written answers', (tester, db) async {
    final (_, ai) = await openPaper(tester, db);
    await tester.tap(find.text('Solve this paper'));
    await tester.pumpAndSettle();
    expect(find.byType(PaperSolveScreen), findsOneWidget);

    // 1. Multiple choice, marked with the paper's answer key.
    expect(find.text('Question 1 of 3'), findsOneWidget);
    expect(find.text('Another paper'), findsNothing);
    await tester.tap(find.text('20'));
    await tester.pumpAndSettle();
    expect(find.text('Not quite. The answer is (2).'), findsOneWidget);
    expect(find.text('150 × 0.2 = 30.'), findsOneWidget);
    expect(find.text('0 correct of 1 answered'), findsOneWidget);
    await next(tester);

    // 2. Typed in, compared by value.
    await tester.enterText(find.widgetWithText(TextField, 'Your answer'), '30.0');
    await tester.tap(find.text('Check'));
    await tester.pumpAndSettle();
    expect(find.text('Correct.'), findsOneWidget);
    expect(find.text('1 correct of 2 answered'), findsOneWidget);
    await next(tester);

    // 3. Written: the paper's answer on request, and an AI check with it.
    expect(find.text('Check with AI'), findsOneWidget);
    await tester.tap(find.text('Show the answer from the paper'));
    await tester.pumpAndSettle();
    expect(find.text('It unwraps an optional with if let.'), findsOneWidget);
    await tester.enterText(find.widgetWithText(TextField, 'Your answer'), 'It unwraps it');
    await tester.pump();
    await tester.tap(find.text('Check with AI'));
    await tester.pumpAndSettle();

    expect(ai.calls, ['check:q3:It unwraps it']);
    expect(find.text('AI-generated · not checked'), findsOneWidget);
    expect(find.text('Your answer is partly right.'), findsOneWidget);
    expect(find.text('30 rupees'), findsOneWidget);
    expect(find.text("The AI's answer matches the one in your paper."), findsOneWidget);
    expect(
      find.text('Checked by AI (fake-model), not by a person. It can be wrong.'),
      findsOneWidget,
    );
  });

  testAppWidgets('without AI, written answers are compared with the paper only', (
    tester,
    db,
  ) async {
    final (_, ai) = await openPaper(tester, db, ai: false);
    await tester.tap(find.text('Solve this paper'));
    await tester.pumpAndSettle();
    await next(tester);
    await next(tester);

    expect(find.text('Explain optional binding.'), findsOneWidget);
    expect(find.text('Check with AI'), findsNothing);
    expect(find.text('Show the answer from the paper'), findsOneWidget);
    expect(ai.calls, isEmpty);
  });

  testAppWidgets('an AI check that disagrees with the paper says so', (tester, db) async {
    final (_, ai) = await openPaper(tester, db);
    ai.answerCheckResult = const AnswerCheck(
      verdict: AnswerVerdict.correct,
      feedback: 'Right.',
      idealAnswer: 'With if let or guard let.',
      paperAnswer: 'It unwraps an optional with if let.',
      paperAgrees: false,
      confident: false,
      model: 'fake-model',
    );
    await tester.tap(find.text('Solve this paper'));
    await tester.pumpAndSettle();
    await next(tester);
    await next(tester);
    await tester.enterText(find.widgetWithText(TextField, 'Your answer'), 'if let');
    await tester.pump();
    await tester.tap(find.text('Check with AI'));
    await tester.pumpAndSettle();

    expect(
      find.text("The AI's answer differs from the one in your paper. Check your book or notes."),
      findsOneWidget,
    );
    expect(find.text("The AI wasn't sure about this one."), findsOneWidget);
  });
}
