import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:preploop/features/study_plan/domain/study_profile.dart';

import '../../helpers/pump_app.dart';

Future<void> openReminder(WidgetTester tester) async {
  await tester.tap(find.descendant(of: find.byType(NavigationBar), matching: find.text('Profile')));
  await tester.pumpAndSettle();
  await scrollTo(tester, find.text('Daily study reminder'));
}

final withTime = StudyProfile(
  reminderMinutes: 7 * 60 + 30,
  onboardingCompletedAt: DateTime.utc(2026, 10, 1),
);

void main() {
  testAppWidgets('switching the reminder on schedules it and says when', (tester, db) async {
    final os = FakeReminderScheduler(granted: false);
    await pumpPrepLoopApp(tester, db, studyProfile: withTime, reminders: os);
    await openReminder(tester);
    expect(find.text('Off'), findsOneWidget);
    expect(os.permissionRequests, 0); // never asked before the learner opts in

    await tester.tap(reminderSwitch);
    await tester.pumpAndSettle();

    expect(find.text('Every day at 7:30 AM'), findsOneWidget);
    expect(os.permissionRequests, 1);
    expect(os.pending, hasLength(1));

    await tester.tap(reminderSwitch);
    await tester.pumpAndSettle();
    expect(find.text('Off'), findsOneWidget);
    expect(os.pending, isEmpty);
  });

  testAppWidgets('denied permission is explained, with a way to fix it', (tester, db) async {
    final os = FakeReminderScheduler(granted: false, grantOnRequest: false);
    await pumpPrepLoopApp(tester, db, studyProfile: withTime, reminders: os);
    await openReminder(tester);

    await tester.tap(reminderSwitch);
    await tester.pumpAndSettle();

    expect(find.textContaining('Notifications are turned off for PrepLoop'), findsOneWidget);
    await scrollTo(tester, find.text('Open notification settings'));
    await tester.tap(find.text('Open notification settings'));
    await tester.pumpAndSettle();
    expect(os.settingsOpened, 1);
    expect(os.pending, isEmpty);
  });

  testAppWidgets('without a time, switching on asks for one first', (tester, db) async {
    await pumpPrepLoopApp(tester, db);
    await openReminder(tester);

    await tester.tap(reminderSwitch);
    await tester.pumpAndSettle();
    expect(find.byType(TimePickerDialog), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(find.text('Choose a reminder time to switch it on.'), findsOneWidget);
  });

  testAppWidgets('platforms without notifications say so', (tester, db) async {
    final os = FakeReminderScheduler(isSupported: false);
    await pumpPrepLoopApp(tester, db, studyProfile: withTime, reminders: os);
    await openReminder(tester);

    expect(find.text('Reminders work in the Android and iOS apps.'), findsOneWidget);
    expect(tester.widget<Switch>(reminderSwitch).onChanged, isNull);
  });
}

/// The reminder's own switch (Profile also has the Repeat Radar switch).
final reminderSwitch = find.descendant(
  of: find.widgetWithText(SwitchListTile, 'Daily study reminder'),
  matching: find.byType(Switch),
);
