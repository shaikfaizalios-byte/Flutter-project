import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:preploop/app/app_features.dart';
import 'package:preploop/app/routes.dart';
import 'package:preploop/core/database/app_database.dart';
import 'package:preploop/core/errors/app_failure.dart';
import 'package:preploop/features/concepts/presentation/concept_form_screen.dart';
import 'package:preploop/features/documents/presentation/documents_screen.dart';
import 'package:preploop/features/learn/domain/quiz_rules.dart';
import 'package:preploop/features/learn/presentation/topic_lesson_screen.dart';
import 'package:preploop/features/learn/presentation/topic_quiz_screen.dart';

import '../../helpers/pump_app.dart';

final learnOn = appFeaturesProvider.overrideWithValue(const AppFeatures(learnStart: true));

Future<FakeAiRepository> openHome(
  WidgetTester tester,
  AppDatabase db, {
  bool enabled = true,
  bool requiresPlus = false,
  bool featureOn = true,
}) async {
  final ai = FakeAiRepository(enabled: enabled, requiresPlus: requiresPlus);
  await pumpPrepLoopApp(
    tester,
    db,
    ai: ai,
    studyProfile: onboardedProfile.copyWith(examCodes: ['SSC_CHSL']),
    extraOverrides: [if (featureOn) learnOn],
  );
  if (featureOn) await scrollTo(tester, find.text('How do you want to start?'));
  return ai;
}

void push(WidgetTester tester, String location) =>
    GoRouter.of(tester.element(find.byType(Scaffold).first)).push(location);

Future<void> typeTopic(WidgetTester tester, String topic) async {
  await tester.enterText(find.widgetWithText(TextField, 'Or type a topic'), topic);
  await tester.pump();
  await tester.tap(find.widgetWithText(FilledButton, 'Continue'));
  await tester.pumpAndSettle();
}

Future<void> answer(WidgetTester tester, String option, {required bool last}) async {
  await tester.tap(find.text(option));
  await tester.pumpAndSettle();
  await scrollWithin(tester, TopicQuizScreen, find.text(last ? 'See my result' : 'Next'));
  await tester.tap(find.text(last ? 'See my result' : 'Next'));
  await tester.pumpAndSettle();
}

const keyCaveat =
    'The AI chose this answer and no one has checked it. If it looks wrong, trust your book.';

