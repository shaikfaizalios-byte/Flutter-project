import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:preploop/core/utils/calendar_date.dart';
import 'package:preploop/features/study_plan/data/study_profile_repository.dart';

import '../../helpers/pump_app.dart';

Future<void> openProfile(WidgetTester tester) async {
  await tester.tap(find.descendant(of: find.byType(NavigationBar), matching: find.text('Profile')));
  await tester.pumpAndSettle();
  // The account section comes first; bring the study plan into view.
  await scrollTo(tester, find.text('Exam date'));
}

void main() {
  testAppWidgets('shows the onboarding answers', (tester, db) async {
    await pumpPrepLoopApp(
      tester,
      db,
      studyProfile: onboardedProfile.copyWith(
        examCodes: ['SSC_CGL', 'SSC_CHSL'],
        targetExamDate: () => CalendarDate(2027, 3, 9),
        dailyStudyMinutes: () => 45,
        reminderMinutes: () => 19 * 60 + 30,
      ),
    );
    await openProfile(tester);

    expect(find.text('Study plan'), findsOneWidget);
    expect(find.text('Mar 9, 2027'), findsOneWidget);
    expect(find.text('45 min'), findsOneWidget);
    expect(find.text('7:30 PM'), findsOneWidget);
  });

  testAppWidgets('unset values read "Not set"', (tester, db) async {
    await pumpPrepLoopApp(tester, db);
    await openProfile(tester);

    expect(find.text('Not set'), findsNWidgets(3));
  });

  testAppWidgets('clearing the exam date', (tester, db) async {
    await pumpPrepLoopApp(
      tester,
      db,
      studyProfile: onboardedProfile.copyWith(targetExamDate: () => CalendarDate(2027, 3, 9)),
    );
    await openProfile(tester);

    await tester.tap(find.byTooltip('Clear'));
    await tester.pumpAndSettle();

    expect(find.text('Mar 9, 2027'), findsNothing);
    final stored = await seed(tester, () => StudyProfileRepository(db).load());
    expect(stored.targetExamDate, isNull);
  });

  testAppWidgets('daily study time can be changed and cleared', (tester, db) async {
    await pumpPrepLoopApp(tester, db);
    await openProfile(tester);
    await scrollTo(tester, find.text('Daily study time'));

    await tester.tap(find.text('Daily study time'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('2 h'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
    expect(find.text('2 h'), findsOneWidget);

    await tester.tap(find.text('Daily study time'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ChoiceChip, '2 h'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();

    final stored = await seed(tester, () => StudyProfileRepository(db).load());
    expect(stored.dailyStudyMinutes, isNull);
  });
}
