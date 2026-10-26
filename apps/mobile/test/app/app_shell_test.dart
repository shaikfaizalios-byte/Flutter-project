import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:preploop/app/app_shell.dart';

import '../helpers/pump_app.dart';

void main() {
  testAppWidgets('starts on Home and answers the three dashboard questions', (tester, db) async {
    await pumpPrepLoopApp(tester, db);

    expect(find.text('Your study loop'), findsOneWidget);
    expect(find.text('Today'), findsOneWidget); // plan, focus and streak in one card
    await scrollTo(tester, find.text('Which topics am I weak in?'));
    expect(find.text('Which topics am I weak in?'), findsOneWidget);
    expect(find.byType(NavigationBar), findsOneWidget);
  });

  testAppWidgets('bottom navigation switches between the five tabs', (tester, db) async {
    await pumpPrepLoopApp(tester, db);

    final tabs = {
      'Study': 'No concepts yet',
      'Practice': 'Practice questions',
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

  testAppWidgets('tablets use a labelled navigation rail with larger icons', (tester, db) async {
    tester.view.physicalSize = const Size(900, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await pumpPrepLoopApp(tester, db);

    expect(find.byType(NavigationRail), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
    final icon = tester.widget<Icon>(
      find.descendant(
        of: find.byType(NavigationRail),
        matching: find.byIcon(Icons.menu_book_outlined),
      ),
    );
    expect(icon.size, 28);
  });

  testAppWidgets('desktop sidebar names every feature and opens it', (tester, db) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await pumpPrepLoopApp(tester, db);

    final sidebar = find.byType(AppSidebar);
    expect(sidebar, findsOneWidget);
    expect(find.byType(NavigationRail), findsNothing);
    for (final label in [
      'Imported papers',
      'Question bank',
      'Repeated models',
      'Revision',
      'Bookmarks',
      'Exams and topics',
    ]) {
      expect(find.descendant(of: sidebar, matching: find.text(label)), findsOneWidget);
    }

    await tester.tap(find.descendant(of: sidebar, matching: find.text('Study')));
    await tester.pumpAndSettle();
    expect(find.text('No concepts yet'), findsOneWidget);

    await tester.tap(find.descendant(of: sidebar, matching: find.text('Imported papers')));
    await tester.pumpAndSettle();
    // The feature screen opens beside the sidebar, which stays in place.
    expect(sidebar, findsOneWidget);
    expect(find.widgetWithText(AppBar, 'Imported papers'), findsOneWidget);
  });

  testAppWidgets('home lists every feature by name', (tester, db) async {
    await pumpPrepLoopApp(tester, db);
    await scrollTo(tester, find.text('Go straight to'));
    await scrollTo(tester, find.text('Exams and topics'));
    await tester.tap(find.text('Exams and topics'));
    await tester.pumpAndSettle();
    expect(find.text('Exams and topics'), findsWidgets);
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
