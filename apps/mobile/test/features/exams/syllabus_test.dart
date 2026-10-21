import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:preploop/features/exams/application/syllabus_prompt.dart';
import 'package:preploop/features/exams/domain/exam_topics.dart';

import '../../helpers/pump_app.dart';
import '../documents/documents_screen_test.dart'
    show FakeDocumentsRepository, openDocuments, overridesFor, samplePdf;
import 'exams_test.dart' show openMyExams;

const syllabus = SyllabusDraft(
  pages: 2,
  readBy: 'text',
  unreadablePages: 0,
  topics: [
    NewTopic(subject: 'Quantitative Ability', name: 'Number System'),
    NewTopic(subject: 'Quantitative Ability', name: 'Profit and Loss'),
    NewTopic(subject: 'Verbal Ability', name: 'Para Jumbles'),
  ],
);

void main() {
  testAppWidgets('before the first paper the learner is asked for the syllabus; it is imported', (
    tester,
    db,
  ) async {
    final exams = FakeExamsRepository()..syllabus = syllabus;
    final docs = FakeDocumentsRepository();
    await pumpPrepLoopApp(
      tester,
      db,
      exams: exams,
      studyProfile: onboardedProfile.copyWith(examCodes: ['SSC_CGL']),
      extraOverrides: overridesFor(docs, picked: samplePdf),
    );
    await openDocuments(tester, docs);

    await tester.tap(find.text('Import PDF'));
    await tester.pumpAndSettle();
    expect(find.text('Add the SSC CGL syllabus first?'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Import syllabus PDF'));
    await tester.pumpAndSettle();

    // The topics screen opened and read the picked PDF as a syllabus; nothing was uploaded.
    expect(exams.calls, contains('syllabus:SSC_CGL:${samplePdf.name}'));
    expect(docs.uploads, isEmpty);
    expect(find.textContaining('3 topics read from the syllabus (2 pages)'), findsOneWidget);
    await tester.tap(find.text('Verbal Ability › Para Jumbles')); // untick one
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add 2 topics'));
    await tester.pumpAndSettle();

    expect(exams.topicsByExam['SSC_CGL']!.map((t) => t.name), ['Number System', 'Profit and Loss']);
    expect(find.text('0 of 2 topics revised'), findsOneWidget);
  });

  testAppWidgets('skipping the syllabus is remembered for that exam', (tester, db) async {
    final docs = FakeDocumentsRepository();
    await pumpPrepLoopApp(
      tester,
      db,
      studyProfile: onboardedProfile.copyWith(examCodes: ['SSC_CGL']),
      extraOverrides: overridesFor(docs, picked: samplePdf),
    );
    await openDocuments(tester, docs);

    await tester.tap(find.text('Import PDF'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Skip for now'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Import "'), findsOneWidget); // the paper import continues
    expect(await syllabusSkipped(db, 'SSC_CGL'), isTrue);
  });

  testAppWidgets('topics are ticked as revised; the syllabus card asks while none are own', (
    tester,
    db,
  ) async {
    final exams = FakeExamsRepository();
    await pumpPrepLoopApp(
      tester,
      db,
      exams: exams,
      studyProfile: onboardedProfile.copyWith(examCodes: ['NEET_UG']),
    );
    await openMyExams(tester);
    await tester.tap(find.text('NEET UG'));
    await tester.pumpAndSettle();
    expect(find.text('Add your syllabus'), findsOneWidget);

    exams.topicsByExam['NEET_UG'] = [
      const ExamTopic(id: 't1', subject: 'Biology', name: 'Genetics', own: true),
      const ExamTopic(id: 't2', subject: 'Biology', name: 'Ecology', own: true),
    ];
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('NEET UG'));
    await tester.pumpAndSettle();
    expect(find.text('Syllabus'), findsOneWidget);
    expect(find.text('0 of 2 topics revised'), findsOneWidget);

    await tester.tap(find.bySemanticsLabel('Genetics revised'));
    await tester.pumpAndSettle();
    expect(exams.calls, contains('completed:t1:true'));
    expect(find.text('1 of 2 topics revised'), findsOneWidget);
    expect(find.textContaining('Your topic · Revised'), findsOneWidget);
  });
}
