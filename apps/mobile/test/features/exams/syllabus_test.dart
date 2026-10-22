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
    // The PDF import is a section named after the file.
    final import = exams.importsByExam['SSC_CGL']!.single;
    expect((import.name, import.kind), (samplePdf.name, SyllabusKind.pdf));
    await scrollTo(tester, find.text(samplePdf.name));
    expect(find.text(samplePdf.name), findsOneWidget);
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

  testAppWidgets('a typed syllabus is read; the last import can be removed in one step', (
    tester,
    db,
  ) async {
    final exams = FakeExamsRepository()..syllabus = syllabus;
    await pumpPrepLoopApp(
      tester,
      db,
      exams: exams,
      studyProfile: onboardedProfile.copyWith(examCodes: ['NEET_UG']),
    );
    await openMyExams(tester);
    await tester.tap(find.text('NEET UG'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Type or paste syllabus'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Maths: Number System, Profit and Loss');
    await tester.tap(find.text('Find topics'));
    await tester.pumpAndSettle();
    expect(exams.calls, contains('syllabus-text:NEET_UG'));
    expect(find.textContaining('3 topics found in what you wrote'), findsOneWidget);
    await tester.tap(find.text('Add 3 topics'));
    await tester.pumpAndSettle();
    expect(exams.topicsByExam['NEET_UG'], hasLength(3));

    // The import is its own section, named and dated, holding its topics.
    expect(exams.importsByExam['NEET_UG']!.single.name, 'Typed syllabus');
    await scrollTo(tester, find.text('Typed syllabus'));
    expect(find.textContaining('3 topics · imported'), findsOneWidget);

    await tester.pump(const Duration(seconds: 5)); // let the "added" message go
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Remove this syllabus and its topics'));
    await tester.pumpAndSettle();
    expect(find.text('Remove "Typed syllabus"?'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await tester.pumpAndSettle();
    expect(exams.topicsByExam['NEET_UG'], isEmpty);
    expect(exams.importsByExam['NEET_UG'], isEmpty);
    expect(find.text('3 topics removed.'), findsOneWidget);
    expect(find.text('Typed syllabus'), findsNothing);
  });

  testAppWidgets('several own topics are selected and removed together', (tester, db) async {
    final exams = FakeExamsRepository()
      ..topicsByExam['NEET_UG'] = [
        const ExamTopic(id: 't1', subject: 'Biology', name: 'Genetics', own: true),
        const ExamTopic(id: 't2', subject: 'Biology', name: 'Ecology', own: true),
        const ExamTopic(id: 't3', subject: 'Biology', name: 'Botany', own: true),
      ];
    await pumpPrepLoopApp(
      tester,
      db,
      exams: exams,
      studyProfile: onboardedProfile.copyWith(examCodes: ['NEET_UG']),
    );
    await openMyExams(tester);
    await tester.tap(find.text('NEET UG'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Select'));
    await tester.pumpAndSettle();
    Finder boxOf(String name) =>
        find.descendant(of: find.widgetWithText(ListTile, name), matching: find.byType(Checkbox));
    for (final name in ['Genetics', 'Botany']) {
      await tester.ensureVisible(boxOf(name));
      await tester.pumpAndSettle();
      await tester.tap(boxOf(name));
    }
    await tester.pumpAndSettle();
    expect(find.text('2 selected'), findsOneWidget);
    await tester.tap(find.text('Remove 2'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await tester.pumpAndSettle();
    expect(exams.topicsByExam['NEET_UG']!.map((t) => t.name), ['Ecology']);
    expect(find.text('2 topics removed.'), findsOneWidget);
  });
}
