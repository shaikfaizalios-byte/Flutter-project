import 'package:flutter/foundation.dart';

import '../../../core/utils/calendar_date.dart';

/// Rules for focus sessions and streaks, shown to the learner where they apply. Choices
/// based on learning research, not invented results:
/// - focused blocks of 25-50 minutes with short breaks (spaced, distraction-free practice);
/// - a streak that allows a rest day, because habits survive a missed day but motivation
///   doesn't survive a punishing counter.
abstract final class FocusRules {
  static const presets = [15, 25, 45, 60];
  static const defaultMinutes = 25;
  static const minMinutes = 5;
  static const maxMinutes = 120;

  /// One missed day within any 7 days keeps the streak going.
  static const restDayEvery = 7;

  /// Days of focus minutes kept on the device.
  static const logDays = 120;
}

/// A running focus session. Times are UTC.
@immutable
class FocusSession {
  const FocusSession({required this.startedAt, required this.minutes});

  factory FocusSession.fromJson(Map<String, dynamic> json) => FocusSession(
    startedAt: DateTime.parse(json['started_at'] as String).toUtc(),
    minutes: json['minutes'] as int,
  );

  final DateTime startedAt;
  final int minutes;

  DateTime get endsAt => startedAt.add(Duration(minutes: minutes));

  Duration remaining(DateTime now) {
    final left = endsAt.difference(now.toUtc());
    return left.isNegative ? Duration.zero : left;
  }

  bool isOver(DateTime now) => remaining(now) == Duration.zero;

  /// Whole minutes focused so far (at most [minutes]).
  int elapsedMinutes(DateTime now) =>
      now.toUtc().difference(startedAt).inMinutes.clamp(0, minutes).toInt();

  Map<String, Object> toJson() => {
    'started_at': startedAt.toUtc().toIso8601String(),
    'minutes': minutes,
  };
}

/// Days in a row with study activity, counting back from today. Today still counts as open:
/// with nothing done yet the streak is the one ending yesterday. One missed day within any
/// [FocusRules.restDayEvery] days is a rest day and doesn't end the streak (it isn't counted
/// either). [active] holds the days with any practice, revision or focus time.
int currentStreak(Set<CalendarDate> active, CalendarDate today) {
  var day = active.contains(today) ? today : today.addDays(-1);
  var streak = 0;
  CalendarDate? lastRest;
  for (var guard = 0; guard < 3660; guard++) {
    if (active.contains(day)) {
      streak++;
    } else {
      final restAllowed =
          streak > 0 &&
          active.contains(day.addDays(-1)) &&
          (lastRest == null || day.daysUntil(lastRest) >= FocusRules.restDayEvery);
      if (!restAllowed) break;
      lastRest = day;
    }
    day = day.addDays(-1);
  }
  return streak;
}

/// Focus minutes per day, keeping only the last [FocusRules.logDays] days before [today].
Map<CalendarDate, int> addFocusMinutes(
  Map<CalendarDate, int> log,
  CalendarDate day,
  int minutes,
  CalendarDate today,
) {
  final oldest = today.addDays(-FocusRules.logDays);
  return {
    for (final entry in log.entries)
      if (oldest.daysUntil(entry.key) >= 0) entry.key: entry.value,
    day: (log[day] ?? 0) + minutes,
  };
}
