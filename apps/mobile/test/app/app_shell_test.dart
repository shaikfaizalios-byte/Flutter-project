import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/pump_app.dart';

void main() {
  testAppWidgets('starts on Home and answers the three dashboard questions', (tester, db) async {
    await pumpPrepLoopApp(tester, db);

    expect(find.text('Your study loop'), findsOneWidget);
    expect(find.text('What should I study today?'), findsOneWidget);
    expect(find.text('Which topics am I weak in?'), findsOneWidget);
    await scrollTo(tester, find.text('What is coming up next?'));
    expect(find.text('What is coming up next?'), findsOneWidget);
    expect(find.byType(NavigationBar), findsOneWidget);
  });

  testAppWidgets('bottom navigation switches between the five tabs', (tester, db) async {
    await pumpPrepLoopApp(tester, db);

    final tabs = {
      'Study': 'No concepts yet',
      'Practice': 'Practice sessions',
      'Progress': 'No progress data yet',
      'Profile': 'Profile & settings',
      'Home': 'Your study loop',
    };
    for (final MapEntry(key: tab, value: expected) in tabs.entries) {
      await tester.tap(find.descendant(of: find.byType(NavigationBar), matching: find.text(tab)));
      await tester.pumpAndSettle();
      expect(find.text(expected), findsOneWidget, reason: 'after tapping $tab');
    }
  });

  testAppWidgets('wide screens use a navigation rail', (tester, db) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await pumpPrepLoopApp(tester, db);

    expect(find.byType(NavigationRail), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
  });

  testAppWidgets('primary screen meets tap-target and labelling guidelines', (tester, db) async {
    final semantics = tester.ensureSemantics();
    await pumpPrepLoopApp(tester, db);

    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    await expectLater(tester, meetsGuideline(textContrastGuideline));
    semantics.dispose();
  });
}
