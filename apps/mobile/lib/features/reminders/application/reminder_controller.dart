import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/localization/generated/app_localizations.dart';
import '../../../core/utils/app_log.dart';
import '../../settings/application/app_preferences.dart';
import '../../study_plan/application/study_profile_controller.dart';
import '../data/reminder_scheduler.dart';
import '../domain/reminder_plan.dart';

final reminderSchedulerProvider = Provider<ReminderScheduler>(
  (ref) => LocalNotificationsReminderScheduler(),
);

enum ReminderStatus {
  /// Reminders are switched off.
  off,

  /// Switched on, but no reminder time is set.
  needsTime,

  /// Switched on, but notifications are not allowed (denied or revoked).
  blocked,

  /// The daily reminder is scheduled.
  on,

  /// Not available on this platform (web, desktop).
  unsupported,

  /// Scheduling failed unexpectedly (logged).
  failed,
}

@immutable
class ReminderState {
  const ReminderState({required this.enabled, required this.status});

  final bool enabled;
  final ReminderStatus status;
}

/// Keeps the one daily study reminder in line with the learner's choices.
///
/// Every sync compares the wanted [ReminderPlan] (time, timezone, wording) with the
/// fingerprint of what was last scheduled, so app restarts, resumes and repeated
/// changes never create duplicates: the reminder is only re-created when something
/// changed, and it always uses the same notification id. Syncs run on start, on
/// resume (timezone travel, permission changed in system settings), and when the
/// reminder time or app language changes.
class ReminderController extends AsyncNotifier<ReminderState> {
  static const enabledKey = 'reminders_enabled';
  static const scheduledKey = 'reminder_scheduled_plan';

  Future<void> _queue = Future.value();

  @override
  Future<ReminderState> build() async {
    ref.listen(studyProfileProvider.select((p) => p.reminderMinutes), (_, _) => resync());
    ref.listen(appPreferencesProvider.select((p) => p.language), (_, _) => resync());
    final lifecycle = AppLifecycleListener(onResume: resync);
    ref.onDispose(lifecycle.dispose);
    return _serialized(_sync);
  }

  /// Turns reminders on, asking for notification permission if needed. When the
  /// learner declines, reminders stay "on but blocked" and the UI explains how to allow
  /// them; returning to the app after allowing them schedules the reminder.
  Future<void> enable() async {
    final scheduler = ref.read(reminderSchedulerProvider);
    await _setEnabled(true);
    if (scheduler.isSupported && await scheduler.permission() != ReminderPermission.granted) {
      await scheduler.requestPermission();
    }
    await resync();
  }

  Future<void> disable() async {
    await _setEnabled(false);
    await resync();
  }

  Future<void> openSystemSettings() => ref.read(reminderSchedulerProvider).openSettings();

  /// Re-checks permission, timezone and settings, and updates the schedule if needed.
  Future<void> resync() async {
    final next = await AsyncValue.guard(() => _serialized(_sync));
    if (ref.mounted) state = next;
  }

  Future<T> _serialized<T>(Future<T> Function() action) {
    final result = _queue.then((_) => action());
    _queue = result.then((_) {}, onError: (Object _) {});
    return result;
  }

  Future<ReminderState> _sync() async {
    final scheduler = ref.read(reminderSchedulerProvider);
    final enabled = await _read(enabledKey) == 'true';
    if (!scheduler.isSupported) {
      return ReminderState(enabled: enabled, status: ReminderStatus.unsupported);
    }
    final scheduled = await _read(scheduledKey);

    Future<ReminderState> clear(ReminderStatus status) async {
      if (scheduled != null) {
        await scheduler.cancel();
        await _write(scheduledKey, null);
      }
      return ReminderState(enabled: enabled, status: status);
    }

    try {
      if (!enabled) return await clear(ReminderStatus.off);
      final minutes = ref.read(studyProfileProvider).reminderMinutes;
      if (minutes == null) return await clear(ReminderStatus.needsTime);
      if (await scheduler.permission() != ReminderPermission.granted) {
        return await clear(ReminderStatus.blocked);
      }
      final plan = await _plan(minutes, await scheduler.localTimezone());
      if (plan.key != scheduled) {
        await scheduler.schedule(plan);
        await _write(scheduledKey, plan.key);
      }
      return ReminderState(enabled: enabled, status: ReminderStatus.on);
    } on Object catch (error, stack) {
      logError('Syncing the study reminder failed', error, stack);
      return ReminderState(enabled: enabled, status: ReminderStatus.failed);
    }
  }

  Future<ReminderPlan> _plan(int minutes, String timezone) async {
    final l10n = _localizations();
    return ReminderPlan(
      minutes: minutes,
      timezone: timezone,
      title: l10n.reminderNotificationTitle,
      body: l10n.reminderNotificationBody,
      channelName: l10n.reminderChannelName,
    );
  }

  AppLocalizations _localizations() {
    final locale =
        ref.read(appPreferencesProvider).language.locale ??
        WidgetsBinding.instance.platformDispatcher.locale;
    try {
      return lookupAppLocalizations(Locale(locale.languageCode));
    } on FlutterError {
      return lookupAppLocalizations(const Locale('en'));
    }
  }

  Future<void> _setEnabled(bool enabled) => _write(enabledKey, enabled ? 'true' : 'false');

  AppDatabase get _db => ref.read(appDatabaseProvider);

  Future<String?> _read(String key) async => (await (_db.select(
    _db.appSettings,
  )..where((s) => s.key.equals(key))).getSingleOrNull())?.value;

  Future<void> _write(String key, String? value) async {
    if (value == null) {
      await (_db.delete(_db.appSettings)..where((s) => s.key.equals(key))).go();
    } else {
      await _db
          .into(_db.appSettings)
          .insertOnConflictUpdate(AppSettingsCompanion.insert(key: key, value: value));
    }
  }
}

final reminderControllerProvider = AsyncNotifierProvider<ReminderController, ReminderState>(
  ReminderController.new,
);
