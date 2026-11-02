import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:preploop/core/localization/content_language.dart';
import 'package:preploop/features/settings/application/app_preferences.dart';
import 'package:preploop/features/settings/presentation/settings_screen.dart';

import '../../helpers/pump_app.dart';

Future<void> openProfile(WidgetTester tester) async {
  await tester.tap(find.descendant(of: find.byType(NavigationBar), matching: find.text('Profile')));
  await tester.pumpAndSettle();
}

void main() {
  testAppWidgets('shows connected server status', (tester, db) async {
    await pumpPrepLoopApp(tester, db);
    await openProfile(tester);
    await scrollTo(tester, find.text('Connected · API 0.1.0'));

    expect(find.text('Connected · API 0.1.0'), findsOneWidget);
  });

  testAppWidgets('shows offline state and retries on request', (tester, db) async {
    final repo = FakeServerStatusRepository(online: false);
    await pumpPrepLoopApp(tester, db, serverStatus: repo);
    await openProfile(tester);
    await scrollTo(tester, find.text('Try again'));

    expect(find.text('Cannot reach the PrepLoop server.'), findsOneWidget);
    expect(repo.calls, 1);

    repo.online = true;
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();

    expect(repo.calls, 2);
    expect(find.text('Connected · API 0.1.0'), findsOneWidget);
  });

  testAppWidgets('switching language to Hindi localises the interface', (tester, db) async {
    await pumpPrepLoopApp(tester, db);
    await openProfile(tester);

    // The first Hindi button is the app's language (the others are content languages).
    final appHindi = find
        .descendant(of: find.byType(SettingsScreen), matching: find.text('हिन्दी'))
        .first;
    await scrollWithin(tester, SettingsScreen, find.text('Papers, syllabus and notes'));
    await tester.ensureVisible(appHindi);
    await tester.pumpAndSettle();
    await tester.tap(appHindi);
    await tester.pumpAndSettle();

    expect(find.text('प्रोफ़ाइल और सेटिंग्स'), findsOneWidget);
    expect(find.text('होम'), findsOneWidget);
    expect(find.text('Home'), findsNothing);
  });

  testAppWidgets('papers and AI lessons can have their own language', (tester, db) async {
    await pumpPrepLoopApp(tester, db);
    await openProfile(tester);
    await scrollTo(tester, find.text('AI lessons and checks'));
    expect(find.text('Same as app'), findsNWidgets(2));

    // Papers, syllabus and notes in Hindi while the app stays in English.
    final papersHindi = find
        .descendant(of: find.byType(SettingsScreen), matching: find.text('हिन्दी'))
        .at(1);
    await scrollWithin(tester, SettingsScreen, find.text('Papers, syllabus and notes'));
    await tester.ensureVisible(papersHindi);
    await tester.pumpAndSettle();
    await tester.tap(papersHindi);
    await tester.pumpAndSettle();

    final prefs = ProviderScope.containerOf(tester.element(find.byType(SettingsScreen)))
        .read(appPreferencesProvider);
    expect(prefs.contentLanguage, ContentLanguage.hindi);
    expect(prefs.aiLanguage, isNull);
    expect(find.text('Home'), findsOneWidget); // the interface language is unchanged
    expect(find.textContaining("in their question's language"), findsOneWidget);
  });

  testAppWidgets('follows a Hindi device locale by default', (tester, db) async {
    await pumpPrepLoopApp(tester, db, deviceLocale: const Locale('hi', 'IN'));

    expect(find.text('आज'), findsOneWidget); // the Today card's title
  });

  testAppWidgets('switching theme to dark applies the dark theme', (tester, db) async {
    await pumpPrepLoopApp(tester, db);
    await openProfile(tester);

    await scrollTo(tester, find.text('Dark'));
    await tester.tap(find.text('Dark'));
    await tester.pumpAndSettle();

    final context = tester.element(find.text('Profile & settings'));
    expect(Theme.of(context).brightness, Brightness.dark);
  });
}
