import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../domain/reminder_plan.dart';

/// Platform access for the daily study reminder. Widget tests use a fake.
abstract interface class ReminderScheduler {
  /// False where scheduled notifications are not available (web, desktop).
  bool get isSupported;

  /// Current permission, without asking the learner.
  Future<ReminderPermission> permission();

  /// Shows the system permission prompt (call only after the learner turns reminders on).
  Future<ReminderPermission> requestPermission();

  /// The device's IANA timezone id.
  Future<String> localTimezone();

  /// Replaces the daily reminder with [plan] (one notification id, so never two).
  Future<void> schedule(ReminderPlan plan);

  /// Removes the daily reminder if one is scheduled.
  Future<void> cancel();

  /// Opens the system notification settings for this app (after a denial).
  Future<void> openSettings();
}

/// [ReminderScheduler] backed by flutter_local_notifications (Android and iOS).
///
/// Android uses inexact alarms (`inexactAllowWhileIdle`), so no exact-alarm permission is
/// needed; the reminder may arrive a few minutes late. The schedule survives reboots
/// (boot receiver in AndroidManifest.xml).
class LocalNotificationsReminderScheduler implements ReminderScheduler {
  LocalNotificationsReminderScheduler([FlutterLocalNotificationsPlugin? plugin])
    : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  /// The one notification id used for the daily reminder.
  static const reminderId = 7001;
  static const channelId = 'study_reminders';

  final FlutterLocalNotificationsPlugin _plugin;
  Future<void>? _ready;

  @override
  bool get isSupported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  Future<void> _init() => _ready ??= () async {
    tzdata.initializeTimeZones();
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        // Never prompt at start-up; the prompt comes when reminders are switched on.
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestSoundPermission: false,
          requestBadgePermission: false,
        ),
      ),
    );
  }();

  @override
  Future<ReminderPermission> permission() async {
    if (!isSupported) return ReminderPermission.unsupported;
    await _init();
    final bool? granted;
    if (defaultTargetPlatform == TargetPlatform.android) {
      granted = await _plugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.areNotificationsEnabled();
    } else {
      final options = await _plugin
          .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()
          ?.checkPermissions();
      granted = options?.isEnabled;
    }
    return granted ?? false ? ReminderPermission.granted : ReminderPermission.denied;
  }

  @override
  Future<ReminderPermission> requestPermission() async {
    if (!isSupported) return ReminderPermission.unsupported;
    await _init();
    final bool? granted;
    if (defaultTargetPlatform == TargetPlatform.android) {
      granted = await _plugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();
    } else {
      granted = await _plugin
          .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(alert: true, sound: true);
    }
    return granted ?? false ? ReminderPermission.granted : ReminderPermission.denied;
  }

  @override
  Future<String> localTimezone() async => (await FlutterTimezone.getLocalTimezone()).identifier;

  @override
  Future<void> schedule(ReminderPlan plan) async {
    await _init();
    final location = tz.getLocation(plan.timezone);
    await _plugin.cancel(id: reminderId);
    await _plugin.zonedSchedule(
      id: reminderId,
      scheduledDate: nextReminderAt(tz.TZDateTime.now(location), plan.minutes),
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(channelId, plan.channelName),
        iOS: const DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      title: plan.title,
      body: plan.body,
      // Repeats daily at the same local time.
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  @override
  Future<void> cancel() async {
    if (!isSupported) return;
    await _init();
    await _plugin.cancel(id: reminderId);
  }

  @override
  Future<void> openSettings() async {
    if (!isSupported) return;
    await _init();
    await _plugin.openAppNotificationSettings();
  }
}
