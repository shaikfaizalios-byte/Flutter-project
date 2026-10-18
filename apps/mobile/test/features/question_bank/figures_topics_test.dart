import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:preploop/features/ai/data/ai_repository.dart';
import 'package:preploop/features/documents/application/documents_providers.dart';
import 'package:preploop/features/question_bank/domain/question.dart';
import 'package:preploop/features/question_bank/presentation/figure_view.dart';

import '../../helpers/pump_app.dart';
import '../documents/documents_screen_test.dart' show FakeDocumentsRepository, doc;
import '../practice/practice_flow_test.dart' show pumpPractice, startPractice;
import 'question_bank_test.dart' show openPractice, openQuestion;

const stemFigure = QuestionFigure(
  id: 'f-stem',
  kind: FigureKind.stem,
  pageNumber: 3,
  width: 400,
  height: 200,
);
const optionFigureA = QuestionFigure(
  id: 'f-opt1',
  kind: FigureKind.option,
  optionPosition: 1,
  pageNumber: 3,
  width: 120,
  height: 120,
);

BankQuestion vennQuestion({VerificationStatus status = VerificationStatus.unverified}) =>
    bankQuestion(
      id: 'venn',
      number: 7,
      stem: 'Select the Venn diagram that best represents the relationship.',
      section: 'General Intelligence',
      options: const ['', 'Two circles', 'Three circles', 'Nested'],
      status: status,
      figures: const [stemFigure, optionFigureA],
      topicStatus: 'suggested',
      topic: const TopicRef(id: 't-venn', subject: 'General Intelligence', name: 'Venn Diagrams'),
      topicSuggestedBy: 'keywords',
      topicSuggestionReason: 'Matched "venn diagram"',
    );

ParseSummary paperSummary({int suggested = 3, int unassigned = 2, int aiPending = 2}) =>
    ParseSummary(
      segmentationStatus: 'completed',
      questionsFound: 5,
      verified: 0,
      rejected: 0,
      withOpenIssues: 1,
      missingAnswers: 0,
      imageDependent: 1,
      withFigures: 1,
      unreadableText: 1,
      topicsSuggested: suggested,
      topicsUnassigned: unassigned,
      topicsAiPending: aiPending,
      sections: const ['General Intelligence'],
      documentIssues: const [],
    );

