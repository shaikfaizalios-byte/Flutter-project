import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:preploop/app/app_features.dart';
import 'package:preploop/core/database/app_database.dart';
import 'package:preploop/features/ladder/domain/ladder_models.dart';
import 'package:preploop/features/ladder/presentation/ladder_card.dart';
import 'package:preploop/features/ladder/presentation/ladder_screen.dart';

import '../../helpers/pump_app.dart';
import 'ladder_flow_test.dart' show openPercentage, startClimbing, topics;

final profilesOn = appFeaturesProvider.overrideWithValue(const AppFeatures(examProfiles: true));

Future<FakeLadderRepository> pumpFormats(
  WidgetTester tester,
  AppDatabase db, {
  String format = 'single_correct',
  double? marks,
  bool flag = true,
  bool available = true,
}) async {
  final ladder =
      FakeLadderRepository(
          data: LadderOverview(topics: topics, available: available),
        )
        ..format = format
        ..marks = marks;
  await pumpPrepLoopApp(
    tester,
    db,
    ai: FakeAiRepository(enabled: true),
    ladder: ladder,
    studyProfile: onboardedProfile.copyWith(examCodes: ['SSC_CHSL']),
    extraOverrides: [if (flag) profilesOn],
  );
  return ladder;
}

Map<String, dynamic> stepJson(Map<String, dynamic> changes) => {
  'round_number': 1,
  'step': 1,
  'difficulty': 'easy',
  'ready': true,
  'source': 'ai',
  'basis_papers': 0,
  'basis_web': true,
  ...changes,
};

LadderStep answered(double marks, double possible, {bool correct = true}) => LadderStep(
  roundNumber: 1,
  step: 1,
  difficulty: LadderDifficulty.easy,
  ready: true,
  result: LadderResult(
    correct: correct,
    solution: const [],
    shortcut: '',
    marks: marks,
    marksPossible: possible,
  ),
);

LadderRound roundOf(List<LadderStep> steps) => LadderRound(
  sessionId: 's',
  roundNumber: 1,
  topicName: 'T',
  subject: 'S',
  sourceMix: LadderSourceMix.papers,
  steps: steps,
);

void main() {
  test('a step without a format is one correct option', () {
    final step = LadderStep.fromJson(stepJson({}));
    expect(step.format, 'single_correct');
    expect(step.typed || step.takesResponse, isFalse);
  });

  test('a match step reads its lists and a result without an index', () {
    final step = LadderStep.fromJson(
      stepJson({
        'format': 'match',
        'format_data': {
          'left': ['a'],
          'right': ['b'],
        },
        'result': {
          'selected_index': null,
          'answer_index': null,
          'correct': false,
          'solution': <String>[],
          'shortcut': '',
          'time_spent_ms': null,
          'answer_lines': ['a → b'],
          'partly_right': true,
          'marks': 1,
          'marks_possible': 4,
        },
      }),
    );
    expect(step.takesResponse, isTrue);
    expect(step.formatData!['right'], ['b']);
    expect(step.result!.answerIndex, isNull);
    expect(step.result!.answerLines, ['a → b']);
    expect((step.result!.marks, step.result!.marksPossible), (1.0, 4.0));
  });

  test('the summary adds up marks, penalties included', () {
    final summary = LadderSummary.of(roundOf([answered(2, 2), answered(-0.5, 2, correct: false)]));
    expect((summary.marks, summary.marksPossible), (1.5, 4.0));
    expect(ladderMarksText(summary.marks!), '1.5');
    expect(ladderMarksText(summary.marksPossible!), '4');
  });

  test('without stated marks the summary has none', () {
    const step = LadderStep(
      roundNumber: 1,
      step: 1,
      difficulty: LadderDifficulty.easy,
      ready: true,
      result: LadderResult(correct: true, solution: [], shortcut: ''),
    );
    expect(LadderSummary.of(roundOf([step])).marks, isNull);
  });

  testAppWidgets('a number is typed, and the right answer is shown in words', (tester, db) async {
    final ladder = await pumpFormats(tester, db, format: 'numeric', marks: 2);
    await openPercentage(tester);
    await startClimbing(tester);

    await tester.enterText(find.byType(TextField), '20');
    await tester.ensureVisible(find.text('Save answer'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save answer'));
    await tester.pumpAndSettle();

    expect(ladder.calls, contains('answer:1:1:20'));
    expect(find.text('Marks: 2 of 2'), findsOneWidget);
    expect(find.text('20 ± 0.5'), findsOneWidget);
  });

  testAppWidgets('several options go in one answer and can be partly right', (tester, db) async {
    final ladder = await pumpFormats(tester, db, format: 'multiple_correct', marks: 4);
    await openPercentage(tester);
    await startClimbing(tester);

    await tester.ensureVisible(find.textContaining('A. 10'));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('A. 10'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Save answer'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save answer'));
    await tester.pumpAndSettle();

    expect(ladder.calls.last, contains('positions'));
    expect(find.text('Partly right'), findsOneWidget);
    expect(find.text('Marks: 1 of 4'), findsOneWidget);
  });

  testAppWidgets('with the flag off no marks are shown', (tester, db) async {
    await pumpFormats(tester, db, marks: 2, flag: false);
    await openPercentage(tester);
    await startClimbing(tester);
    await tester.ensureVisible(find.text('20'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('20'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Marks:'), findsNothing);
    expect(find.byType(LadderScreen), findsOneWidget);
  });

  testAppWidgets('an exam without a ladder shows no card', (tester, db) async {
    await pumpFormats(tester, db, available: false);
    expect(find.byType(LadderCard, skipOffstage: false), findsOneWidget);
    expect(find.text('Challenge Ladder', skipOffstage: false), findsNothing);
  });
}
