import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:preploop/core/errors/app_failure.dart';

import '../../helpers/pump_app.dart';
import '../settings/settings_screen_test.dart' show openProfile;

Future<void> openPlus(WidgetTester tester) async {
  await openProfile(tester);
  await scrollTo(tester, find.text('See PrepLoop Plus'));
  await tester.tap(find.text('See PrepLoop Plus'));
  await tester.pumpAndSettle();
}

void main() {
  testAppWidgets('Profile leads to Plus: free plan, what it includes, this month\'s AI use', (
    tester,
    db,
  ) async {
    await pumpPrepLoopApp(tester, db, plus: FakePlusRepository(used: 12));
    await openPlus(tester);

    expect(find.text('Free plan'), findsOneWidget);
    expect(find.textContaining("Plus can't be bought yet"), findsOneWidget);
    expect(find.text('Start a 7-day test'), findsNothing); // not a test server
    expect(find.textContaining('Quick AI answers'), findsOneWidget);
    expect(find.text('Up to 300 AI requests a month.'), findsOneWidget);
    expect(find.textContaining("AI isn't switched on"), findsOneWidget);
    await scrollTo(tester, find.text('12 of 300 AI requests used'));
    expect(find.text('12 of 300 AI requests used'), findsOneWidget);
    expect(find.textContaining('practice, mock tests, revision'), findsOneWidget);
  });

  testAppWidgets('a test server offers a free test subscription that can be ended', (
    tester,
    db,
  ) async {
    final plus = FakePlusRepository(testMode: true);
    await pumpPrepLoopApp(tester, db, plus: plus, ai: FakeAiRepository(enabled: true));
    await openPlus(tester);
    expect(find.textContaining("AI isn't switched on"), findsNothing);

    await tester.tap(find.text('Start a 7-day test'));
    await tester.pumpAndSettle();
    expect(plus.calls, ['start:7']);
    expect(find.textContaining('Plus is active until'), findsOneWidget);
    expect(find.text('Test subscription: nothing was paid.'), findsOneWidget);

    await tester.tap(find.text('End test subscription'));
    await tester.pumpAndSettle();
    expect(plus.calls.last, 'end');
    expect(find.text('Free plan'), findsOneWidget);

    // The Profile card shows the plan too.
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    await scrollTo(tester, find.text('See PrepLoop Plus'));
    await tester.tap(find.text('See PrepLoop Plus'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Start a 7-day test'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Plus is active until'), findsOneWidget);
  });

  testAppWidgets('without a connection Plus says so and can retry', (tester, db) async {
    final plus = FakePlusRepository()..failure = const NetworkFailure();
    await pumpPrepLoopApp(tester, db, plus: plus);
    await openPlus(tester);
    expect(find.textContaining("Plus details couldn't be loaded"), findsOneWidget);

    plus.failure = null;
    await tester.tap(find.widgetWithText(OutlinedButton, 'Try again'));
    await tester.pumpAndSettle();
    expect(find.text('Free plan'), findsOneWidget);
  });
}
