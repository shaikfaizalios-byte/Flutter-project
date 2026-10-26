import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:preploop/app/app_features.dart';
import 'package:preploop/core/utils/calendar_date.dart';
import 'package:preploop/features/documents/application/documents_providers.dart';
import 'package:preploop/features/insights/domain/radar.dart';
import 'package:preploop/features/insights/domain/repeats.dart';
import 'package:preploop/features/question_bank/domain/question.dart';

import '../../helpers/pump_app.dart';
import '../documents/documents_screen_test.dart' show FakeDocumentsRepository, doc;
import '../question_bank/question_bank_test.dart' show openPractice, openQuestion;

const basis = PapersBasis(total: 4, dated: 3, undated: 1, years: [2019, 2021, 2022]);

const venn = TopicRepeat(
  topicId: 't-venn',
  subject: 'General Intelligence',
  name: 'Venn Diagrams',
  confirmed: RepeatCounts(questions: 5, papers: 3, years: [YearCount(2019, 2), YearCount(2021, 2)]),
  unreviewed: 2,
  patterns: [
    PatternRepeat(
      patternId: 'p-classes',
      name: 'Relationship between classes',
      confirmed: RepeatCounts(questions: 4, papers: 3),
      unreviewed: 1,
    ),
  ],
  withoutPattern: 1,
);

const rare = TopicRepeat(
  topicId: 't-dice',
  subject: 'General Intelligence',
  name: 'Dice and Cubes',
  confirmed: RepeatCounts(questions: 1, papers: 1),
  unreviewed: 0,
);

const group = SimilarGroup(
  topicName: 'Percentage',
  papers: 2,
  years: [2019, 2021],
  questions: [
    SimilarQuestion(
      questionId: 'q1',
      documentFilename: 'chsl-2019.pdf',
      examYear: 2019,
      questionNumber: 51,
      stemExcerpt: 'Anu spends 90% of her income…',
      verified: true,
    ),
    SimilarQuestion(
      questionId: 'q9',
      documentFilename: 'chsl-2021.pdf',
      questionNumber: 48,
      stemExcerpt: 'Anu spends 75% of her income…',
      verified: false,
    ),
  ],
);

Future<void> openRepeats(WidgetTester tester) async {
  await openPractice(tester, bank: 'See repeated models');
}

/// Repeat Radar is hidden by default; these tests turn it on.
final radarOn = appFeaturesProvider.overrideWithValue(const AppFeatures(repeatRadar: true));

