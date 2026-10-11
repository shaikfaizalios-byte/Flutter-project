import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/pump_app.dart';

void main() {
  testWidgets('starts on Home and answers the three dashboard questions', (tester) async {
    await pumpPrepLoopApp(tester);

    expect(find.text('Your study loop'), findsOneWidget);
    expect(find.text('What should I study today?'), findsOneWidget);
    expect(find.text('Which topics am I weak in?'), findsOneWidget);
    expect(find.text('What is coming up next?'), findsOneWidget);
    expect(find.byType(NavigationBar), findsOneWidget);
  });

  testWidgets('bottom navigation switches between the five tabs', (tester) async {
    await pumpPrepLoopApp(tester);

    final tabs = {
      'Study': 'Your study material lives here',
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

  testWidgets('wide screens use a navigation rail', (tester) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await pumpPrepLoopApp(tester);

    expect(find.byType(NavigationRail), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
  });

  testWidgets('primary screen meets tap-target and labelling guidelines', (tester) async {
    final semantics = tester.ensureSemantics();
    await pumpPrepLoopApp(tester);

    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    await expectLater(tester, meetsGuideline(textContrastGuideline));
    semantics.dispose();
  });
}
