import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:preploop/app/app_features.dart';
import 'package:preploop/core/utils/calendar_date.dart';
import 'package:preploop/features/exams/domain/new_exam.dart';
import 'package:preploop/features/exams/presentation/exam_builder_screen.dart';
import 'package:preploop/features/study_plan/domain/study_profile.dart';

import '../../helpers/pump_app.dart';
import 'exams_test.dart' show openMyExams;

final profilesOn = appFeaturesProvider.overrideWithValue(const AppFeatures(examProfiles: true));

void main() {
  test('only what was entered is sent, and a null option count is kept', () {
    final json = const NewExam(name: 'Board', kind: 'mcq', optionsPerQuestion: null).toJson();
    expect(json, {'name': 'Board', 'kind': 'mcq', 'options_per_question': null});
    final full = NewExam(
      name: 'Board',
      kind: 'mixed',
      optionsPerQuestion: 5,
      conductingBody: 'State Board',
      languages: const ['en'],
      examDates: [CalendarDate(2027, 3, 14)],
      stages: const [
        NewStage(
          name: 'Written',
          durationMinutes: 120,
          marksCorrect: 2,
          marksWrong: 0.5,
          sections: [NewSection(name: 'A', questionCount: 50, cutoff: 20)],
        ),
      ],
    ).toJson();
    expect(full['exam_dates'], ['2027-03-14']);
    expect(full['stages'], [
      {
        'name': 'Written',
        'duration_minutes': 120,
        'sections': [
          {'name': 'A', 'question_count': 50, 'cutoff': 20.0},
        ],
        'marking_scheme': {'marks_correct': 2.0, 'marks_wrong': 0.5},
      },
    ]);
  });

  testAppWidgets('the flag off keeps today\'s wording and name-only exams', (tester, db) async {
    await pumpPrepLoopApp(tester, db, studyProfile: const StudyProfile());
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    expect(find.text('Which exam are you preparing for?'), findsOneWidget);
    expect(find.text('Select one or both.'), findsOneWidget);
    expect(find.text('Custom exam'), findsNothing);
  });

  testAppWidgets('onboarding: a custom exam needs a name and is then chosen', (tester, db) async {
    final exams = FakeExamsRepository();
    await pumpPrepLoopApp(
      tester,
      db,
      exams: exams,
      studyProfile: const StudyProfile(),
      extraOverrides: [profilesOn],
    );
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    expect(find.text('What are you preparing for?'), findsOneWidget);
    await tester.tap(find.text('Custom exam'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Create exam').first);
    await tester.pumpAndSettle();
    expect(find.text('Needed'), findsOneWidget);
    expect(exams.created, isEmpty);

    await tester.enterText(find.byType(TextFormField).first, 'State Board Exam');
    await tester.tap(find.text('Create exam').first);
    await tester.pumpAndSettle();

    expect(exams.created.single.name, 'State Board Exam');
    expect(find.widgetWithText(FilterChip, 'State Board Exam'), findsOneWidget);
  });

  testAppWidgets('my exams: stages and marking are sent as entered', (tester, db) async {
    final exams = FakeExamsRepository();
    await pumpPrepLoopApp(tester, db, exams: exams, extraOverrides: [profilesOn]);
    await openMyExams(tester);
    await tester.ensureVisible(find.text('Create my own exam').first);
    await tester.tap(find.text('Create my own exam').first);
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField).first, 'Board');
    final form = find.descendant(
      of: find.byType(ExamBuilderScreen),
      matching: find.byType(ListView),
    );
    await tester.dragUntilVisible(find.text('Add a stage'), form, const Offset(0, -200));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add a stage'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextFormField, 'Stage name'), 'Written');
    await tester.enterText(find.widgetWithText(TextFormField, 'Minutes'), '90');
    await tester.enterText(find.widgetWithText(TextFormField, 'Marks for a correct answer'), '2');
    await tester.enterText(find.widgetWithText(TextFormField, 'Marks off for a wrong answer'), '0');
    await tester.enterText(find.widgetWithText(TextFormField, 'Section name'), 'Part A');
    await tester.enterText(find.widgetWithText(TextFormField, 'Questions'), '40');
    await tester.tap(find.text('Create exam').first);
    await tester.pumpAndSettle();

    final stage = exams.created.single.stages.single;
    expect(stage.name, 'Written');
    expect(stage.durationMinutes, 90);
    expect(stage.sections.single.questionCount, 40);
  });
}