Future<void> openPaperReview(WidgetTester tester) async {
  await tester.tap(find.descendant(of: find.byType(NavigationBar), matching: find.text('Study')));
  await tester.pumpAndSettle();
  await tester.tap(find.byTooltip('Imported papers'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('chsl-2024.pdf'));
  await tester.pumpAndSettle();
}

FakeDocumentsRepository paperDocs() => FakeDocumentsRepository()
  ..listResponses = [
    [doc(id: 'doc1', filename: 'chsl-2024.pdf')],
  ];

void main() {
  testAppWidgets('review shows figures from the paper and why a topic was suggested', (
    tester,
    db,
  ) async {
    final repo = FakeQuestionsRepository([vennQuestion()]);
    await pumpPrepLoopApp(tester, db, questions: repo);
    await openPractice(tester);
    await openQuestion(tester, 'Q.7');

    expect(find.text('Figures from the paper (shown as printed)'), findsOneWidget);
    expect(find.bySemanticsLabel('Figure from the paper (page 3)'), findsOneWidget);
    // The option figure sits under its option, further down.
    await scrollTo(tester, find.bySemanticsLabel('Option figure from the paper (page 3)'));
    expect(find.bySemanticsLabel('Option figure from the paper (page 3)'), findsOneWidget);
    expect(repo.figureRequests, containsAll([('venn', 'f-stem'), ('venn', 'f-opt1')]));
    await tester.drag(find.byType(ListView).first, const Offset(0, 2000));
    await tester.pumpAndSettle();

    // A figure opens a zoomable view.
    await tester.tap(
      find.descendant(of: find.byType(QuestionFigureView).first, matching: find.byType(Image)),
    );
    await tester.pumpAndSettle();
    expect(find.byType(InteractiveViewer), findsOneWidget);
    await tester.tap(find.byTooltip('Close'));
    await tester.pumpAndSettle();
    expect(find.byType(InteractiveViewer), findsNothing);

    await scrollTo(tester, find.textContaining('Why: Matched "venn diagram"'));
    expect(find.textContaining('Why: Matched "venn diagram"'), findsOneWidget);
  });

  testAppWidgets('paper review: accept all suggested topics after confirming', (tester, db) async {
    final repo = FakeQuestionsRepository([vennQuestion()])..summary = paperSummary();
    await pumpPrepLoopApp(
      tester,
      db,
      questions: repo,
      extraOverrides: [documentsRepositoryProvider.overrideWithValue(paperDocs())],
    );
    await openPaperReview(tester);

    expect(find.text('1 with figures'), findsOneWidget);
    expect(find.text('1 with unreadable text'), findsOneWidget);
    expect(find.text('3 suggested · 2 without a topic'), findsOneWidget);
    // AI is off by default: no AI action is offered.
    expect(find.textContaining('Suggest topics with AI'), findsNothing);

    await scrollTo(tester, find.text('Accept all suggestions (3)'));
    await tester.tap(find.text('Accept all suggestions (3)'));
    await tester.pumpAndSettle();
    expect(find.text('Accept all suggestions?'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(repo.acceptCalls, isEmpty);

    await tester.tap(find.text('Accept all suggestions (3)'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Accept all'));
    await tester.pumpAndSettle();
    expect(repo.acceptCalls, ['doc1']);
    expect(repo.questions['venn']!.topicStatus, 'confirmed');
    expect(find.text('1 topics and 0 question types accepted.'), findsOneWidget);
  });

  testAppWidgets('paper review: AI topic suggestion runs until nothing is left', (
    tester,
    db,
  ) async {
    final repo = FakeQuestionsRepository([vennQuestion()])..summary = paperSummary(aiPending: 30);
    final ai = FakeAiRepository(enabled: true, questions: repo)
      ..paperSteps = const [
        PaperTopicsResult(considered: 20, suggested: 15, noMatch: 5, remaining: 10),
        PaperTopicsResult(considered: 10, suggested: 8, noMatch: 2, remaining: 0),
      ];
    await pumpPrepLoopApp(
      tester,
      db,
      questions: repo,
      ai: ai,
      extraOverrides: [documentsRepositoryProvider.overrideWithValue(paperDocs())],
    );
    await openPaperReview(tester);

    await scrollTo(tester, find.text('Suggest topics with AI (30 questions)'));
    await tester.tap(find.text('Suggest topics with AI (30 questions)'));
    await tester.pumpAndSettle();
    // The learner is told that question text goes to the AI service.
    expect(find.textContaining('sent to the AI service'), findsOneWidget);
    await tester.tap(find.text('Send to AI'));
    await tester.pumpAndSettle();

    expect(ai.calls.where((c) => c == 'paper-topics:doc1'), hasLength(2));
    expect(find.text('AI suggested 23 topics. 7 questions had no match.'), findsOneWidget);
  });

  testAppWidgets('practice shows question and option figures', (tester, db) async {
    await pumpPractice(tester, db, pool: [vennQuestion(status: VerificationStatus.verified)]);
    await startPractice(tester);

    expect(find.bySemanticsLabel('Figure from the paper (page 3)'), findsOneWidget);
    final figures = find.byType(QuestionFigureView);
    expect(figures, findsNWidgets(2));
    expect(tester.widget<QuestionFigureView>(figures.last).figure.kind, FigureKind.option);

    // Tapping an option's figure selects that option (no zoom inside answers).
    final optionImage = find.descendant(of: figures.last, matching: find.byType(Image));
    await tester.ensureVisible(optionImage);
    await tester.pumpAndSettle();
    await tester.tap(optionImage);
    await tester.pumpAndSettle();
    expect(find.byType(InteractiveViewer), findsNothing);
    expect(find.text('Correct answer: (2)'), findsOneWidget);
  });
}
