import 'package:flutter/foundation.dart';
import 'package:timezone/timezone.dart' as tz;

/// Whether the app may show notifications.
enum ReminderPermission {
  granted,
  denied,

  /// This platform has no scheduled notifications (web, desktop).
  unsupported,
}

/// The single daily study reminder the app wants scheduled. Two equal plans mean the
/// existing schedule is already right, so nothing is cancelled or re-created.
@immutable
class ReminderPlan {
  const ReminderPlan({
    required this.minutes,
    required this.timezone,
    required this.title,
    required this.body,
    required this.channelName,
  });

  /// Local wall-clock time as minutes after midnight (0–1439).
  final int minutes;

  /// IANA timezone id (e.g. `Asia/Kolkata`) the reminder time is interpreted in.
  final String timezone;
  final String title;
  final String body;

  /// Android notification channel name (shown in system settings).
  final String channelName;

  /// Stable fingerprint stored after scheduling, compared on every sync.
  String get key => [minutes, timezone, title, body, channelName].join('\u001f');

  @override
  bool operator ==(Object other) => other is ReminderPlan && other.key == key;

  @override
  int get hashCode => key.hashCode;
}

/// The next time the daily reminder fires: today at [minutes] past local midnight in
/// [now]'s location if that is still ahead, otherwise tomorrow.
///
/// Wall-clock based: across a daylight-saving change the reminder keeps its local time.
/// A time that does not exist on a "spring forward" day is moved forward by the gap
/// (02:30 → 03:30), as the timezone database resolves it; a repeated time on a "fall
/// back" day fires once, at its first occurrence.
tz.TZDateTime nextReminderAt(tz.TZDateTime now, int minutes) {
  assert(minutes >= 0 && minutes < 24 * 60, 'minutes must be within a day');
  tz.TZDateTime at(int dayOffset) => tz.TZDateTime(
    now.location,
    now.year,
    now.month,
    now.day + dayOffset,
    minutes ~/ 60,
    minutes % 60,
  );
  final today = at(0);
  return today.isAfter(now) ? today : at(1);
}
