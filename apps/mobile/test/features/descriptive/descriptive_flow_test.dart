import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:preploop/app/app_features.dart';
import 'package:preploop/core/database/app_database.dart';
import 'package:preploop/core/errors/app_failure.dart';
import 'package:preploop/core/localization/content_language.dart';
import 'package:preploop/features/descriptive/application/descriptive_providers.dart';
import 'package:preploop/features/descriptive/data/descriptive_repository.dart';
import 'package:preploop/features/descriptive/domain/descriptive_models.dart';
import 'package:preploop/features/descriptive/presentation/descriptive_card.dart';
import 'package:preploop/features/descriptive/presentation/descriptive_screen.dart';

import '../../helpers/pump_app.dart';

const estimate = 'Estimated marks from AI feedback, not an official grade.';
final profilesOn = appFeaturesProvider.overrideWithValue(const AppFeatures(examProfiles: true));

/// Stand-in for the server: two levels, and the second marking can disagree.
class FakeDescriptive implements DescriptiveRepository {
  FakeDescriptive({this.available = true, this.paperQuestions = 0});

  final bool available;
  final int paperQuestions;
  bool fromPapers = false;
  final calls = <String>[];
  double? low;
  double? high;

  /// Thrown by the next answer (then cleared).
  AppFailure? failure;

  static DescriptiveStep planned(int step) => DescriptiveStep(
    step: step,
    level: step == 1 ? 'define_list' : 'case_evaluate',
    marks: step == 1 ? 2 : 10,
    wordLimit: step == 1 ? 40 : 200,
    ready: false,
  );

  @override
  Future<DescriptiveOverview> overview(String examCode) async => DescriptiveOverview(
    available: available,
    topics: [
      DescriptiveTopic(
        topicId: 't1',
        name: 'Contracts',
        subject: 'Law',
        paperQuestions: paperQuestions,
      ),
    ],
  );

  @override
  Future<DescriptiveSession> start({
    required String examCode,
    required String topicId,
    required ContentLanguage language,
    bool fromPapers = false,
  }) async {
    this.fromPapers = fromPapers;
    return DescriptiveSession(sessionId: 's1', steps: [planned(1), planned(2)]);
  }

  @override
  Future<DescriptiveStep> generate(String sessionId, int step) async {
    calls.add('generate:$step');
    final plan = planned(step);
    return DescriptiveStep(
      step: step,
      level: plan.level,
      marks: plan.marks,
      wordLimit: plan.wordLimit,
      ready: true,
      stem: 'Question $step?',
      fromPaper: fromPapers,
      paperLabel: fromPapers ? 'law-2024.pdf' : null,
    );
  }

  @override
  Future<DescriptiveStep> answer(
    String sessionId,
    int step, {
    required String text,
    required bool fromPhoto,
  }) async {
    calls.add('answer:$step:$text:$fromPhoto');
    final next = failure;
    failure = null;
    if (next != null) throw next;
    final plan = planned(step);
    return DescriptiveStep(
      step: step,
      level: plan.level,
      marks: plan.marks,
      wordLimit: plan.wordLimit,
      ready: true,
      stem: 'Question $step?',
      fromPaper: fromPapers,
      result: DescriptiveResult(
        marks: 1.5,
        marksPossible: plan.marks,
        low: low,
        high: high,
        points: const [
          DescriptivePoint(point: 'Names the rule', marks: 2, awarded: 1.5, comment: 'Mostly'),
        ],
        missingPoints: const ['An example'],
        structure: 'Clear',
        modelAnswer: 'The model answer.',
        modelAnswerFromPaper: fromPapers,
        wordCount: 3,
      ),
    );
  }

  @override
  Future<PhotoReading> readPhoto(String name, List<int> bytes) async {
    calls.add('photo:$name');
    return const PhotoReading(text: 'Read frum the page', unclear: true);
  }
}

Future<FakeDescriptive> pumpCard(
  WidgetTester tester,
  AppDatabase db, {
  bool available = true,
  bool flag = true,
  int paperQuestions = 0,
}) async {
  final repository = FakeDescriptive(available: available, paperQuestions: paperQuestions);
  await pumpPrepLoopApp(
    tester,
    db,
    ai: FakeAiRepository(enabled: true),
    studyProfile: onboardedProfile.copyWith(examCodes: ['SSC_CHSL']),
    extraOverrides: [
      if (flag) profilesOn,
      descriptiveRepositoryProvider.overrideWithValue(repository),
      photoPickerProvider.overrideWithValue(() async => (name: 'p.jpg', bytes: const [1, 2])),
    ],
  );
  return repository;
}

Future<void> tapText(WidgetTester tester, String text) async {
  await tester.ensureVisible(find.text(text));
  await tester.pumpAndSettle();
  await tester.tap(find.text(text));
  await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 30)));
  await tester.pumpAndSettle();
}

Future<void> openTopic(WidgetTester tester) async {
  await scrollTo(tester, find.byType(DescriptiveCard));
  await tapText(tester, 'Written answers');
  await tapText(tester, 'Contracts');
}

