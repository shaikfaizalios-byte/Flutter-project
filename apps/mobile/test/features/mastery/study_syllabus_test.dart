import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:preploop/features/exams/domain/exam_topics.dart';
import 'package:preploop/features/revision/data/revision_repository.dart';
import 'package:preploop/features/question_bank/domain/question.dart';

import '../../helpers/pump_app.dart';
import '../concepts/concept_flow_test.dart' show openStudy, seedConcept;

/// An exam with a saved syllabus of three subjects (like a JE paper's).
FakeExamsRepository syllabusExams() => FakeExamsRepository()
  ..topicsByExam['SSC_CHSL'] = [
    const ExamTopic(
      id: 't1',
      subject: 'General Intelligence & Reasoning',
      name: 'Analogy',
      own: true,
    ),
    const ExamTopic(
      id: 't2',
      subject: 'General Intelligence & Reasoning',
      name: 'Coding-Decoding',
      own: true,
    ),
    const ExamTopic(id: 't3', subject: 'General Awareness', name: 'History', own: true),
    const ExamTopic(id: 't4', subject: 'General Engineering', name: 'Thermodynamics', own: true),
  ];

void main() {
  testAppWidgets('Study shows the syllabus subjects, then a subject\'s topics, then a topic', (
    tester,
    db,
  ) async {
    await pumpPrepLoopApp(
      tester,
      db,
      exams: syllabusExams(),
      studyProfile: onboardedProfile.copyWith(examCodes: ['SSC_CHSL']),
    );
    await openStudy(tester);

    expect(find.text('Your syllabus'), findsOneWidget);
    expect(find.text('General Intelligence & Reasoning'), findsOneWidget);
    expect(find.text('General Awareness'), findsOneWidget);
    expect(find.text('General Engineering'), findsOneWidget);
    expect(find.text('0 of 2 strong'), findsOneWidget);

    // The Subject filter offers the syllabus subjects.
    await tester.tap(find.byTooltip('Filter by Subject'));
    await tester.pumpAndSettle();
    expect(find.text('General Engineering'), findsNWidgets(2)); // card row + menu item
    await tester.tap(find.text('General Intelligence & Reasoning').last);
    await tester.pumpAndSettle();

    // The subject's topics, each with its level.
    expect(find.text('Analogy'), findsOneWidget);
    expect(find.text('Coding-Decoding'), findsOneWidget);
    expect(find.text('Not started'), findsNWidgets(2));
    expect(find.text('No concepts here yet. Add one with the button above.'), findsOneWidget);

    await tester.tap(find.text('Analogy'));
    await tester.pumpAndSettle();
    expect(find.text('Topic: Analogy'), findsOneWidget);
    expect(find.text('Start with a few practice questions or a concept.'), findsOneWidget);
    expect(find.text('No practice answers in the last 30 days'), findsOneWidget);

    // Adding a concept from the topic fills in its subject and topic.
    await tester.tap(find.text('Add a concept'));
    await tester.pumpAndSettle();
    expect(find.text('New concept'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, 'General Intelligence & Reasoning'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, 'Analogy'), findsOneWidget);
  });

  testAppWidgets('marking a topic revised from Study saves it', (tester, db) async {
    final exams = syllabusExams();
    await pumpPrepLoopApp(
      tester,
      db,
      exams: exams,
      studyProfile: onboardedProfile.copyWith(examCodes: ['SSC_CHSL']),
    );
    await openStudy(tester);
    await tester.tap(find.text('General Awareness'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('History'));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilterChip, 'Revised'));
    await tester.pumpAndSettle();
    expect(exams.topicsByExam['SSC_CHSL']!.firstWhere((t) => t.id == 't3').completed, isTrue);
    expect(find.text('Learning'), findsOneWidget); // revised, but no answers yet
  });

  testAppWidgets('revision shows only the current exam\'s cards', (tester, db) async {
    await seed(
      tester,
      () => RevisionRepository(db).addQuestions([
        bankQuestion(id: 'chsl', stem: 'A CHSL question', status: VerificationStatus.verified),
        bankQuestion(
          id: 'other',
          stem: 'A question of another exam',
          exam: 'SSC_CGL',
          status: VerificationStatus.verified,
        ),
      ]),
    );
    await seedConcept(tester, db, 'Concept of the other exam'); // SSC_CGL
    await pumpPrepLoopApp(
      tester,
      db,
      studyProfile: onboardedProfile.copyWith(examCodes: ['SSC_CHSL', 'SSC_CGL']),
    );
    await openStudy(tester);
    await tester.tap(find.byTooltip('Revision'));
    await tester.pumpAndSettle();

    await scrollTo(tester, find.textContaining('A CHSL question'));
    expect(find.textContaining('A question of another exam'), findsNothing);
    expect(find.text('Concept of the other exam'), findsNothing);
  });
}
