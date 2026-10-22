import 'package:flutter_test/flutter_test.dart';
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
}
