import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:preploop/core/database/app_database.dart';
import 'package:preploop/core/utils/clock.dart';
import 'package:preploop/features/reminders/application/reminder_controller.dart';
import 'package:preploop/features/reminders/data/reminder_scheduler.dart';
import 'package:preploop/features/settings/application/app_preferences.dart';
import 'package:preploop/features/study_plan/application/study_profile_controller.dart';
import 'package:preploop/features/study_plan/domain/study_profile.dart';

import '../../helpers/pump_app.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late FakeReminderScheduler os;

  setUp(() {
    db = createTestDatabase();
    os = FakeReminderScheduler();
  });

  /// A fresh app start against the same device storage and OS state.
  ProviderContainer start({int? reminderMinutes = 7 * 60 + 30}) {
    final container = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        clockProvider.overrideWithValue(() => testNow),
        reminderSchedulerProvider.overrideWithValue(os),
        initialStudyProfileProvider.overrideWithValue(
          StudyProfile(reminderMinutes: reminderMinutes, onboardingCompletedAt: testNow),
        ),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  Future<ReminderState> stateOf(ProviderContainer c) => c.read(reminderControllerProvider.future);

  ReminderController controller(ProviderContainer c) => c.read(reminderControllerProvider.notifier);

  Future<ReminderState> settle(ProviderContainer c) async {
    await controller(c).resync();
    return stateOf(c);
  }

  test('off by default: nothing is scheduled and no permission is asked', () async {
    final app = start();
    final state = await stateOf(app);

    expect((state.enabled, state.status), (false, ReminderStatus.off));
    expect(os.pending, isEmpty);
    expect(os.permissionRequests, 0);
  });

  test('switching on asks for permission and schedules one daily reminder', () async {
    os.granted = false;
    final app = start();
    await stateOf(app);

    await controller(app).enable();
    final state = await stateOf(app);

    expect(state.status, ReminderStatus.on);
    expect(os.permissionRequests, 1);
    expect(os.pending, hasLength(1));
    final plan = os.pending[LocalNotificationsReminderScheduler.reminderId]!;
    expect((plan.minutes, plan.timezone), (450, 'Asia/Kolkata'));
    expect(plan.title, 'Time to study');
  });

  test('restarts and resumes never create duplicates', () async {
    final first = start();
    await stateOf(first);
    await controller(first).enable();
    expect(os.scheduleCalls, 1);

    await settle(first); // resume
    await settle(first);
    first.dispose();
    final second = start(); // app restart
    expect((await stateOf(second)).status, ReminderStatus.on);
    await settle(second);

    expect(os.scheduleCalls, 1);
    expect(os.pending, hasLength(1));
  });

  test('changing the time replaces the reminder instead of adding one', () async {
    final app = start();
    await stateOf(app);
    await controller(app).enable();

    await app.read(studyProfileProvider.notifier).setReminderMinutes(20 * 60);
    await settle(app);

    expect(os.scheduleCalls, 2);
    expect(os.pending, hasLength(1));
    expect(os.pending.values.single.minutes, 1200);
  });

  test('a timezone change is picked up on resume', () async {
    final app = start();
    await stateOf(app);
    await controller(app).enable();

    os.timezone = 'Europe/London'; // the learner travelled
    await settle(app);

    expect(os.scheduleCalls, 2);
    expect(os.pending.values.single.timezone, 'Europe/London');
    expect(os.pending, hasLength(1));
  });

  test('the notification text follows the app language', () async {
    final app = start();
    await stateOf(app);
    await controller(app).enable();

    await app.read(appPreferencesProvider.notifier).setLanguage(AppLanguage.hindi);
    await settle(app);

    expect(os.pending.values.single.title, 'पढ़ाई का समय');
    expect(os.pending, hasLength(1));
  });

  test('denied permission: the app keeps working and explains; allowing later schedules', () async {
    os
      ..granted = false
      ..grantOnRequest = false;
    final app = start();
    await stateOf(app);

    await controller(app).enable();
    var state = await stateOf(app);
    expect((state.enabled, state.status), (true, ReminderStatus.blocked));
    expect(os.pending, isEmpty);

    await controller(app).openSystemSettings();
    expect(os.settingsOpened, 1);
    os.granted = true; // allowed in system settings, then back to the app
    state = await settle(app);

    expect(state.status, ReminderStatus.on);
    expect(os.pending, hasLength(1));
  });

  test('permission revoked in system settings cancels the schedule on resume', () async {
    final app = start();
    await stateOf(app);
    await controller(app).enable();

    os.granted = false;
    final state = await settle(app);

    expect(state.status, ReminderStatus.blocked);
    expect(os.pending, isEmpty);
  });

  test('switching off cancels the reminder', () async {
    final app = start();
    await stateOf(app);
    await controller(app).enable();

    await controller(app).disable();
    final state = await stateOf(app);

    expect((state.enabled, state.status), (false, ReminderStatus.off));
    expect(os.pending, isEmpty);
  });

  test('without a reminder time nothing is scheduled; clearing the time cancels', () async {
    final noTime = start(reminderMinutes: null);
    await stateOf(noTime);
    await controller(noTime).enable();
    expect((await stateOf(noTime)).status, ReminderStatus.needsTime);
    expect(os.pending, isEmpty);

    await noTime.read(studyProfileProvider.notifier).setReminderMinutes(6 * 60);
    expect((await settle(noTime)).status, ReminderStatus.on);
    await noTime.read(studyProfileProvider.notifier).setReminderMinutes(null);
    expect((await settle(noTime)).status, ReminderStatus.needsTime);
    expect(os.pending, isEmpty);
  });

  test('unsupported platforms (web, desktop) never touch notifications', () async {
    os.isSupported = false;
    final app = start();
    await stateOf(app);
    await controller(app).enable();

    expect((await stateOf(app)).status, ReminderStatus.unsupported);
    expect((os.scheduleCalls, os.permissionRequests), (0, 0));
  });
}