Future<void> openFirstQuestion(WidgetTester tester) async {
  await openTopic(tester);
  await tapText(tester, 'Start writing');
}

void main() {
  test('totals add up what has been marked', () {
    const marked = DescriptiveStep(
      step: 1,
      level: 'define_list',
      marks: 2,
      wordLimit: 40,
      ready: true,
      result: DescriptiveResult(marks: 1.5, marksPossible: 2, points: [], modelAnswer: ''),
    );
    final session = DescriptiveSession(sessionId: 's', steps: [marked, FakeDescriptive.planned(2)]);
    expect(session.totals, (1.5, 2.0));
  });

  test('marks read without a needless decimal', () {
    expect(marksText(4), '4');
    expect(marksText(6.5), '6.5');
  });

  testAppWidgets('an answer is written, marked, and labelled an estimate', (tester, db) async {
    final repository = await pumpCard(tester, db);
    await openFirstQuestion(tester);
    expect(find.text('Question 1?'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'My own answer');
    await tester.pumpAndSettle();
    await tapText(tester, 'Mark my answer');

    expect(repository.calls, contains('answer:1:My own answer:false'));
    expect(find.text(estimate), findsOneWidget);
    expect(find.text('1.5 of 2 marks'), findsOneWidget);
    expect(find.text('Names the rule'), findsOneWidget);
    expect(find.text('• An example'), findsOneWidget);
    expect(find.text('The model answer.'), findsOneWidget);
  });

  testAppWidgets('markings that disagreed show the range', (tester, db) async {
    final repository = await pumpCard(tester, db);
    repository
      ..low = 1
      ..high = 2;
    await openFirstQuestion(tester);
    await tester.enterText(find.byType(TextField), 'Answer');
    await tester.pumpAndSettle();
    await tapText(tester, 'Mark my answer');
    expect(find.textContaining('from 1 to 2'), findsOneWidget);
  });

  testAppWidgets('a photo fills the box to correct before anything is marked', (tester, db) async {
    final repository = await pumpCard(tester, db);
    await openFirstQuestion(tester);
    await tapText(tester, 'Read from a photo');

    expect(repository.calls, contains('photo:p.jpg'));
    expect(repository.calls.where((c) => c.startsWith('answer')), isEmpty);
    expect(find.text('Read frum the page'), findsOneWidget);
    expect(find.textContaining('Check this against your page'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'Read from the page');
    await tester.pumpAndSettle();
    await tapText(tester, 'Mark my answer');
    expect(repository.calls, contains('answer:1:Read from the page:true'));
  });

  testAppWidgets('a failed marking keeps the answer to send again', (tester, db) async {
    final repository = await pumpCard(tester, db);
    repository.failure = const NetworkFailure();
    await openFirstQuestion(tester);
    await tester.enterText(find.byType(TextField), 'Keep me');
    await tester.pumpAndSettle();
    await tapText(tester, 'Mark my answer');
    expect(find.text('Keep me'), findsOneWidget);
    await tapText(tester, 'Mark my answer');
    expect(find.text(estimate), findsOneWidget);
  });

  testAppWidgets('the last level leads to the total', (tester, db) async {
    await pumpCard(tester, db);
    await openFirstQuestion(tester);
    for (final button in ['Next step', 'See results']) {
      await tester.enterText(find.byType(TextField), 'Answer');
      await tester.pumpAndSettle();
      await tapText(tester, 'Mark my answer');
      await tapText(tester, button);
    }
    expect(find.text('3 of 12 marks'), findsOneWidget);
    expect(find.text(estimate), findsOneWidget);
  });

  testAppWidgets('a real question says where it came from and what marked it', (tester, db) async {
    final repository = await pumpCard(tester, db, paperQuestions: 3);
    await openTopic(tester);
    await tapText(tester, 'Use questions from my papers (3)');

    expect(repository.fromPapers, isTrue);
    expect(find.text('From your paper: law-2024.pdf'), findsOneWidget);
    expect(find.textContaining('AI-generated practice question'), findsNothing);

    await tester.enterText(find.byType(TextField), 'My answer');
    await tester.pumpAndSettle();
    await tapText(tester, 'Mark my answer');

    expect(find.text(estimate), findsOneWidget);
    expect(find.textContaining('not the exam\'s official scheme'), findsOneWidget);
    expect(find.text('Answer printed in your paper'), findsOneWidget);
    expect(find.text('Model answer (AI-generated)'), findsNothing);
  });

  testAppWidgets('a topic with no written questions offers only AI ones', (tester, db) async {
    await pumpCard(tester, db);
    await openTopic(tester);
    expect(find.text('Start writing'), findsOneWidget);
    expect(find.textContaining('from my papers'), findsNothing);
  });

  testAppWidgets('a multiple-choice exam shows no card', (tester, db) async {
    await pumpCard(tester, db, available: false);
    expect(find.text('Written answers', skipOffstage: false), findsNothing);
  });

  testAppWidgets('with the flag off there is no card', (tester, db) async {
    await pumpCard(tester, db, flag: false);
    expect(find.text('Written answers', skipOffstage: false), findsNothing);
  });
}
