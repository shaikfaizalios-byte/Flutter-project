import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../core/exams/exam_catalog.dart';
import '../../../core/localization/generated/app_localizations.dart';
import '../../../core/utils/calendar_date.dart';
import '../domain/study_profile.dart';

/// "45 min", "1 h", "1 h 30 min" (localised).
String formatStudyDuration(AppLocalizations l10n, int minutes) {
  final hours = minutes ~/ 60;
  final rest = minutes % 60;
  if (hours == 0) return l10n.durationMinutes(rest);
  if (rest == 0) return l10n.durationHours(hours);
  return l10n.durationHoursMinutes(hours, rest);
}

/// A calendar date in the current locale, e.g. "12 Mar 2027".
String formatCalendarDate(BuildContext context, CalendarDate date) =>
    DateFormat.yMMMd(Localizations.localeOf(context).toLanguageTag())
        .format(date.toLocalDateTime());

/// A wall-clock time from minutes after midnight, in the device's 12/24 h style.
String formatReminderTime(BuildContext context, int minutes) =>
    MaterialLocalizations.of(context)
        .formatTimeOfDay(TimeOfDay(hour: minutes ~/ 60, minute: minutes % 60));

String formatExamNames(AppLocalizations l10n, List<String> codes, List<ExamOption> catalog) =>
    codes.isEmpty ? l10n.examsNotChosen : codes.map((c) => examShortNameIn(catalog, c)).join(' · ');

/// Single-select daily study time.
class DailyMinutesSelector extends StatelessWidget {
  const DailyMinutesSelector({super.key, required this.selected, required this.onChanged});

  final int? selected;
  final ValueChanged<int?> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: [
        for (final minutes in StudyProfileRules.dailyMinuteOptions)
          ChoiceChip(
            label: Text(formatStudyDuration(l10n, minutes)),
            selected: selected == minutes,
            // Tapping the selected chip again clears the choice.
            onSelected: (on) => onChanged(on ? minutes : null),
          ),
      ],
    );
  }
}

/// Shows a date picker for the exam date (today up to 5 years ahead).
Future<CalendarDate?> pickExamDate(
  BuildContext context, {
  required CalendarDate today,
  CalendarDate? initial,
}) async {
  final first = today.toLocalDateTime();
  final last = DateTime(today.year + 5, today.month, today.day);
  var initialDate = initial?.toLocalDateTime() ?? first;
  if (initialDate.isBefore(first)) initialDate = first;
  final picked = await showDatePicker(
    context: context,
    firstDate: first,
    lastDate: last,
    initialDate: initialDate,
  );
  return picked == null ? null : CalendarDate(picked.year, picked.month, picked.day);
}

/// Shows a time picker; returns minutes after midnight.
Future<int?> pickReminderTime(BuildContext context, {int? initialMinutes}) async {
  final initial = initialMinutes ?? 19 * 60;
  final picked = await showTimePicker(
    context: context,
    initialTime: TimeOfDay(hour: initial ~/ 60, minute: initial % 60),
  );
  return picked == null ? null : picked.hour * 60 + picked.minute;
}
