import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:preploop/core/database/app_database.dart';
import 'package:preploop/core/errors/app_failure.dart';
import 'package:preploop/features/ladder/application/ladder_providers.dart';
import 'package:preploop/features/ladder/domain/ladder_models.dart';
import 'package:preploop/features/ladder/presentation/ladder_card.dart';
import 'package:preploop/features/ladder/presentation/ladder_icon.dart';
import 'package:preploop/features/ladder/presentation/ladder_screen.dart';
import 'package:preploop/features/ladder/presentation/ladder_topics_screen.dart';

import '../../helpers/pump_app.dart';

const topics = [
  LadderTopic(topicId: 't1', name: 'Percentage', subject: 'Quantitative Aptitude', papers: 6),
  LadderTopic(topicId: 't2', name: 'Ratio', subject: 'Quantitative Aptitude', papers: 4),
  LadderTopic(topicId: 't3', name: 'Average', subject: 'Quantitative Aptitude', papers: 2),
  LadderTopic(topicId: 't4', name: 'Algebra', subject: 'Quantitative Aptitude', papers: 1),
  LadderTopic(topicId: 't5', name: 'Polity', subject: 'General Awareness'),
];

Future<FakeLadderRepository> pumpLadder(
  WidgetTester tester,
  AppDatabase db, {
  bool aiOn = true,
  bool needsPlus = false,
  LadderBest? best,
}) async {
  final ladder = FakeLadderRepository(
    data: LadderOverview(topics: topics, best: best),
  );
  await pumpPrepLoopApp(
    tester,
    db,
    ai: FakeAiRepository(enabled: aiOn, requiresPlus: needsPlus),
    ladder: ladder,
    studyProfile: onboardedProfile.copyWith(examCodes: ['SSC_CHSL']),
  );
  return ladder;
}

Future<void> openPercentage(WidgetTester tester) async {
  await scrollTo(tester, find.byType(LadderCard));
  await tester.ensureVisible(find.widgetWithText(ActionChip, 'Percentage'));
  await tester.pumpAndSettle();
  await tester.tap(find.widgetWithText(ActionChip, 'Percentage'));
  await tester.pumpAndSettle();
}

Future<void> startClimbing(WidgetTester tester) async {
  await tester.ensureVisible(find.text('Start climbing'));
  await tester.tap(find.text('Start climbing'));
  await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
  await tester.pumpAndSettle();
  if (find.text('Continue').evaluate().isNotEmpty) {
    await tester.tap(find.text('Continue'));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await tester.pumpAndSettle();
  }
}

Future<void> answerStep(WidgetTester tester, String option, String button) async {
  await tester.ensureVisible(find.text(option));
  await tester.pumpAndSettle();
  await tester.tap(find.text(option));
  await tester.pumpAndSettle();
  await tester.ensureVisible(find.text(button));
  await tester.pumpAndSettle();
  await tester.tap(find.text(button));
  await tester.pumpAndSettle();
}

Future<void> climbAll(WidgetTester tester, {String option = '20'}) async {
  for (var i = 0; i < 4; i++) {
    await answerStep(tester, option, 'Next step');
  }
  await answerStep(tester, option, 'See results');
}

