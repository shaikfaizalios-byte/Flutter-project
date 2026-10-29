import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:preploop/app/routes.dart';
import 'package:preploop/core/database/app_database.dart';
import 'package:preploop/core/errors/app_failure.dart';
import 'package:preploop/features/documents/presentation/documents_screen.dart';
import 'package:preploop/features/learn/domain/quiz_rules.dart';
import 'package:preploop/features/learn/presentation/topic_lesson_screen.dart';
import 'package:preploop/features/learn/presentation/topic_quiz_screen.dart';

import '../../helpers/pump_app.dart';

Future<FakeAiRepository> openHome(
  WidgetTester tester,
  AppDatabase db, {
  bool enabled = true,
  bool requiresPlus = false,
}) async {
  final ai = FakeAiRepository(enabled: enabled, requiresPlus: requiresPlus);
  await pumpPrepLoopApp(
    tester,
    db,
    ai: ai,
    studyProfile: onboardedProfile.copyWith(examCodes: ['SSC_CHSL']),
  );
  await scrollTo(tester, find.text('How do you want to start?'));
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

void main() {
  test('quiz verdict follows the stated thresholds', () {
    expect(quizVerdict(4, 5), QuizVerdict.knowsIt);
    expect(quizVerdict(3, 5), QuizVerdict.partly);
    expect(quizVerdict(2, 5), QuizVerdict.learnFirst);
    expect(quizVerdict(0, 0), QuizVerdict.learnFirst);
  });

  testAppWidgets('Home offers three ways to start; a paper opens the importer', (tester, db) async {
    await openHome(tester, db);

    expect(find.text("I'm new to a topic: teach me first"), findsOneWidget);
    expect(find.text('I know a topic: test my knowledge'), findsOneWidget);
    await tester.tap(find.text('Analyse a previous year paper'));
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

  testAppWidgets('a knowledge check is marked on the device with explanations', (tester, db) async {
    final ai = await openHome(tester, db);
    push(tester, AppRoutes.topicQuiz('Percentage', subject: 'Maths'));
    await tester.pumpAndSettle();

    expect(find.text('Question 1 of 3'), findsOneWidget);
    await tester.tap(find.text('A1'));
    await tester.pumpAndSettle();
    expect(find.text('Not quite. The answer is B.'), findsOneWidget);
    expect(find.text('Because B1.'), findsOneWidget);
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
      ..quizCount = 1
      ..failure = const ServerFailure(code: 'ai_unavailable', statusCode: 502);
    push(tester, AppRoutes.topicQuiz('Ratio'));
    await tester.pumpAndSettle();

    expect(find.text('Try again'), findsOneWidget);
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();
    await answer(tester, 'B1', last: true);

    expect(find.text('1 of 1 correct'), findsOneWidget);
    expect(find.textContaining('You know this topic well.'), findsOneWidget);
    expect(find.text('Learn this topic'), findsNothing);
    expect(ai.calls, hasLength(2));
  });
}
