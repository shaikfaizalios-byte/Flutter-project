import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:preploop/features/insights/domain/repeats.dart';

import '../../helpers/pump_app.dart';
import 'repeats_test.dart' show basis, openRepeats, rare, venn;

void main() {
  testAppWidgets('Not repeated: unseen syllabus topics, one-paper topics and unseen types', (
    tester,
    db,
  ) async {
    final insights = FakeInsightsRepository(
      report: const RepeatsReport(
        papers: basis,
        topics: [venn, rare],
        notRepeated: NotRepeated(
          notSeen: [
            TopicRef(topicId: 't1', subject: 'General Awareness', name: 'Polity'),
            TopicRef(topicId: 't2', subject: 'General Engineering', name: 'Thermodynamics'),
          ],
          patternsNotSeen: [PatternGap(topicName: 'Venn Diagrams', name: 'Reading a diagram')],
          questionsWithoutTopic: 3,
        ),
      ),
    );
    await pumpPrepLoopApp(
      tester,
      db,
      insights: insights,
      studyProfile: onboardedProfile.copyWith(examCodes: ['SSC_CHSL']),
    );
    await openRepeats(tester);

    await tester.tap(find.text('Not repeated'));
    await tester.pumpAndSettle();

    expect(find.text("What these papers didn't ask"), findsOneWidget);
    expect(find.textContaining('It is not a prediction'), findsOneWidget);
    expect(find.textContaining('3 questions have no topic yet'), findsOneWidget);
    await scrollTo(tester, find.text('2 syllabus topics not seen'));
    expect(find.text('Polity'), findsOneWidget);
    expect(find.text('Thermodynamics'), findsOneWidget);
    await scrollTo(tester, find.text('1 topic came in only one paper'));
    expect(find.text('Dice and Cubes  ·  General Intelligence'), findsOneWidget);
    await scrollTo(tester, find.text('1 question type not seen yet'));
    expect(find.text('Venn Diagrams: Reading a diagram'), findsOneWidget);

    // "Study" opens the topic in the Study tab.
    await scrollTo(tester, find.text('Polity'));
    await tester.tap(
      find.descendant(of: find.widgetWithText(ListTile, 'Polity'), matching: find.text('Study')),
    );
    await tester.pumpAndSettle();
    expect(find.text('Topic: Polity'), findsOneWidget);
  });

  testAppWidgets('Repeated stays the default view', (tester, db) async {
    final insights = FakeInsightsRepository(
      report: const RepeatsReport(papers: basis, topics: [venn]),
    );
    await pumpPrepLoopApp(tester, db, insights: insights);
    await openRepeats(tester);

    expect(find.text('Venn Diagrams  ·  General Intelligence'), findsOneWidget);
    expect(find.text("What these papers didn't ask"), findsNothing);
  });
}
