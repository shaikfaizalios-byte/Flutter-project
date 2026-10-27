import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:preploop/features/insights/domain/repeats.dart';

import '../../helpers/pump_app.dart';
import '../documents/documents_screen_test.dart' show FakeDocumentsRepository, overridesFor;
import 'repeats_test.dart' show basis, venn;

void main() {
  testAppWidgets('a new learner starts from the starter papers on Home', (tester, db) async {
    final practice = FakePracticeRepository(serverNow: () => testNow);
    final insights = FakeInsightsRepository(
      sharedReport: const RepeatsReport(papers: basis, topics: [venn]),
    )..sharedSummary = const [SharedBankExam(examCode: 'SSC_CHSL', papers: 5, questions: 480)];
    await pumpPrepLoopApp(
      tester,
      db,
      practice: practice,
      insights: insights,
      studyProfile: onboardedProfile.copyWith(examCodes: ['SSC_CHSL']),
      extraOverrides: overridesFor(FakeDocumentsRepository()), // no papers of their own
    );

    expect(find.text('Starter papers'), findsOneWidget);
    expect(
      find.text('5 previous SSC CHSL papers are ready to practise: 480 checked questions.'),
      findsOneWidget,
    );

    // Topics that repeat opens Repeated models on the shared bank.
    await tester.tap(find.text('Topics that repeat'));
    await tester.pumpAndSettle();
    expect(insights.scopes.last, 'shared');
    expect(find.text('Venn Diagrams  ·  General Intelligence'), findsOneWidget);

    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Practise'));
    await tester.pumpAndSettle();
    expect(practice.practiceRequests.single.examCode, 'SSC_CHSL');
    expect(practice.practiceRequests.single.includeShared, isTrue);
  });

  testAppWidgets('no starter tile without shared papers or once own papers exist', (
    tester,
    db,
  ) async {
    await pumpPrepLoopApp(
      tester,
      db,
      studyProfile: onboardedProfile.copyWith(examCodes: ['SSC_CHSL']),
      extraOverrides: overridesFor(FakeDocumentsRepository()),
    );
    expect(find.text('Starter papers'), findsNothing);
  });

  testAppWidgets('Repeated models with no own papers points to the starter papers', (
    tester,
    db,
  ) async {
    final insights = FakeInsightsRepository(
      sharedReport: const RepeatsReport(papers: basis, topics: [venn]),
    )..sharedSummary = const [SharedBankExam(examCode: 'SSC_CHSL', papers: 5, questions: 480)];
    await pumpPrepLoopApp(
      tester,
      db,
      insights: insights,
      studyProfile: onboardedProfile.copyWith(examCodes: ['SSC_CHSL']),
    );
    await tester.tap(
      find.descendant(of: find.byType(NavigationBar), matching: find.text('Practice')),
    );
    await tester.pumpAndSettle();
    await scrollTo(tester, find.text('See repeated models'));
    await tester.tap(find.text('See repeated models'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('See 5 starter papers'));
    await tester.pumpAndSettle();
    expect(find.text('Venn Diagrams  ·  General Intelligence'), findsOneWidget);
  });
}
