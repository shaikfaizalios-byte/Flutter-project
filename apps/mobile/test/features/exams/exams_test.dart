import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:preploop/core/errors/app_failure.dart';
import 'package:preploop/features/exams/domain/exam_topics.dart';

import '../../helpers/pump_app.dart';
import '../question_bank/question_bank_test.dart' show openPractice, openQuestion;
import '../settings/study_plan_section_test.dart' show openProfile;

Future<void> openExamChooser(WidgetTester tester) async {
  await openProfile(tester);
  await tester.tap(find.text('Exams'));
  await tester.pumpAndSettle();
}

Future<void> openMyExams(WidgetTester tester) async {
  await openProfile(tester);
  await scrollTo(tester, find.text('Exams and topics'));
  await tester.tap(find.text('Exams and topics'));
  await tester.pumpAndSettle();
}

void main() {
  testAppWidgets('more exams: search the catalog and choose any exam', (tester, db) async {
    await pumpPrepLoopApp(tester, db);
    await openExamChooser(tester);

    // Featured exams are chips; the rest are behind "More exams".
    expect(find.text('SSC CGL'), findsWidgets);
    expect(find.text('NEET UG'), findsNothing);
    await tester.tap(find.text('More exams'));
    await tester.pumpAndSettle();
    expect(find.text('Banking'), findsOneWidget);
    expect(find.text('IBPS PO'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'neet');
    await tester.pumpAndSettle();
    expect(find.text('IBPS PO'), findsNothing);
    await tester.tap(find.text('NEET UG'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Done (1 chosen)'));
    await tester.pumpAndSettle();

    // The chosen exam now shows as a chip and in the study plan.
    expect(find.widgetWithText(FilterChip, 'NEET UG'), findsOneWidget);
  });

  testAppWidgets('creating my own exam selects it and keeps it private', (tester, db) async {
    final exams = FakeExamsRepository();
    await pumpPrepLoopApp(tester, db, exams: exams);
    await openExamChooser(tester);
    await tester.tap(find.text('More exams'));
    await tester.pumpAndSettle();

    await scrollTo(tester, find.text('Create my own exam'));
    await tester.tap(find.text('Create my own exam'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'Rajasthan Patwari');
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();

    expect(exams.calls, ['create:Rajasthan Patwari']);
    expect(find.text('My own exams'), findsOneWidget);
    expect(find.text('Done (1 chosen)'), findsOneWidget);
  });

  testAppWidgets('my exams: own exam topics, duplicates refused, AI draft kept in part', (
    tester,
    db,
  ) async {
    final exams = FakeExamsRepository()
      ..draft = const TopicDraft(
        model: 'fake-model',
        questionsConsidered: 40,
        topics: [
          NewTopic(subject: 'Biology', name: 'Genetics', keywords: ['gene']),
          NewTopic(subject: 'Physics', name: 'Optics', keywords: ['lens']),
        ],
      );
    await pumpPrepLoopApp(
      tester,
      db,
      exams: exams,
      ai: FakeAiRepository(enabled: true),
      studyProfile: onboardedProfile.copyWith(examCodes: ['NEET_UG']),
    );
    await openMyExams(tester);
    expect(find.text('NEET UG'), findsOneWidget);
    await tester.tap(find.text('NEET UG'));
    await tester.pumpAndSettle();
    expect(find.text('NEET UG: topics'), findsOneWidget);
    expect(find.text('No topics yet'), findsOneWidget);

    Future<void> addTopic(String subject, String name) async {
      await tester.tap(find.widgetWithText(FloatingActionButton, 'Add topic'));
      await tester.pumpAndSettle();
      final fields = find.byType(TextField);
      await tester.enterText(fields.at(0), subject);
      await tester.enterText(fields.at(1), name);
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pumpAndSettle();
    }

    await addTopic('Biology', 'Cell Biology');
    expect(find.text('Cell Biology'), findsOneWidget);
    expect(find.text('Your topic'), findsOneWidget);
    await addTopic('biology', 'cell biology');
    expect(find.text('This exam already has that topic.'), findsOneWidget);
    await tester.pump(const Duration(seconds: 5)); // let the message go
    await tester.pumpAndSettle();

    // AI draft: a notice first, then only kept topics are saved.
    await tester.tap(find.text('Draft topics from my papers (AI)'));
    await tester.pumpAndSettle();
    expect(find.textContaining('sent to the AI service'), findsOneWidget);
    await tester.tap(find.text('Send to AI'));
    await tester.pumpAndSettle();
    expect(find.textContaining('AI suggestion from 40 of your questions'), findsOneWidget);
    await tester.tap(find.text('Physics › Optics'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add 1 topics'));
    await tester.pumpAndSettle();
    expect(find.text('1 topics added.'), findsOneWidget);
    expect(exams.topicsByExam['NEET_UG']!.map((t) => t.name), ['Cell Biology', 'Genetics']);
  });

  testAppWidgets('an own exam in use cannot be deleted; an unused one can', (tester, db) async {
    final exams = FakeExamsRepository();
    await pumpPrepLoopApp(tester, db, exams: exams);
    await openMyExams(tester);

    await tester.tap(find.widgetWithText(FloatingActionButton, 'Create my own exam'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Patwari');
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();
    expect(find.text('My own exam (only you see it)'), findsOneWidget);

    exams.inUse.add('MY_1');
    await tester.tap(find.byTooltip('More actions'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete').last);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await tester.pumpAndSettle();
    expect(find.textContaining('still use this exam'), findsOneWidget);
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();

    exams.inUse.clear();
    await tester.tap(find.byTooltip('More actions'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete').last);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await tester.pumpAndSettle();
    expect(find.text('Exam deleted.'), findsOneWidget);
    expect(find.text('Patwari'), findsNothing);
  });

  testAppWidgets('the topic picker asks for the question\'s own exam', (tester, db) async {
    final questions = FakeQuestionsRepository([bankQuestion(exam: 'NEET_UG')]);
    await pumpPrepLoopApp(tester, db, questions: questions);
    await openPractice(tester);
    await openQuestion(tester, 'Q.1');

    expect(find.text('NEET UG'), findsOneWidget); // exam chip uses the catalog name
    await scrollTo(tester, find.text('Topic'));
    expect(questions.topicRequests, contains('NEET_UG'));
  });

  testAppWidgets('draft needs imported papers: explained', (tester, db) async {
    final exams = FakeExamsRepository()
      ..draftFailure = const ServerFailure(statusCode: 422, code: 'not_eligible');
    await pumpPrepLoopApp(
      tester,
      db,
      exams: exams,
      ai: FakeAiRepository(enabled: true),
      studyProfile: onboardedProfile.copyWith(examCodes: ['NEET_UG']),
    );
    await openMyExams(tester);
    await tester.tap(find.text('NEET UG'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Draft topics from my papers (AI)'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Send to AI'));
    await tester.pumpAndSettle();
    expect(find.text('Import at least one paper of this exam first.'), findsOneWidget);
  });
}