void main() {
  testAppWidgets('no papers: explains and links to importing', (tester, db) async {
    final insights = FakeInsightsRepository(
      report: const RepeatsReport(papers: PapersBasis(total: 0, dated: 0, undated: 0)),
    );
    await pumpPrepLoopApp(tester, db, insights: insights);
    await openRepeats(tester);

    expect(find.text('Repeated models'), findsOneWidget);
    expect(find.text('No papers yet'), findsOneWidget);
    expect(find.text('Import papers'), findsOneWidget);
  });

  testAppWidgets('report states its basis, keeps suggestions apart and starts practice', (
    tester,
    db,
  ) async {
    final insights = FakeInsightsRepository(
      report: const RepeatsReport(papers: basis, topics: [venn, rare], similarGroups: [group]),
    );
    final practice = FakePracticeRepository(serverNow: () => DateTime(2026, 10, 15, 9));
    await pumpPrepLoopApp(tester, db, practice: practice, insights: insights);
    await openRepeats(tester);

    expect(find.text('Based on 4 of your papers (2019–2022)'), findsOneWidget);
    expect(find.textContaining('1 papers have no confirmed date'), findsOneWidget);
    expect(find.textContaining('at least 50% of your papers, once you have 3'), findsOneWidget);
    expect(find.text('In 3 of 4 papers · 5 questions\n+2 not yet reviewed'), findsOneWidget);
    // 3 of 4 papers meets the named rule; 1 of 4 does not.
    expect(find.text('Seen in most papers'), findsOneWidget);

    await tester.tap(find.text('Venn Diagrams  ·  General Intelligence'));
    await tester.pumpAndSettle();
    expect(find.text('By year: 2019: 2 · 2021: 2'), findsOneWidget);
    expect(find.text('Relationship between classes'), findsOneWidget);
    expect(find.text('In 3 of 4 papers · 4 questions\n+1 not yet reviewed'), findsOneWidget);
    expect(find.text('1 other questions in this topic (no named type)'), findsOneWidget);

    await tester.tap(find.text('Practise'));
    await tester.pumpAndSettle();
    expect(practice.practiceRequests.single.patternId, 'p-classes');
  });

  testAppWidgets('worded-alike groups are labelled as hints and open the question', (
    tester,
    db,
  ) async {
    final insights = FakeInsightsRepository(
      report: const RepeatsReport(papers: basis, similarGroups: [group]),
    );
    final questions = FakeQuestionsRepository([bankQuestion()]);
    await pumpPrepLoopApp(tester, db, questions: questions, insights: insights);
    await openRepeats(tester);

    expect(find.text('Worded alike in different papers'), findsOneWidget);
    expect(find.textContaining('A hint, not a reviewed classification'), findsOneWidget);
    expect(find.text('In 2 of 4 papers · 2019, 2021'), findsOneWidget);
    expect(find.text('chsl-2019.pdf · Q.51 · 2019'), findsOneWidget);

    await tester.tap(find.text('Anu spends 90% of her income…'));
    await tester.pumpAndSettle();
    expect(find.text('Q.1'), findsOneWidget); // the question review screen
  });

  testAppWidgets('question review: suggested type with its reason; topic change clears it', (
    tester,
    db,
  ) async {
    final repo = FakeQuestionsRepository([
      bankQuestion(
        topicStatus: 'suggested',
        topic: sampleTopics.first,
        topicSuggestedBy: 'keywords',
        pattern: samplePatterns.first,
        patternStatus: 'suggested',
        patternSuggestionReason: 'Matched "income"',
      ),
    ]);
    await pumpPrepLoopApp(tester, db, questions: repo);
    await openPractice(tester);
    await openQuestion(tester, 'Q.1');

    await scrollTo(tester, find.text('Income, expenditure and savings'));
    expect(
      find.textContaining('Suggested type. Approving the question confirms it.'),
      findsOneWidget,
    );
    expect(find.textContaining('Why: Matched "income"'), findsOneWidget);

    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(repo.edits.last.$2['pattern_id'], 'p-income');

    // Another topic: its patterns only, and the old type is cleared on save.
    await scrollTo(tester, find.text('Quantitative Aptitude › Percentage'));
    await tester.tap(find.text('Quantitative Aptitude › Percentage'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Quantitative Aptitude › Ratio and Proportion').last);
    await tester.pumpAndSettle();
    expect(find.text('Income, expenditure and savings'), findsNothing);
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(repo.edits.last.$2['topic_id'], 't-ratio');
    expect(repo.edits.last.$2.containsKey('pattern_id'), isTrue);
    expect(repo.edits.last.$2['pattern_id'], isNull);
  });

  testAppWidgets('paper date: a suggestion is confirmed in one tap or edited', (tester, db) async {
    final docs = FakeDocumentsRepository()
      ..listResponses = [
        [doc(id: 'doc1', filename: 'ssc-chsl-2-july-2019-shift-3.pdf')],
      ];
    final repo = FakeQuestionsRepository([bankQuestion()]);
    repo.summary = ParseSummary(
      segmentationStatus: 'completed',
      questionsFound: 1,
      verified: 0,
      rejected: 0,
      withOpenIssues: 0,
      missingAnswers: 0,
      imageDependent: 0,
      sections: const [],
      documentIssues: const [],
      paperDate: PaperDate(
        year: 2019,
        date: CalendarDate(2019, 7, 2),
        shift: 3,
        status: 'suggested',
        reason: 'Read from the file name and first page',
      ),
    );
    await pumpPrepLoopApp(
      tester,
      db,
      questions: repo,
      extraOverrides: [documentsRepositoryProvider.overrideWithValue(docs)],
    );
    await tester.tap(find.descendant(of: find.byType(NavigationBar), matching: find.text('Study')));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Imported papers'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('ssc-chsl-2-july-2019-shift-3.pdf'));
    await tester.pumpAndSettle();

    expect(find.text('When was this paper held?'), findsOneWidget);
    expect(find.text('Jul 2, 2019 · Shift 3'), findsOneWidget);
    expect(find.textContaining('Read from the file name and first page'), findsOneWidget);

    await tester.tap(find.text('Confirm'));
    await tester.pumpAndSettle();
    expect(repo.paperDates.single, ('doc1', 2019, CalendarDate(2019, 7, 2), 3));
    expect(find.text('Confirmed. Used in year counts.'), findsOneWidget);

    await tester.tap(find.text('Change'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Shift 3').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Shift 2').last);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();
    expect(repo.paperDates.last, ('doc1', 2019, CalendarDate(2019, 7, 2), 2));
  });

  testAppWidgets('all learners: empty Radar explains the rule; sharing is opt-in', (
    tester,
    db,
  ) async {
    final insights = FakeInsightsRepository(eligiblePapers: 1);
    await pumpPrepLoopApp(tester, db, insights: insights, extraOverrides: [radarOn]);
    await openRepeats(tester);
    await tester.tap(find.text('All learners'));
    await tester.pumpAndSettle();

    expect(find.text('Not enough shared data yet'), findsOneWidget);
    expect(find.textContaining('at least 2 learners have reviewed it'), findsOneWidget);
    await scrollTo(tester, find.text('Share my counts with the Repeat Radar'));
    expect(find.textContaining('Never question text'), findsOneWidget);
    expect(
      find.text('1 of your papers can join (they need a confirmed date and shift).'),
      findsOneWidget,
    );
    final toggle = find.byType(Switch);
    expect(tester.widget<Switch>(toggle).value, isFalse);

    await tester.tap(toggle);
    await tester.pumpAndSettle();
    expect(insights.shareChanges, [true]);
    expect(tester.widget<Switch>(find.byType(Switch)).value, isTrue);
  });

  testAppWidgets('all learners: pooled shifts with basis, rule and practise', (tester, db) async {
    final insights = FakeInsightsRepository(
      radarReport: const RadarReport(
        basis: RadarBasis(shifts: 6, minAccounts: 2, years: [2019, 2024], withheld: 3),
        topics: [
          RadarTopic(
            topicId: 't-venn',
            subject: 'General Intelligence',
            name: 'Venn Diagrams',
            counts: RadarCounts(
              shifts: 5,
              questions: 7,
              years: [RadarYear(2019, 2), RadarYear(2024, 3)],
            ),
            patterns: [
              RadarPattern(
                patternId: 'p-classes',
                name: 'Relationship between classes',
                counts: RadarCounts(shifts: 4, questions: 4),
              ),
            ],
          ),
        ],
      ),
    );
    final practice = FakePracticeRepository(serverNow: () => DateTime(2026, 10, 18, 9));
    await pumpPrepLoopApp(
      tester,
      db,
      insights: insights,
      practice: practice,
      extraOverrides: [radarOn],
    );
    await openRepeats(tester);
    await tester.tap(find.text('All learners'));
    await tester.pumpAndSettle();

    expect(find.text('Based on 6 exam shifts reviewed by learners (2019–2024)'), findsOneWidget);
    expect(find.textContaining("One person can't change these numbers"), findsOneWidget);
    expect(
      find.text("3 counts are hidden because learners' numbers didn't agree."),
      findsOneWidget,
    );
    expect(find.text('In 5 of 6 shifts · 7 questions'), findsOneWidget);
    expect(find.text('In most shifts'), findsOneWidget);

    await tester.tap(find.text('Venn Diagrams  ·  General Intelligence'));
    await tester.pumpAndSettle();
    expect(find.text('Shifts by year: 2019: 2 · 2024: 3'), findsOneWidget);
    await tester.tap(find.text('Practise'));
    await tester.pumpAndSettle();
    expect(practice.practiceRequests.single.patternId, 'p-classes');
  });
}
