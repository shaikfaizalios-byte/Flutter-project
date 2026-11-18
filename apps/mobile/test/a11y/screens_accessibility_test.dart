// Accessibility pass beyond the tabs: the screens learners spend their time on. Labelled and
// large enough tap targets, text contrast, light and dark, and 2× text without overflow.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:preploop/app/theme/app_theme.dart';
import 'package:preploop/core/database/app_database.dart';
import 'package:preploop/features/snap/presentation/snap_screen.dart';
import 'package:preploop/features/settings/application/app_preferences.dart';

import '../features/practice/practice_flow_test.dart' show pumpPractice, startPractice;
import '../features/question_bank/question_bank_test.dart'
    show openPractice, openQuestion, sampleBank;
import '../helpers/pump_app.dart';
import 'accessibility_test.dart' show expectGuidelines;

/// Screens reached by their route.
const routes = {
  'Snap a question': '/study/snap',
  'Current affairs': '/study/current-affairs',
  'Revision': '/study/revision',
  'Imported papers': '/study/documents',
  'Ladder topics': '/ladder/topics',
};

Future<void> pumpAt(WidgetTester tester, AppDatabase db, String route, ThemeMode mode) async {
  await pumpPrepLoopApp(
    tester,
    db,
    questions: sampleBank(),
    studyProfile: onboardedProfile.copyWith(examCodes: ['SSC_CHSL']),
    initialPreferences: AppPreferences(themeMode: mode),
  );
  unawaited(GoRouter.of(tester.element(find.byType(Scaffold).first)).push(route));
  await tester.pumpAndSettle();
}

void main() {
  for (final mode in [ThemeMode.light, ThemeMode.dark]) {
    for (final MapEntry(key: name, value: route) in routes.entries) {
      testAppWidgets('$name meets accessibility guidelines (${mode.name})', (tester, db) async {
        final semantics = tester.ensureSemantics();
        await pumpAt(tester, db, route, mode);
        await expectGuidelines(tester);
        semantics.dispose();
      });
    }

    testAppWidgets('a practice question meets accessibility guidelines (${mode.name})', (
      tester,
      db,
    ) async {
      final semantics = tester.ensureSemantics();
      await pumpPractice(tester, db);
      await startPractice(tester);
      await expectGuidelines(tester);
      semantics.dispose();
    });

    testAppWidgets('question review meets accessibility guidelines (${mode.name})', (
      tester,
      db,
    ) async {
      final semantics = tester.ensureSemantics();
      await pumpPrepLoopApp(
        tester,
        db,
        questions: sampleBank(),
        initialPreferences: AppPreferences(themeMode: mode),
      );
      await openPractice(tester);
      await openQuestion(tester, 'Q.2');
      await expectGuidelines(tester);
      semantics.dispose();
    });
  }

  for (final MapEntry(key: name, value: route) in routes.entries) {
    testAppWidgets('$name lays out at 2× text', (tester, db) async {
      tester.platformDispatcher.textScaleFactorTestValue = 2.0;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await pumpAt(tester, db, route, ThemeMode.light);
      expect(tester.takeException(), isNull);
    });
  }

  testAppWidgets('a practice question lays out at 2× text', (tester, db) async {
    tester.platformDispatcher.textScaleFactorTestValue = 2.0;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await pumpPractice(tester, db);
    await startPractice(tester);
    expect(tester.takeException(), isNull);
  });

  testAppWidgets('with animations removed on the device, pages open without a transition', (
    tester,
    db,
  ) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(
      disableAnimations: true,
    );
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    await pumpAt(tester, db, '/study/snap', ThemeMode.light);
    final context = tester.element(find.byType(SnapScreen));
    expect(Theme.of(context).pageTransitionsTheme, AppTheme.noTransitions);
  });

  testAppWidgets('by default pages keep their transition', (tester, db) async {
    await pumpAt(tester, db, '/study/snap', ThemeMode.light);
    final context = tester.element(find.byType(SnapScreen));
    expect(Theme.of(context).pageTransitionsTheme, isNot(AppTheme.noTransitions));
  });
}
