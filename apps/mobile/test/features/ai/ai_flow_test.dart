import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:preploop/app/routes.dart';
import 'package:preploop/core/database/app_database.dart';
import 'package:preploop/core/errors/app_failure.dart';
import 'package:preploop/features/ai/data/ai_repository.dart';
import 'package:preploop/features/concepts/data/local_concepts_repository.dart';
import 'package:preploop/features/concepts/domain/concept.dart';
import 'package:preploop/features/question_bank/domain/question.dart';
import 'package:preploop/features/question_bank/presentation/question_review_screen.dart';

import '../../helpers/pump_app.dart';

void push(WidgetTester tester, String location) =>
    GoRouter.of(tester.element(find.byType(Scaffold).first)).push(location);

/// A reviewed question from a paper, without an explanation.
BankQuestion verifiedNoExplanation({String id = 'q1'}) =>
    bankQuestion(id: id, status: VerificationStatus.verified, subject: 'Quantitative Aptitude');

Future<(FakeAiRepository, FakeQuestionsRepository)> openReview(
  WidgetTester tester,
  AppDatabase db,
  BankQuestion question, {
  bool enabled = true,
  Locale? locale,
}) async {
  final questions = FakeQuestionsRepository([question]);
  final ai = FakeAiRepository(enabled: enabled, questions: questions);
  await pumpPrepLoopApp(tester, db, questions: questions, ai: ai, deviceLocale: locale);
  push(tester, AppRoutes.question(question.id));
  await tester.pumpAndSettle();
  return (ai, questions);
}

Future<void> scrollToText(WidgetTester tester, String text) =>
    scrollWithin(tester, QuestionReviewScreen, find.text(text));

