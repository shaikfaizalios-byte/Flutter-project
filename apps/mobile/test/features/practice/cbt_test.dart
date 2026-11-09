import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:preploop/app/app_features.dart';
import 'package:preploop/core/localization/generated/app_localizations.dart';
import 'package:preploop/features/practice/application/practice_providers.dart';
import 'package:preploop/features/practice/domain/cbt.dart';
import 'package:preploop/features/practice/domain/practice_models.dart';
import 'package:preploop/features/practice/presentation/mock_analysis_card.dart';
import 'package:preploop/features/practice/presentation/session_screen.dart';
import 'package:preploop/features/question_bank/domain/question.dart';

import '../../helpers/fake_practice.dart';

SessionItemView item(
  int position, {
  String section = 'Physics',
  int? selected,
  bool marked = false,
  bool visited = false,
}) => SessionItemView(
  position: position,
  verified: true,
  bookmarked: false,
  section: section,
  stem: 'Question $position?',
  options: const [
    QuestionOption(position: 1, label: 'A', text: 'first'),
    QuestionOption(position: 2, label: 'B', text: 'second'),
  ],
  selectedPosition: selected,
  marked: marked,
  visited: visited,
);

void main() {
  group('palette', () {
    test('follows the five official states', () {
      expect(cbtStatus(item(1)), CbtStatus.notVisited);
      expect(cbtStatus(item(1, visited: true)), CbtStatus.notAnswered);
      expect(cbtStatus(item(1), current: true), CbtStatus.notAnswered);
      expect(cbtStatus(item(1, selected: 1, visited: true)), CbtStatus.answered);
      expect(cbtStatus(item(1, marked: true)), CbtStatus.marked);
      expect(cbtStatus(item(1, marked: true, selected: 2)), CbtStatus.answeredMarked);
    });

    test('groups questions into sections in paper order', () {
      final sections = cbtSections([item(1), item(2), item(3, section: 'Chemistry')]);
      expect(sections.map((s) => (s.name, s.first)), [('Physics', 0), ('Chemistry', 2)]);
    });

    test('counts a section by state', () {
      final counts = cbtCounts([item(1, selected: 1), item(2), item(3, marked: true)], 2);
      expect(counts[CbtStatus.answered], 1);
      expect(counts[CbtStatus.notAnswered], 1);
      expect(counts[CbtStatus.marked], 1);
      expect(counts[CbtStatus.notVisited], 0);
    });
  });

  test('chapter accuracy counts attempted questions only', () {
    const chapter = ChapterAccuracy(
      subject: 'Physics',
      name: 'Kinematics',
      correct: 3,
      wrong: 1,
      unattempted: 6,
      timeMs: 1000,
    );
    expect(chapter.accuracy, 75);
    const none = ChapterAccuracy(
      subject: '',
      name: '',
      correct: 0,
      wrong: 0,
      unattempted: 2,
      timeMs: 0,
    );
    expect(none.accuracy, isNull);
  });

  Future<FakePracticeRepository> open(
    WidgetTester tester, {
    Size size = const Size(1200, 900),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final practice = FakePracticeRepository(serverNow: () => DateTime.utc(2026, 11, 7, 9));
    final mock = await practice.startMock('CBT');
    practice.useCbt(mock.id);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          practiceRepositoryProvider.overrideWithValue(practice),
          appFeaturesProvider.overrideWithValue(const AppFeatures(examProfiles: true)),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: SessionScreen(sessionId: mock.id),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return practice;
  }

  testWidgets('a selected option is saved only by Save & Next', (tester) async {
    final practice = await open(tester);
    final id = practice.sessions.keys.single;

    await tester.tap(find.textContaining('(1)').first);
    await tester.pump();
    expect(practice.sessions[id]!.answers[1], isNull);

    await tester.tap(find.text('Save & Next'));
    await tester.pumpAndSettle();
    expect(practice.sessions[id]!.answers[1], 1);
    expect(find.text('Question 2 of 2'), findsOneWidget);
  });

  testWidgets('leaving by the palette drops an unsaved answer', (tester) async {
    final practice = await open(tester);
    final id = practice.sessions.keys.single;

    await tester.tap(find.textContaining('(1)').first);
    await tester.pump();
    await tester.tap(find.bySemanticsLabel(RegExp('Question 2')));
    await tester.pumpAndSettle();

    expect(practice.sessions[id]!.answers[1], isNull);
    expect(practice.visits, [1]);
    expect(find.text('Question 2 of 2'), findsOneWidget);
  });

  testWidgets('mark for review saves with its mark, and clear removes the answer', (tester) async {
    final practice = await open(tester);
    final id = practice.sessions.keys.single;

    await tester.tap(find.textContaining('(2)').first);
    await tester.pump();
    await tester.tap(find.text('Mark for Review & Next'));
    await tester.pumpAndSettle();
    expect(practice.sessions[id]!.answers[1], 2);
    expect(practice.marks[1], isTrue);

    await tester.tap(find.bySemanticsLabel(RegExp('Question 1')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Clear Response'));
    await tester.pumpAndSettle();
    expect(practice.sessions[id]!.answers[1], isNull);
    expect(practice.marks[1], isFalse);
  });

  testWidgets('a percentile says what it is, and nothing else claims a rank', (tester) async {
    Future<void> show(MockAnalysis analysis) async {
      await tester.pumpWidget(
        ProviderScope(
          key: ValueKey(analysis),
          overrides: [
            appFeaturesProvider.overrideWithValue(const AppFeatures(examProfiles: true)),
            mockAnalysisProvider('s').overrideWith((ref) async => analysis),
          ],
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: SingleChildScrollView(child: MockAnalysisCard(sessionId: 's')),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    await show(const MockAnalysis());
    expect(find.textContaining('PrepLoop attempts'), findsNothing);
    await show(const MockAnalysis(percent: 62, accounts: 140));
    expect(find.textContaining('62%'), findsOneWidget);
    expect(find.textContaining('140 PrepLoop'), findsOneWidget);
    expect(find.textContaining('not an exam rank'), findsOneWidget);
  });

  testWidgets('on a phone the palette opens in a sheet', (tester) async {
    await open(tester, size: const Size(360, 720));
    expect(find.bySemanticsLabel(RegExp('Question 2')), findsNothing);
    await tester.tap(find.byIcon(Icons.grid_view));
    await tester.pumpAndSettle();
    await tester.tap(find.bySemanticsLabel(RegExp('Question 2')));
    await tester.pumpAndSettle();
    expect(find.text('Question 2 of 2'), findsOneWidget);
  });
}
