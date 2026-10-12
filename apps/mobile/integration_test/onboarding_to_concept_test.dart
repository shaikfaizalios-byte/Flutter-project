// End-to-end flow on a real device or emulator:
//   flutter test integration_test -d <device-id>
// Uses an in-memory database so runs never touch the app's real data.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:preploop/features/study_plan/domain/study_profile.dart';

import '../test/helpers/pump_app.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testAppWidgets('fresh install: onboarding → create a concept → view it', (tester, db) async {
    await pumpPrepLoopApp(tester, db, studyProfile: const StudyProfile());

    // Onboarding: choose SSC CGL and a daily goal, skip the optional rest.
    expect(find.text('Welcome to PrepLoop'), findsOneWidget);
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('SSC CGL'));
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('1 h'));
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Start studying'));
    await tester.pumpAndSettle();
    expect(find.text('Daily study goal: 1 h'), findsOneWidget);

    // Create a concept from the Study tab.
    await tester.tap(find.descendant(of: find.byType(NavigationBar), matching: find.text('Study')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add concept'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextFormField, 'Title'), 'Simple interest');
    await tester.enterText(find.widgetWithText(TextFormField, 'Subject'), 'Quantitative Aptitude');
    await tester.enterText(find.widgetWithText(TextFormField, 'Topic'), 'Interest');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    // Open it.
    await tester.tap(find.text('Simple interest'));
    await tester.pumpAndSettle();
    expect(find.text('Quantitative Aptitude › Interest'), findsOneWidget);
    expect(find.text('SSC CGL'), findsOneWidget);
  });
}
