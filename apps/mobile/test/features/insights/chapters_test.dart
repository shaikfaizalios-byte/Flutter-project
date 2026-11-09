import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:preploop/core/localization/generated/app_localizations.dart';
import 'package:preploop/features/exams/application/active_exam.dart';
import 'package:preploop/features/insights/application/chapters_providers.dart';
import 'package:preploop/features/insights/data/insights_repository.dart';
import 'package:preploop/features/insights/domain/chapters.dart';
import 'package:preploop/features/insights/presentation/chapters_screen.dart';
import 'package:preploop/features/insights/presentation/repeats_screen.dart';
import 'package:preploop/features/insights/domain/repeats.dart';

import '../../helpers/fake_insights.dart';

const report = ChapterReport(
  basis: ShiftBasis(
    shifts: 4,
    questions: 40,
    unreviewed: 6,
    years: [YearWeight(year: 2025, questions: 40, shifts: 4)],
    sessions: [SessionWeight(session: 'January', questions: 20, shifts: 2)],
  ),
  chapters: [
    ChapterWeight(
      subject: 'Physics',
      name: 'Kinematics',
      questions: 10,
      shifts: 3,
      years: [YearWeight(year: 2025, questions: 10, shifts: 3)],
      sessions: [SessionWeight(session: 'January', questions: 5, shifts: 1)],
    ),
  ],
);

Future<void> show(WidgetTester tester, FakeInsightsRepository insights) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        insightsRepositoryProvider.overrideWithValue(insights),
        activeExamProvider.overrideWithValue('SSC_CHSL'),
        sharedChaptersProvider.overrideWith((ref) async => const []),
        repeatRulesProvider.overrideWithValue(
          const RepeatRules(share: 0.5, minPapers: 2, reliablePapers: 5),
        ),
      ],
      child: const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: ChaptersScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  test('a weight needs questions to be a share of', () {
    expect(weightPercent(10, 40), 25);
    expect(weightPercent(1, 3), 33);
    expect(weightPercent(0, 0), isNull);
  });

  test('reads the report from the server', () {
    final read = ChapterReport.fromJson({
      'basis': {
        'shifts': 2,
        'questions': 3,
        'unreviewed': 1,
        'years': [
          {'year': 2025, 'questions': 3, 'shifts': 2, 'marks': null},
        ],
        'sessions': <Object>[],
      },
      'chapters': [
        {
          'subject': 'Physics',
          'name': 'Kinematics',
          'questions': 3,
          'shifts': 2,
          'marks': null,
          'years': <Object>[],
          'sessions': <Object>[],
          'topics': [
            {'topic_id': 't', 'name': 'Motion', 'questions': 3, 'shifts': 2},
          ],
        },
      ],
    });
    expect(read.basis.year(2025)?.shifts, 2);
    expect(read.chapters.single.topics.single.name, 'Motion');
  });

  testWidgets('shows x of y shifts, what was left out, and a small sample', (tester) async {
    await show(tester, FakeInsightsRepository()..chapterReport = report);

    expect(find.textContaining('Appeared in 3 of 4 shifts'), findsOneWidget);
    expect(find.text('4 shifts counted · 40 reviewed questions'), findsOneWidget);
    expect(find.textContaining('6 questions not reviewed'), findsOneWidget);
    expect(find.textContaining('small sample'), findsOneWidget);
    expect(find.textContaining('Not a prediction'), findsOneWidget);

    await tester.tap(find.text('Kinematics'));
    await tester.pumpAndSettle();
    expect(find.text('2025: 25% of questions · 3 of 4 shifts'), findsOneWidget);
    expect(find.text('January: 1 of 2 shifts'), findsOneWidget);
  });

  testWidgets('a concept hint says it is AI and outside the counts', (tester) async {
    await show(
      tester,
      FakeInsightsRepository()
        ..chapterReport = report
        ..hints = const [
          ConceptHint(
            topicName: 'Motion',
            label: 'Equations of motion',
            shifts: 2,
            questions: [ConceptHintQuestion(questionId: 'q', number: 7, year: 2025)],
          ),
        ],
    );
    await tester.scrollUntilVisible(find.text('Equations of motion'), 200);
    expect(find.textContaining('AI hint'), findsOneWidget);
    expect(find.text('Motion · 2 shifts'), findsOneWidget);
  });
}
