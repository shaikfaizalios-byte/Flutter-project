import 'package:flutter_test/flutter_test.dart';
import 'package:preploop/core/utils/external_links.dart';
import 'package:preploop/core/widgets/search_field.dart';

import '../../helpers/pump_app.dart';
import 'concept_flow_test.dart' show openStudy, seedConcept;

final paperQuestions = FakeQuestionsRepository([
  bankQuestion(id: 'q1', stem: 'What does the Swift optional binding do?'),
  bankQuestion(id: 'q2', number: 2, stem: 'Which Swift keyword declares a constant?'),
  bankQuestion(id: 'q3', number: 3, stem: 'What is 20% of 150?'),
  bankQuestion(id: 'q4', number: 4, stem: 'Swift question of another exam', exam: 'SSC_CGL'),
]);

void main() {
  testAppWidgets('the Study search also lists matching questions from the papers', (
    tester,
    db,
  ) async {
    final questions = paperQuestions;
    await pumpPrepLoopApp(
      tester,
      db,
      questions: questions,
      studyProfile: onboardedProfile.copyWith(examCodes: ['SSC_CHSL']),
    );
    await openStudy(tester);

    await tester.enterText(find.byType(AppSearchField), 'swift');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();

    // Only the current exam's questions, searched on the server with the typed text.
    expect(questions.queries.last.text, 'swift');
    expect(questions.queries.last.examCode, 'SSC_CHSL');
    expect(find.textContaining('Questions from your SSC CHSL papers'), findsOneWidget);
    expect(find.textContaining('optional binding'), findsOneWidget);
    expect(find.textContaining('declares a constant'), findsOneWidget);
    expect(find.textContaining('another exam'), findsNothing);

    await tester.tap(find.textContaining('See all'));
    await tester.pumpAndSettle();
    expect(find.byType(AppSearchField), findsWidgets);
    expect(questions.queries.last.text, 'swift');
  });

  testAppWidgets('a search with no matching question says so', (tester, db) async {
    await pumpPrepLoopApp(
      tester,
      db,
      questions: paperQuestions,
      studyProfile: onboardedProfile.copyWith(examCodes: ['SSC_CHSL']),
    );
    await openStudy(tester);

    await tester.enterText(find.byType(AppSearchField), 'kotlin');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('No questions in your imported papers match "kotlin"'),
      findsOneWidget,
    );
  });

  testAppWidgets('a concept page lists questions about that concept', (tester, db) async {
    await pumpPrepLoopApp(
      tester,
      db,
      questions: paperQuestions,
      studyProfile: onboardedProfile.copyWith(examCodes: ['SSC_CHSL']),
    );
    await seedConcept(tester, db, 'Swift');
    await openStudy(tester);
    await tester.tap(find.text('Swift').first);
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();

    await scrollTo(tester, find.textContaining('optional binding'));
    expect(find.textContaining('optional binding'), findsOneWidget);
  });

  testAppWidgets('Google is offered when nothing matches and to learn more about matches', (
    tester,
    db,
  ) async {
    final opened = <Uri>[];
    await pumpPrepLoopApp(
      tester,
      db,
      questions: paperQuestions,
      studyProfile: onboardedProfile.copyWith(examCodes: ['SSC_CHSL']),
      extraOverrides: [
        linkOpenerProvider.overrideWithValue((uri) async {
          opened.add(uri);
          return true;
        }),
      ],
    );
    await openStudy(tester);

    await tester.enterText(find.byType(AppSearchField), 'kotlin coroutines');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Search on Google'));
    await tester.pumpAndSettle();
    expect(opened.single.toString(), 'https://www.google.com/search?q=kotlin+coroutines');

    await tester.enterText(find.byType(AppSearchField), 'swift');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Learn more on Google'));
    await tester.pumpAndSettle();
    expect(opened.last.queryParameters['q'], 'swift');

    // A question itself can be looked up too.
    await tester.tap(find.textContaining('optional binding'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Learn more on Google'));
    await tester.pumpAndSettle();
    expect(opened.last.queryParameters['q'], 'What does the Swift optional binding do?');
  });

  testAppWidgets('a link that cannot open says so', (tester, db) async {
    await pumpPrepLoopApp(
      tester,
      db,
      questions: paperQuestions,
      studyProfile: onboardedProfile.copyWith(examCodes: ['SSC_CHSL']),
      extraOverrides: [linkOpenerProvider.overrideWithValue((uri) async => false)],
    );
    await openStudy(tester);
    await tester.enterText(find.byType(AppSearchField), 'kotlin');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Search on Google'));
    await tester.pumpAndSettle();
    expect(find.text("Couldn't open the browser."), findsOneWidget);
  });

  test('the Google address collapses whitespace and caps the length', () {
    expect(googleSearchUri('  swift \n  optionals ').queryParameters['q'], 'swift optionals');
    final long = googleSearchUri('a' * 500).queryParameters['q']!;
    expect(long.length, webSearchMaxLength);
    expect(googleSearchUri('C++ & Swift?').host, 'www.google.com');
  });
}
