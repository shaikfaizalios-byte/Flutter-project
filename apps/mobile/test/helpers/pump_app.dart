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
import 'package:preploop/features/study_plan/application/study_profile_controller.dart';
import 'package:preploop/features/study_plan/domain/study_profile.dart';
import 'package:preploop/core/utils/clock.dart';
import 'package:preploop/features/analytics/application/analytics_providers.dart';
import 'package:preploop/features/practice/application/practice_providers.dart';
import 'package:preploop/features/question_bank/data/questions_repository.dart';
import 'package:preploop/features/reminders/application/reminder_controller.dart';

import 'fake_analytics.dart';
import 'fake_practice.dart';
import 'fake_questions.dart';
import 'fake_reminders.dart';

export 'fake_analytics.dart';
export 'fake_practice.dart';
export 'fake_questions.dart';
export 'fake_reminders.dart';

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

/// Fixed "now" for widget tests: 12 Oct 2026, 10:00 local time.
final testNow = DateTime(2026, 10, 12, 10);

/// A learner who has finished onboarding (the default for app tests).
final onboardedProfile = StudyProfile(onboardingCompletedAt: DateTime.utc(2026, 10, 1));

/// Pumps the whole app. Starts onboarded unless [studyProfile] says otherwise;
/// pass `const StudyProfile()` to simulate a fresh install.
Future<void> pumpPrepLoopApp(
  WidgetTester tester,
  AppDatabase db, {
  FakeServerStatusRepository? serverStatus,
  Locale? deviceLocale,
  AppPreferences initialPreferences = const AppPreferences(),
  StudyProfile? studyProfile,
  DateTime? now,
  DateTime Function()? clockOverride,
  List<Override> extraOverrides = const [],
  FakeQuestionsRepository? questions,
  FakePracticeRepository? practice,
  FakeReminderScheduler? reminders,
  FakeAnalyticsRepository? analytics,
}) async {
  if (deviceLocale != null) {
    tester.platformDispatcher.localesTestValue = [deviceLocale];
    addTearDown(tester.platformDispatcher.clearLocalesTestValue);
  }
  final overrides = <Override>[
    appConfigProvider.overrideWithValue(testConfig),
    appDatabaseProvider.overrideWithValue(db),
    clockProvider.overrideWithValue(clockOverride ?? () => now ?? testNow),
    initialPreferencesProvider.overrideWithValue(initialPreferences),
    initialStudyProfileProvider.overrideWithValue(studyProfile ?? onboardedProfile),
    serverStatusRepositoryProvider.overrideWithValue(serverStatus ?? FakeServerStatusRepository()),
    questionsRepositoryProvider.overrideWithValue(questions ?? FakeQuestionsRepository()),
    practiceRepositoryProvider.overrideWithValue(
      practice ?? FakePracticeRepository(serverNow: clockOverride ?? () => now ?? testNow),
    ),
    reminderSchedulerProvider.overrideWithValue(reminders ?? FakeReminderScheduler()),
    analyticsRepositoryProvider.overrideWithValue(analytics ?? FakeAnalyticsRepository()),
    localTimezoneProvider.overrideWith((ref) async => 'Asia/Kolkata'),
    ...extraOverrides,
  ];
  await tester.pumpWidget(ProviderScope(overrides: overrides, child: const PrepLoopApp()));
  await tester.pumpAndSettle();
}

/// Scrolls the screen's main vertical list until [finder] is built and visible.
Future<void> scrollTo(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(
    finder,
    200,
    scrollable: find
        .byWidgetPredicate((w) => w is Scrollable && w.axisDirection == AxisDirection.down)
        .first,
  );
  await tester.pumpAndSettle();
}
