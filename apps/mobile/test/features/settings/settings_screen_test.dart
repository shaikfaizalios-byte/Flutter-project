import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/pump_app.dart';

Future<void> openProfile(WidgetTester tester) async {
  await tester.tap(find.descendant(of: find.byType(NavigationBar), matching: find.text('Profile')));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('shows connected server status', (tester) async {
    await pumpPrepLoopApp(tester);
    await openProfile(tester);

    expect(find.text('Connected · API 0.1.0'), findsOneWidget);
  });

  testWidgets('shows offline state and retries on request', (tester) async {
    final repo = FakeServerStatusRepository(online: false);
    await pumpPrepLoopApp(tester, serverStatus: repo);
    await openProfile(tester);

    expect(find.text('Cannot reach the PrepLoop server.'), findsOneWidget);
    expect(repo.calls, 1);

    repo.online = true;
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();

    expect(repo.calls, 2);
    expect(find.text('Connected · API 0.1.0'), findsOneWidget);
  });

  testWidgets('switching language to Hindi localises the interface', (tester) async {
    await pumpPrepLoopApp(tester);
    await openProfile(tester);

    await tester.tap(find.text('हिन्दी'));
    await tester.pumpAndSettle();

    expect(find.text('प्रोफ़ाइल और सेटिंग्स'), findsOneWidget);
    expect(find.text('होम'), findsOneWidget);
    expect(find.text('Home'), findsNothing);
  });

  testWidgets('follows a Hindi device locale by default', (tester) async {
    await pumpPrepLoopApp(tester, deviceLocale: const Locale('hi', 'IN'));

    expect(find.text('आज मुझे क्या पढ़ना चाहिए?'), findsOneWidget);
  });

  testWidgets('switching theme to dark applies the dark theme', (tester) async {
    await pumpPrepLoopApp(tester);
    await openProfile(tester);

    await tester.tap(find.text('Dark'));
    await tester.pumpAndSettle();

    final context = tester.element(find.text('Profile & settings'));
    expect(Theme.of(context).brightness, Brightness.dark);
  });
}
