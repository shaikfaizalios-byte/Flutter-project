import 'package:preploop/features/reminders/data/reminder_scheduler.dart';
import 'package:preploop/features/reminders/domain/reminder_plan.dart';

/// Records what the app asks the OS for. [pending] mirrors the OS: scheduled
/// notifications by id, so a duplicate would show up as a second entry.
class FakeReminderScheduler implements ReminderScheduler {
  FakeReminderScheduler({
    this.isSupported = true,
    this.granted = true,
    this.grantOnRequest = true,
    this.timezone = 'Asia/Kolkata',
  });

  @override
  bool isSupported;
  bool granted;
  bool grantOnRequest;
  String timezone;

  final pending = <int, ReminderPlan>{};
  int scheduleCalls = 0;
  int cancelCalls = 0;
  int permissionRequests = 0;
  int settingsOpened = 0;

  ReminderPermission get _current => !isSupported
      ? ReminderPermission.unsupported
      : granted
      ? ReminderPermission.granted
      : ReminderPermission.denied;

  @override
  Future<ReminderPermission> permission() async => _current;

  @override
  Future<ReminderPermission> requestPermission() async {
    permissionRequests++;
    if (grantOnRequest) granted = true;
    return _current;
  }

  @override
  Future<String> localTimezone() async => timezone;

  @override
  Future<void> schedule(ReminderPlan plan) async {
    scheduleCalls++;
    pending[LocalNotificationsReminderScheduler.reminderId] = plan;
  }

  @override
  Future<void> cancel() async {
    cancelCalls++;
    pending.remove(LocalNotificationsReminderScheduler.reminderId);
  }

  @override
  Future<void> openSettings() async => settingsOpened++;
}
