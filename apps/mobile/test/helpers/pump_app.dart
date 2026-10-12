import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:preploop/app/app.dart';
import 'package:preploop/core/config/app_config.dart';
import 'package:preploop/core/database/app_database.dart';
import 'package:preploop/core/errors/app_failure.dart';
import 'package:preploop/features/settings/application/app_preferences.dart';
import 'package:preploop/features/settings/data/server_status_repository.dart';
import 'package:preploop/features/settings/domain/server_health.dart';

const testConfig = AppConfig(
  appName: 'PrepLoop',
  apiBaseUrl: 'http://test.invalid',
  flavor: AppFlavor.development,
);

AppDatabase _openMemoryDatabase() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  return AppDatabase(NativeDatabase.memory());
}

/// Fresh in-memory database for a plain (non-widget) test. Closed automatically.
AppDatabase createTestDatabase() {
  final db = _openMemoryDatabase();
  addTearDown(db.close);
  return db;
}

/// `testWidgets` for tests that pump the whole app. Provides a fresh in-memory
/// database and cleans up correctly: drift cancels stream queries with a
/// zero-duration timer when widgets are disposed, which must run inside the
/// test body, and closing the database must happen outside fake async.
void testAppWidgets(
  String description,
  Future<void> Function(WidgetTester tester, AppDatabase db) body,
) {
  testWidgets(description, (tester) async {
    final db = _openMemoryDatabase();
    try {
      await body(tester, db);
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(Duration.zero);
      await tester.runAsync(db.close);
    }
  });
}

/// Inserts test data outside fake async (real database I/O).
Future<T> seed<T>(WidgetTester tester, Future<T> Function() action) async =>
    (await tester.runAsync(action)) as T;

/// Fake repository so widget tests never touch the network.
class FakeServerStatusRepository implements ServerStatusRepository {
  FakeServerStatusRepository({this.online = true});

  bool online;
  int calls = 0;

  @override
  Future<ServerHealth> fetchHealth() async {
    calls++;
    if (!online) throw const NetworkFailure();
    return const ServerHealth(version: '0.1.0', environment: 'test');
  }
}

Future<void> pumpPrepLoopApp(
  WidgetTester tester,
  AppDatabase db, {
  FakeServerStatusRepository? serverStatus,
  Locale? deviceLocale,
  AppPreferences initialPreferences = const AppPreferences(),
}) async {
  if (deviceLocale != null) {
    tester.platformDispatcher.localesTestValue = [deviceLocale];
    addTearDown(tester.platformDispatcher.clearLocalesTestValue);
  }
  final overrides = <Override>[
    appConfigProvider.overrideWithValue(testConfig),
    appDatabaseProvider.overrideWithValue(db),
    initialPreferencesProvider.overrideWithValue(initialPreferences),
    serverStatusRepositoryProvider.overrideWithValue(serverStatus ?? FakeServerStatusRepository()),
  ];
  await tester.pumpWidget(ProviderScope(overrides: overrides, child: const PrepLoopApp()));
  await tester.pumpAndSettle();
}
