import 'package:flutter_test/flutter_test.dart';
import 'package:preploop/core/utils/calendar_date.dart';

import '../../helpers/pump_app.dart';

void main() {
  testAppWidgets('prompts to choose an exam when none is selected', (tester, db) async {
    await pumpPrepLoopApp(tester, db);

    expect(find.text('Choose your exam'), findsOneWidget);
    expect(find.text('You have not added any concepts yet.'), findsNothing);
  });

  testAppWidgets('one Today card: the exam, ways to start, focus and streak', (tester, db) async {
    await pumpPrepLoopApp(
      tester,
      db,
      studyProfile: onboardedProfile.copyWith(examCodes: ['SSC_CGL'], dailyStudyMinutes: () => 60),
    );

    expect(find.text('Choose your exam'), findsNothing);
    expect(find.text('Showing SSC CGL'), findsOneWidget);
    expect(find.text('Today'), findsOneWidget);
    // What to do, how long, then focus time against the goal, all in the one card.
    expect(find.text('1 thing to do'), findsOneWidget);
    expect(find.text('Practise mixed questions'), findsOneWidget);
    expect(find.text('About 15 min planned for your 60-minute daily goal.'), findsOneWidget);
    expect(find.text('0 of 60 min focused today'), findsOneWidget);
    // Hidden for now.
    expect(find.text('Another'), findsNothing);
  });

  testAppWidgets('counts down to the exam date', (tester, db) async {
    // testNow is 12 Oct 2026.
    await pumpPrepLoopApp(
      tester,
      db,
      studyProfile: onboardedProfile.copyWith(targetExamDate: () => CalendarDate(2026, 10, 22)),
    );
    await scrollTo(tester, find.textContaining('10 days to go'));

    expect(find.textContaining('10 days to go'), findsOneWidget);
  });

  testAppWidgets('handles exam day and past dates', (tester, db) async {
    await pumpPrepLoopApp(
      tester,
      db,
      studyProfile: onboardedProfile.copyWith(targetExamDate: () => CalendarDate(2026, 10, 12)),
    );
    await scrollTo(tester, find.textContaining('Your exam is today'));
    expect(find.textContaining('Your exam is today'), findsOneWidget);
  });

  testAppWidgets('says when the exam date has passed', (tester, db) async {
    await pumpPrepLoopApp(
      tester,
      db,
      studyProfile: onboardedProfile.copyWith(targetExamDate: () => CalendarDate(2026, 9, 1)),
    );
    final passed = find.textContaining('Your exam date has passed.');
    await scrollTo(tester, passed);
    expect(passed, findsOneWidget);
  });

  testAppWidgets('weak topics stay an honest empty state', (tester, db) async {
    await pumpPrepLoopApp(tester, db);

    await scrollTo(tester, find.textContaining('Not enough practice data yet'));
    expect(find.textContaining('Not enough practice data yet'), findsOneWidget);
  });
}
