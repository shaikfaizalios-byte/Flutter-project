import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../../core/utils/calendar_date.dart';
import '../../analytics/domain/analytics_models.dart';

/// Rules for the weekly review, shown where they apply.
abstract final class WeeklyReviewRules {
  /// Days in a review week (rolling: the last 7 days, today included).
  static const days = 7;

  /// A new review is suggested on Home this many days after the last one saved.
  static const everyDays = 7;

  /// Weak topics suggested for next week.
  static const focusTopics = 3;

  /// Reflections kept on the device.
  static const keptReflections = 12;

  /// Longest reflection answer (characters).
  static const maxText = 1000;
}

/// Real numbers for one 7-day span. [answered]/[correct] are null when practice statistics
/// could not be loaded (offline).
@immutable
class WeekNumbers {
  const WeekNumbers({
    required this.focusMinutes,
    required this.activeDays,
    required this.reviews,
    required this.recallChecks,
    this.answered,
    this.correct,
  });

  final int focusMinutes;
  final int activeDays;
  final int reviews;
  final int recallChecks;
  final int? answered;
  final int? correct;

  /// Null without answers (never a made-up 0 %).
  double? get accuracy => (answered ?? 0) == 0 ? null : correct! / answered!;
}

/// This week (the last 7 days) and the 7 days before, for comparison.
@immutable
class WeeklyReview {
  const WeeklyReview({
    required this.start,
    required this.end,
    required this.thisWeek,
    required this.lastWeek,
  });

  final CalendarDate start;
  final CalendarDate end;
  final WeekNumbers thisWeek;
  final WeekNumbers lastWeek;
}

/// Builds the review from the device logs and (optional) server practice days.
WeeklyReview buildWeeklyReview({
  required CalendarDate today,
  Map<CalendarDate, int> focusLog = const {},
  Map<CalendarDate, int> recallLog = const {},
  Map<CalendarDate, int> reviewsByDay = const {},
  Set<CalendarDate> activeDays = const {},
  List<DailyStats>? practiceDaily,
}) {
  WeekNumbers numbers(CalendarDate first) {
    bool inside(CalendarDate day) {
      final offset = first.daysUntil(day);
      return offset >= 0 && offset < WeeklyReviewRules.days;
    }

    int sum(Map<CalendarDate, int> log) =>
        log.entries.where((e) => inside(e.key)).fold(0, (total, e) => total + e.value);
    final practice = practiceDaily?.where((d) => inside(d.date)).toList();
    return WeekNumbers(
      focusMinutes: sum(focusLog),
      activeDays: activeDays.where(inside).length,
      reviews: sum(reviewsByDay),
      recallChecks: sum(recallLog),
      answered: practice?.fold<int>(0, (total, d) => total + d.answered),
      correct: practice?.fold<int>(0, (total, d) => total + d.correct),
    );
  }

  final start = today.addDays(1 - WeeklyReviewRules.days);
  return WeeklyReview(
    start: start,
    end: today,
    thisWeek: numbers(start),
    lastWeek: numbers(start.addDays(-WeeklyReviewRules.days)),
  );
}

/// The learner's reflection for a week: what went well and what to change next week.
@immutable
class WeeklyReflection {
  const WeeklyReflection({required this.savedOn, this.wentWell = '', this.nextWeek = ''});

  factory WeeklyReflection.fromJson(Map<String, dynamic> json) => WeeklyReflection(
    savedOn: CalendarDate.tryParse(json['saved_on'] as String?)!,
    wentWell: json['went_well'] as String? ?? '',
    nextWeek: json['next_week'] as String? ?? '',
  );

  final CalendarDate savedOn;
  final String wentWell;
  final String nextWeek;

  Map<String, Object> toJson() => {
    'saved_on': savedOn.toIsoString(),
    'went_well': wentWell,
    'next_week': nextWeek,
  };
}

/// Reflections newest first, from the stored JSON (unreadable entries are skipped).
List<WeeklyReflection> parseReflections(String? raw) {
  if (raw == null) return const [];
  final list = <WeeklyReflection>[];
  for (final item in jsonDecode(raw) as List<dynamic>) {
    try {
      list.add(WeeklyReflection.fromJson(item as Map<String, dynamic>));
    } on Object {
      continue;
    }
  }
  return list..sort((a, b) => b.savedOn.compareTo(a.savedOn));
}

/// Adds [reflection] (replacing one saved the same day) and keeps the newest
/// [WeeklyReviewRules.keptReflections].
List<WeeklyReflection> addReflection(List<WeeklyReflection> all, WeeklyReflection reflection) {
  final list = [
    reflection,
    for (final r in all)
      if (r.savedOn != reflection.savedOn) r,
  ]..sort((a, b) => b.savedOn.compareTo(a.savedOn));
  return list.take(WeeklyReviewRules.keptReflections).toList();
}

/// Whether Home should suggest a review: some activity this week, and no review saved in the
/// last [WeeklyReviewRules.everyDays] days.
bool reviewDue({
  required CalendarDate today,
  required WeeklyReflection? last,
  required int activeDaysThisWeek,
}) {
  if (activeDaysThisWeek == 0) return false;
  return last == null || last.savedOn.daysUntil(today) >= WeeklyReviewRules.everyDays;
}