void main() {
  test('quiz verdict follows the stated thresholds and needs enough questions', () {
    expect(quizVerdict(4, 5), QuizVerdict.knowsIt);
    expect(quizVerdict(3, 5), QuizVerdict.partly);
    expect(quizVerdict(2, 5), QuizVerdict.learnFirst);
    expect(quizVerdict(3, 3), QuizVerdict.knowsIt);
    expect(quizVerdict(2, 2), QuizVerdict.tooFew);
    expect(quizVerdict(1, 1), QuizVerdict.tooFew);
    expect(quizVerdict(0, 0), QuizVerdict.tooFew);
  });

  testAppWidgets('while the feature is off, nothing of it shows or opens', (tester, db) async {
    final ai = await openHome(tester, db, featureOn: false);

    expect(find.text('How do you want to start?'), findsNothing);
    push(tester, AppRoutes.topicLesson('Percentage'));
    await tester.pumpAndSettle();
    push(tester, AppRoutes.topicQuiz('Percentage'));
    await tester.pumpAndSettle();

    expect(find.byType(TopicLessonScreen), findsNothing);
    expect(find.byType(TopicQuizScreen), findsNothing);
    expect(ai.calls, isEmpty);
  });

  testAppWidgets('Home offers three ways to start; a paper opens the importer', (tester, db) async {
    await openHome(tester, db);

    expect(find.text("I'm new to a topic: teach me first"), findsOneWidget);
    expect(find.text('I know a topic: test my knowledge'), findsOneWidget);
    await tester.tap(find.text('Import a previous year paper'));
    await tester.pumpAndSettle();

    expect(find.byType(DocumentsScreen), findsOneWidget);
  });

  testAppWidgets('without AI, learning and checking are shown as unavailable', (tester, db) async {
    final ai = await openHome(tester, db, enabled: false);

    expect(find.text("Needs AI help, which isn't available right now."), findsNWidgets(2));
    await tester.tap(find.text("I'm new to a topic: teach me first"));
    await tester.pumpAndSettle();
    expect(find.text('Choose a topic'), findsNothing);
    expect(ai.calls, isEmpty);
  });

  testAppWidgets('without Plus, the Plus prompt is shown instead', (tester, db) async {
    await openHome(tester, db, requiresPlus: true);

    expect(
      find.text('Lessons and knowledge checks use AI, which is part of PrepLoop Plus.'),
      findsOneWidget,
    );
  });

  testAppWidgets('a typed topic gets a labelled lesson, then a check', (tester, db) async {
    final ai = await openHome(tester, db);

    await tester.tap(find.text("I'm new to a topic: teach me first"));
    await tester.pumpAndSettle();
    await typeTopic(tester, 'Percentage');

    expect(find.byType(TopicLessonScreen), findsOneWidget);
    expect(find.text('Learn: Percentage'), findsOneWidget);
    expect(find.text('AI-generated · not checked'), findsOneWidget);
    expect(find.text('Percentage means per hundred.'), findsOneWidget);
    expect(find.text('20/100 × 150 = 30'), findsNothing); // answer hidden until asked
    await scrollWithin(tester, TopicLessonScreen, find.text('Show the answer'));
    await tester.tap(find.text('Show the answer'));
    await tester.pumpAndSettle();
    expect(find.text('20/100 × 150 = 30'), findsOneWidget);
    expect(ai.calls, ['lesson:Percentage:null:SSC_CHSL:en']);

    await scrollWithin(tester, TopicLessonScreen, find.text('Test my knowledge'));
    await tester.tap(find.text('Test my knowledge'));
    await tester.pumpAndSettle();
    expect(find.text('Test: Percentage'), findsOneWidget);
    expect(ai.calls.last, 'quiz:Percentage:null:SSC_CHSL:en');
  });

  testAppWidgets('a lesson saved as a concept keeps its AI label', (tester, db) async {
    await openHome(tester, db);
    push(tester, AppRoutes.topicLesson('Percentage', subject: 'Maths'));
    await tester.pumpAndSettle();

    await scrollWithin(tester, TopicLessonScreen, find.text('Save as a concept'));
    await tester.tap(find.text('Save as a concept'));
    await tester.pumpAndSettle();

    final form = find.byType(ConceptFormScreen);
    expect(form, findsOneWidget);
    Future<String> field(String label) async {
      final input = find.widgetWithText(TextField, label);
      await scrollWithin(tester, ConceptFormScreen, input);
      return tester.widget<TextField>(input).controller!.text;
    }

    // The AI tag isn't offered for editing; the form says it always stays.
    expect(await field('Tags (optional)'), '');
    expect(
      find.text('Made from an AI lesson: it always stays labelled as AI-generated.'),
      findsOneWidget,
    );
    expect(await field('Source (optional)'), 'AI lesson (fake-model), not checked');
    expect(await field('Notes (optional)'), startsWith('[AI-generated · not checked]'));
  });

  testAppWidgets('a lesson the AI was unsure about cannot be saved', (tester, db) async {
    final ai = await openHome(tester, db);
    ai.confident = false;
    push(tester, AppRoutes.topicLesson('Percentage'));
    await tester.pumpAndSettle();

    expect(find.textContaining("The AI wasn't sure"), findsOneWidget);
    await scrollWithin(tester, TopicLessonScreen, find.text('Test my knowledge'));
    expect(find.text('Save as a concept'), findsNothing);
  });

  testAppWidgets('a knowledge check is marked on the device with labelled questions', (
    tester,
    db,
  ) async {
    final ai = await openHome(tester, db);
    push(tester, AppRoutes.topicQuiz('Percentage', subject: 'Maths'));
    await tester.pumpAndSettle();

    expect(find.text('Question 1 of 3'), findsOneWidget);
    expect(find.text('AI question · not from a paper'), findsOneWidget);
    await tester.tap(find.text('A1'));
    await tester.pumpAndSettle();
    expect(find.text('Not quite. The answer is B.'), findsOneWidget);
    expect(find.text('Because B1.'), findsOneWidget);
    expect(find.text(keyCaveat), findsOneWidget);
    await tester.tap(find.text('A1')); // locked once answered
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();

    await answer(tester, 'B2', last: false);
    await answer(tester, 'B3', last: true);

    expect(find.text('2 of 3 correct'), findsOneWidget);
    expect(find.textContaining('You know parts of it.'), findsOneWidget);
    expect(ai.calls, ['quiz:Percentage:Maths:SSC_CHSL:en']);

    await tester.tap(find.text('New questions'));
    await tester.pumpAndSettle();
    expect(find.text('Question 1 of 3'), findsOneWidget);
    expect(ai.calls, hasLength(2));
  });

  testAppWidgets('a full score suggests practice; a failed request can be retried', (
    tester,
    db,
  ) async {
    final ai = await openHome(tester, db)
      ..failure = const ServerFailure(code: 'ai_unavailable', statusCode: 502);
    push(tester, AppRoutes.topicQuiz('Ratio'));
    await tester.pumpAndSettle();

    expect(find.text('Try again'), findsOneWidget);
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();
    await answer(tester, 'B1', last: false);
    await answer(tester, 'B2', last: false);
    await answer(tester, 'B3', last: true);

    expect(find.text('3 of 3 correct'), findsOneWidget);
    expect(find.textContaining('You know this topic well.'), findsOneWidget);
    expect(find.text('Learn this topic'), findsNothing);
    expect(ai.calls, hasLength(2));
  });

  testAppWidgets('too few questions give no verdict', (tester, db) async {
    final ai = await openHome(tester, db);
    ai.quizCount = 1;
    push(tester, AppRoutes.topicQuiz('Ratio'));
    await tester.pumpAndSettle();
    await answer(tester, 'B1', last: true);

    expect(find.text('1 of 1 correct'), findsOneWidget);
    expect(find.text('Too few questions to judge this topic. Try new questions.'), findsOneWidget);
    expect(find.textContaining('You know this topic well.'), findsNothing);
  });
}
