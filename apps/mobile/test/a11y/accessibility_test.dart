// Accessibility pass for the main screens: Material tap-target size, labelled tap targets and
// text contrast (light and dark), and large text (2×) without layout overflow.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:preploop/features/settings/application/app_preferences.dart';

import '../helpers/pump_app.dart';

const tabs = ['Home', 'Study', 'Practice', 'Progress', 'Profile'];

Future<void> openTab(WidgetTester tester, String tab) async {
  await tester.tap(find.descendant(of: find.byType(NavigationBar), matching: find.text(tab)));
  await tester.pumpAndSettle();
}

Future<void> expectGuidelines(WidgetTester tester) async {
  await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
  await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
  await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
  await expectLater(tester, meetsGuideline(textContrastGuideline));
}

void main() {
  for (final mode in [ThemeMode.light, ThemeMode.dark]) {
    for (final tab in tabs) {
      testAppWidgets('$tab tab meets accessibility guidelines (${mode.name})', (tester, db) async {
        final semantics = tester.ensureSemantics();
        await pumpPrepLoopApp(tester, db, initialPreferences: AppPreferences(themeMode: mode));
        await openTab(tester, tab);

        await expectGuidelines(tester);
        semantics.dispose();
      });
    }
  }

  testAppWidgets('sign-in screen meets accessibility guidelines', (tester, db) async {
    final semantics = tester.ensureSemantics();
    await pumpPrepLoopApp(tester, db, session: null);

    await expectGuidelines(tester);
    semantics.dispose();
  });

  testAppWidgets('large text (2×) lays out every tab and sign-in without overflow', (
    tester,
    db,
  ) async {
    tester.platformDispatcher.textScaleFactorTestValue = 2.0;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await pumpPrepLoopApp(tester, db);

    for (final tab in tabs) {
      await openTab(tester, tab);
      expect(tester.takeException(), isNull, reason: '$tab at 2× text');
    }
  });

  testAppWidgets('large text (2×) on the sign-in screen', (tester, db) async {
    tester.platformDispatcher.textScaleFactorTestValue = 2.0;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await pumpPrepLoopApp(tester, db, session: null);

    expect(tester.takeException(), isNull);
    expect(find.text('Sign in'), findsWidgets);
  });
}
