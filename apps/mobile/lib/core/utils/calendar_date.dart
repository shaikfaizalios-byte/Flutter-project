import 'package:flutter/foundation.dart';

/// A calendar date with no time or timezone (e.g. an exam date). Stored as
/// `yyyy-MM-dd` so it never shifts when the device timezone changes.
@immutable
class CalendarDate implements Comparable<CalendarDate> {
  CalendarDate(this.year, this.month, this.day) {
    final check = DateTime.utc(year, month, day);
    if (check.year != year || check.month != month || check.day != day) {
      throw ArgumentError('Invalid date $year-$month-$day');
    }
  }

  /// The local calendar date of [dateTime].
  factory CalendarDate.fromDateTime(DateTime dateTime) {
    final local = dateTime.toLocal();
    return CalendarDate(local.year, local.month, local.day);
  }

  /// The date part of a UTC [DateTime] (no timezone conversion).
  factory CalendarDate.fromUtc(DateTime utc) => CalendarDate(utc.year, utc.month, utc.day);

  /// Parses `yyyy-MM-dd`; returns null for anything else.
  static CalendarDate? tryParse(String? value) {
    final match = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(value ?? '');
    if (match == null) return null;
    try {
      return CalendarDate(
        int.parse(match.group(1)!),
        int.parse(match.group(2)!),
        int.parse(match.group(3)!),
      );
    } on ArgumentError {
      return null;
    }
  }

  final int year;
  final int month;
  final int day;

  /// Whole days from this date to [other] (negative if [other] is earlier).
  /// Uses UTC midnights so daylight-saving changes cannot skew the count.
  int daysUntil(CalendarDate other) => DateTime.utc(
    other.year,
    other.month,
    other.day,
  ).difference(DateTime.utc(year, month, day)).inDays;

  /// The date [days] later (earlier if negative). Calendar arithmetic in UTC, so
  /// daylight-saving changes cannot skip or repeat a day.
  CalendarDate addDays(int days) =>
      CalendarDate.fromUtc(DateTime.utc(year, month, day).add(Duration(days: days)));

  /// Local midnight of this date, for date pickers and formatting.
  DateTime toLocalDateTime() => DateTime(year, month, day);

  String toIsoString() =>
      '${year.toString().padLeft(4, '0')}-${month.toString().padLeft(2, '0')}-'
      '${day.toString().padLeft(2, '0')}';

  @override
  int compareTo(CalendarDate other) => daysUntil(other).sign * -1;

  @override
  bool operator ==(Object other) =>
      other is CalendarDate && other.year == year && other.month == month && other.day == day;

  @override
  int get hashCode => Object.hash(year, month, day);

  @override
  String toString() => toIsoString();
}