void main() {
  testAppWidgets('without AI on the server, no AI actions are offered', (tester, db) async {
    await openReview(tester, db, verifiedNoExplanation(), enabled: false);

    expect(find.text('AI assistance'), findsNothing);
    expect(find.text('Draft an explanation with AI'), findsNothing);
  });

  testAppWidgets('explanation draft is labelled, reviewed and approved', (tester, db) async {
    final (ai, questions) = await openReview(tester, db, verifiedNoExplanation());

    await scrollToText(tester, 'Draft an explanation with AI');
    await tester.tap(find.text('Draft an explanation with AI'));
    await tester.pumpAndSettle();

    expect(find.text('AI-generated draft, not reviewed'), findsOneWidget);
    expect(find.text('AI: 20/100 × 150 = 30.'), findsOneWidget);
    expect(questions.questions['q1']!.explanation, isNull); // source text untouched

    await scrollToText(tester, 'Approve');
    await tester.tap(find.widgetWithText(FilledButton, 'Approve').first);
    await tester.pumpAndSettle();

    expect(ai.calls, ['draft:q1', 'approve:e-q1']);
    expect(find.text('AI-generated explanation (approved)'), findsOneWidget);
  });

  testAppWidgets('a draft the AI was unsure about carries a warning', (tester, db) async {
    await openReview(
      tester,
      db,
      bankQuestion(
        status: VerificationStatus.verified,
        aiExplanation: const AiExplanation(
          id: 'e-q1',
          questionId: 'q1',
          text: 'Maybe 30.',
          status: AiDraftStatus.draft,
          modelConfident: false,
          model: 'fake-model',
        ),
      ),
    );

    await scrollToText(tester, 'Maybe 30.');
    expect(find.textContaining('The AI was not sure'), findsOneWidget);
  });

  testAppWidgets('AI can only work from reviewed questions', (tester, db) async {
    await openReview(tester, db, bankQuestion(subject: 'Quantitative Aptitude'));

    await scrollToText(tester, 'AI assistance');
    expect(find.text('Draft an explanation with AI'), findsNothing);
    expect(find.text('Generate similar practice questions'), findsNothing);
    expect(find.textContaining('Approve this question first'), findsOneWidget);
  });

  testAppWidgets('topic suggestion is labelled as coming from AI', (tester, db) async {
    final (ai, _) = await openReview(tester, db, verifiedNoExplanation());

    await scrollToText(tester, 'Suggest a topic with AI');
    await tester.tap(find.text('Suggest a topic with AI'));
    await tester.pumpAndSettle();

    expect(ai.calls, ['topic:q1']);
    await scrollToText(tester, 'Suggested by AI. Confirm or change it.');
  });

  testAppWidgets('similar questions are generated for review, with rejections reported', (
    tester,
    db,
  ) async {
    final (ai, _) = await openReview(tester, db, verifiedNoExplanation());
    ai.rejectedCount = 1;

    await scrollToText(tester, 'Generate similar practice questions');
    await tester.tap(find.text('Generate similar practice questions'));
    await tester.pumpAndSettle();
    expect(find.textContaining('never count as previous-year questions'), findsOneWidget);
    await tester.tap(find.text('5'));
    await tester.tap(find.text('हिन्दी'));
    await tester.tap(find.text('Generate'));
    await tester.pumpAndSettle();

    expect(ai.generatedFor.single, ('question:q1', ContentLanguage.hindi, 5));
    expect(
      find.text(
        '2 AI questions added to the question bank for review. 1 was rejected by the checks.',
      ),
      findsOneWidget,
    );
  });

  testAppWidgets('AI failures are explained', (tester, db) async {
    final (ai, _) = await openReview(tester, db, verifiedNoExplanation());
    ai.failure = const ServerFailure(statusCode: 502, code: 'ai_unavailable');

    await scrollToText(tester, 'Draft an explanation with AI');
    await tester.tap(find.text('Draft an explanation with AI'));
    await tester.pumpAndSettle();

    expect(find.textContaining('The AI service is not available right now'), findsOneWidget);
  });

  testAppWidgets('concept notes can become AI questions after a clear notice', (tester, db) async {
    final concept = await seed(
      tester,
      () => LocalConceptsRepository(db, clock: () => testNow).create(
        const ConceptDraft(
          examCode: 'SSC_CGL',
          title: 'Percent change',
          notes: 'new − old ÷ old',
          subject: 'Quantitative Aptitude',
          topic: 'Percentage',
          language: ContentLanguage.english,
        ),
      ),
    );
    final ai = FakeAiRepository(enabled: true);
    await pumpPrepLoopApp(tester, db, ai: ai);
    push(tester, AppRoutes.concept(concept.id));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Practice questions from my notes (AI)'));
    await tester.pumpAndSettle();
    expect(find.textContaining('your notes are sent to the AI service'), findsOneWidget);
    await tester.tap(find.text('Generate'));
    await tester.pumpAndSettle();

    expect(ai.generatedFor.single, ('concept:Percent change', ContentLanguage.english, 3));
    expect(find.textContaining('2 AI questions added'), findsOneWidget);
  });

  testAppWidgets('AI questions and explanations are labelled during practice', (tester, db) async {
    final practice = FakePracticeRepository(
      serverNow: () => testNow,
      pool: [bankQuestion(origin: QuestionOrigin.ai, documentId: null)],
    );
    await pumpPrepLoopApp(tester, db, practice: practice);
    await tester.tap(
      find.descendant(of: find.byType(NavigationBar), matching: find.byIcon(Icons.quiz_outlined)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Start practice'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Include AI-generated questions'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Start practice').last);
    await tester.pumpAndSettle();

    expect(practice.practiceRequests.single.includeAi, isTrue);
    expect(find.text('AI-generated'), findsOneWidget);
    await tester.tap(find.text('30'));
    await tester.pumpAndSettle();
    expect(find.text('AI-generated explanation'), findsOneWidget);
  });

  testAppWidgets('a learner can report a question from a session', (tester, db) async {
    final ai = FakeAiRepository();
    await pumpPrepLoopApp(tester, db, ai: ai);
    await tester.tap(
      find.descendant(of: find.byType(NavigationBar), matching: find.byIcon(Icons.quiz_outlined)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Start practice'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Start practice').last);
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Report a problem'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('The question is unclear'));
    await tester.enterText(find.byType(TextField), 'Two answers fit');
    await tester.tap(find.text('Send report'));
    await tester.pumpAndSettle();

    expect(ai.reports.single, ('q1', ReportReason.unclear, 'Two answers fit'));
    expect(find.text('Thanks. The question goes back for review.'), findsOneWidget);
  });

  testAppWidgets('AI assistance is localised in Hindi', (tester, db) async {
    await openReview(tester, db, verifiedNoExplanation(), locale: const Locale('hi'));

    await scrollToText(tester, 'AI सहायता');
    expect(find.text('AI से व्याख्या का मसौदा बनाएँ'), findsOneWidget);
  });
}
