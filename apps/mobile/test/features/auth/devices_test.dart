import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:preploop/features/auth/data/auth_api.dart';

import '../../helpers/pump_app.dart';
import '../settings/settings_screen_test.dart' show openProfile;

Future<void> openDevices(WidgetTester tester) async {
  await openProfile(tester);
  await scrollTo(tester, find.text('Signed-in devices'));
  await tester.tap(find.text('Signed-in devices'));
  await tester.pumpAndSettle();
}

FakeAuthApi threeDevices() => FakeAuthApi()
  ..deviceList = [
    SignedInDevice(
      id: 'here',
      platform: 'android',
      signedInAt: DateTime.utc(2026, 10, 1, 9),
      lastActiveAt: DateTime.utc(2026, 11, 1, 9),
      current: true,
    ),
    SignedInDevice(
      id: 'laptop',
      platform: 'web',
      signedInAt: DateTime.utc(2026, 10, 20, 9),
      lastActiveAt: DateTime.utc(2026, 10, 30, 9),
    ),
    SignedInDevice(
      id: 'old',
      signedInAt: DateTime.utc(2026, 9, 1, 9),
      lastActiveAt: DateTime.utc(2026, 9, 2, 9),
    ),
  ];

void main() {
  testAppWidgets('Profile lists signed-in devices, this one first, by kind only', (
    tester,
    db,
  ) async {
    await pumpPrepLoopApp(tester, db, authApi: threeDevices());
    await openDevices(tester);

    expect(find.text('Android phone or tablet'), findsOneWidget);
    expect(find.textContaining('This device'), findsOneWidget);
    expect(find.text('Web browser'), findsOneWidget);
    expect(find.text('Device signed in before this list existed'), findsOneWidget);
    // Only other devices can be signed out from here.
    expect(find.widgetWithText(TextButton, 'Sign out'), findsNWidgets(2));
  });

  testAppWidgets('a device is signed out after confirming', (tester, db) async {
    final api = threeDevices();
    await pumpPrepLoopApp(tester, db, authApi: api);
    await openDevices(tester);

    await tester.tap(find.widgetWithText(TextButton, 'Sign out').first);
    await tester.pumpAndSettle();
    expect(find.text('Sign out Web browser?'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Sign out'));
    await tester.pumpAndSettle();

    expect(api.signedOutDevices, ['laptop']);
    expect(find.text('Web browser'), findsNothing);
    expect(find.text('1 device signed out.'), findsOneWidget);
  });

  testAppWidgets('all other devices can be signed out at once', (tester, db) async {
    final api = threeDevices();
    await pumpPrepLoopApp(tester, db, authApi: api);
    await openDevices(tester);

    await tester.tap(find.widgetWithText(OutlinedButton, 'Sign out all other devices'));
    await tester.pumpAndSettle();
    expect(find.text('2 other devices will be signed out straight away.'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Sign out all other devices'));
    await tester.pumpAndSettle();

    expect(api.signedOutDevices, ['laptop', 'old']);
    expect(find.text('2 devices signed out.'), findsOneWidget);
    expect(find.widgetWithText(OutlinedButton, 'Sign out all other devices'), findsNothing);
  });

  testAppWidgets('an expired access token is refreshed once, then the list loads', (
    tester,
    db,
  ) async {
    final api = threeDevices()..devicesNeedRefresh = true;
    await pumpPrepLoopApp(tester, db, authApi: api);
    await openDevices(tester);

    expect(api.refreshCount, 1);
    expect(find.text('Web browser'), findsOneWidget);
  });

  testAppWidgets('offline: says so and offers to try again', (tester, db) async {
    final api = threeDevices();
    await pumpPrepLoopApp(tester, db, authApi: api);
    api.offline = true;
    await openDevices(tester);

    expect(find.text('Could not load your devices'), findsOneWidget);
    api.offline = false;
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();
    expect(find.text('Web browser'), findsOneWidget);
  });
}