void main() {
  test('a round is summed up per question type', () {
    const round = LadderRound(
      sessionId: 's',
      roundNumber: 1,
      topicName: 'T',
      subject: 'S',
      sourceMix: LadderSourceMix.papers,
      steps: [
        LadderStep(
          roundNumber: 1,
          step: 1,
          difficulty: LadderDifficulty.easy,
          ready: true,
          modelName: 'A',
          result: LadderResult(
            selectedIndex: 1,
            correct: true,
            answerIndex: 1,
            solution: [],
            shortcut: '',
            timeSpentMs: 30000,
          ),
        ),
        LadderStep(
          roundNumber: 1,
          step: 2,
          difficulty: LadderDifficulty.easy,
          ready: true,
          modelName: 'A',
          result: LadderResult(
            selectedIndex: 0,
            correct: false,
            answerIndex: 1,
            solution: [],
            shortcut: '',
          ),
        ),
      ],
    );
    final summary = LadderSummary.of(round);
    expect((summary.correct, summary.total), (1, 2));
    expect(summary.timeSpent, const Duration(seconds: 30));
    expect(summary.byModel['A'], (1, 2));
  });

  test('the overview offers up to three topics seen in papers', () {
    const overview = LadderOverview(topics: topics);
    expect([for (final t in overview.repeated) t.name], ['Percentage', 'Ratio', 'Average']);
    expect(LadderOverview(topics: [topics.last]).repeated, isEmpty);
  });

  test('the icon draws at any size and step colours rise from green to red', () {
    expect(ladderStepColors, hasLength(5));
    expect(ladderStepColors[0], ladderStepColors[1]);
    final old = const LadderIconPainter(progress: 0.2, dim: Colors.grey);
    expect(const LadderIconPainter(progress: 0.3, dim: Colors.grey).shouldRepaint(old), isTrue);
  });

  testAppWidgets('Home offers repeated topics, any topic, and only the learner\'s own best', (
    tester,
    db,
  ) async {
    await pumpLadder(tester, db, best: const LadderBest(step: 4, topicName: 'Percentage'));

    await scrollTo(tester, find.byType(LadderCard));
    await tester.ensureVisible(find.text('Challenge Ladder'));
    expect(find.text('5 questions. Each one harder. How high can you climb?'), findsOneWidget);
    expect(find.text('Your best: step 4 in Percentage'), findsOneWidget);
    expect(find.widgetWithText(ActionChip, 'Average'), findsOneWidget);
    expect(find.widgetWithText(ActionChip, 'Algebra'), findsNothing); // three at most
    expect(find.widgetWithText(ActionChip, 'Any topic'), findsOneWidget);
  });

  testAppWidgets('any topic: a searchable list with repeated topics first', (tester, db) async {
    await pumpLadder(tester, db);
    await scrollTo(tester, find.byType(LadderCard));
    await tester.ensureVisible(find.widgetWithText(ActionChip, 'Any topic'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ActionChip, 'Any topic'));
    await tester.pumpAndSettle();

    expect(find.byType(LadderTopicsScreen), findsOneWidget);
    expect(find.textContaining('in 6 of your papers'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'pol');
    await tester.pumpAndSettle();
    expect(find.text('Polity'), findsOneWidget);
    expect(find.text('Ratio'), findsNothing);
    await tester.tap(find.text('Polity'));
    await tester.pumpAndSettle();
    expect(find.byType(LadderScreen), findsOneWidget);
    expect(find.textContaining('web references only'), findsOneWidget); // no papers on it
  });

  testAppWidgets('consent comes first; declining sends nothing', (tester, db) async {
    final ladder = await pumpLadder(tester, db);
    await openPercentage(tester);

    expect(find.textContaining('Not past-paper questions'), findsOneWidget);
    await tester.ensureVisible(find.text('Start climbing'));
    await tester.tap(find.text('Start climbing'));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await tester.pumpAndSettle();
    expect(find.textContaining('sent to an AI service'), findsOneWidget);
    await tester.tap(find.text('Not now'));
    await tester.pumpAndSettle();
    expect(ladder.calls.where((c) => c.startsWith('start')), isEmpty);
  });

  testAppWidgets('a whole climb: steps, labels, feedback, results and test me more', (
    tester,
    db,
  ) async {
    final ladder = await pumpLadder(tester, db)
      ..paperStep = 3;
    await openPercentage(tester);
    await startClimbing(tester);

    expect(ladder.calls, contains('start:SSC_CHSL:t1:en'));
    expect(ladder.calls.where((c) => c.startsWith('generate:1:')), hasLength(5));
    expect(find.text('Step 1 of 5 · Easy'), findsOneWidget);
    expect(find.text('Income'), findsOneWidget);
    expect(find.text('Pattern seen in 4 of your papers'), findsOneWidget);
    expect(find.text('Timer (target 60 s)'), findsOneWidget);

    await tester.tap(find.text('20'));
    await tester.pumpAndSettle();
    expect(find.text('Right'), findsOneWidget);
    expect(find.text('1. 20 is the answer.'), findsOneWidget);
    expect(find.text('Half of 40.'), findsOneWidget);
    await tester.ensureVisible(find.text('Next step'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Next step'));
    await tester.pumpAndSettle();

    expect(find.text('Step 2 of 5 · Easy'), findsOneWidget);
    expect(find.text('Pattern seen in 4 of your papers and web references'), findsOneWidget);
    await answerStep(tester, '10', 'Next step');

    expect(find.text('Step 3 of 5 · Medium'), findsOneWidget);
    expect(find.text('From your papers · chsl.pdf 2023'), findsOneWidget); // a real question
    await answerStep(tester, '20', 'Next step');
    await answerStep(tester, '20', 'Next step');
    expect(find.text('Step 5 of 5 · Extreme hard'), findsOneWidget);
    await answerStep(tester, '20', 'See results');

    expect(find.text('Your climb'), findsOneWidget);
    expect(find.text('4 of 5 right'), findsOneWidget);
    expect(find.text('Missed'), findsOneWidget);
    expect(find.text('Cleared'), findsNWidgets(4));
    expect(find.text('Discount: 1 of 2'), findsOneWidget);
    await tester.ensureVisible(find.text('Test me more'));
    expect(find.textContaining('Not past-paper questions'), findsOneWidget);

    await tester.pumpAndSettle();
    await tester.tap(find.text('Test me more'));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await tester.pumpAndSettle();
    expect(ladder.calls, contains('more'));
    expect(find.text('Step 1 of 5 · Medium-hard'), findsOneWidget);
  });

  testAppWidgets('a failure explains, offers real questions, and retry goes on', (
    tester,
    db,
  ) async {
    final ladder = await pumpLadder(tester, db)
      ..failure = const NetworkFailure();
    await openPercentage(tester);
    await startClimbing(tester);

    expect(find.textContaining('offline'), findsOneWidget);
    expect(find.text('Practise real questions from your papers'), findsOneWidget);

    await tester.tap(find.text('Try again'));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await tester.pumpAndSettle();
    expect(find.text('Step 1 of 5 · Easy'), findsOneWidget);
    expect(ladder.calls.where((c) => c.startsWith('generate:1:')), hasLength(5));
  });

  testAppWidgets('without AI or without Plus no ladder starts', (tester, db) async {
    await pumpLadder(tester, db, aiOn: false);
    await openPercentage(tester);
    expect(find.textContaining("AI isn't available"), findsOneWidget);
    expect(find.text('Practise real questions from your papers'), findsOneWidget);
    expect(find.text('Start climbing'), findsNothing);
  });

  testAppWidgets('Plus is asked for when the server requires it', (tester, db) async {
    await pumpLadder(tester, db, needsPlus: true);
    await openPercentage(tester);
    expect(find.text('Challenge Ladder is part of PrepLoop Plus.'), findsOneWidget);
  });

  testAppWidgets('the stored consent is remembered', (tester, db) async {
    await tester.runAsync(() => saveLadderConsent(db));
    final ladder = await pumpLadder(tester, db);
    await openPercentage(tester);
    await tester.ensureVisible(find.text('Start climbing'));
    await tester.tap(find.text('Start climbing'));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await tester.pumpAndSettle();
    expect(find.textContaining('sent to an AI service'), findsNothing);
    expect(ladder.calls.where((c) => c.startsWith('start')), hasLength(1));
  });

  testAppWidgets('reduce motion keeps the icon still', (tester, db) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(disableAnimations: true),
            child: Scaffold(body: LadderIcon()),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(seconds: 2));
    expect(tester.hasRunningAnimations, isFalse);
  });
}
