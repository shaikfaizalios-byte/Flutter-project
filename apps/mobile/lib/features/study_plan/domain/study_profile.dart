import 'package:flutter/foundation.dart';

import '../../../core/utils/calendar_date.dart';

/// The learner's study setup, collected in onboarding and editable in Profile.
/// Every field except [examCodes] is optional ("skip" is always allowed).
@immutable
class StudyProfile {
  const StudyProfile({
    this.examCodes = const [],
    this.targetExamDate,
    this.dailyStudyMinutes,
    this.reminderMinutes,
    this.onboardingCompletedAt,
  });

  /// Selected exams; empty means the learner has not chosen yet.
  final List<String> examCodes;
  final CalendarDate? targetExamDate;
  final int? dailyStudyMinutes;

  /// Preferred reminder time as minutes after local midnight.
  final int? reminderMinutes;
  final DateTime? onboardingCompletedAt;

  bool get onboardingCompleted => onboardingCompletedAt != null;

  /// Nullable fields take a getter so they can be explicitly cleared:
  /// `copyWith(targetExamDate: () => null)`.
  StudyProfile copyWith({
    List<String>? examCodes,
    CalendarDate? Function()? targetExamDate,
    int? Function()? dailyStudyMinutes,
    int? Function()? reminderMinutes,
    DateTime? Function()? onboardingCompletedAt,
  }) => StudyProfile(
    examCodes: examCodes ?? this.examCodes,
    targetExamDate: targetExamDate != null ? targetExamDate() : this.targetExamDate,
    dailyStudyMinutes: dailyStudyMinutes != null ? dailyStudyMinutes() : this.dailyStudyMinutes,
    reminderMinutes: reminderMinutes != null ? reminderMinutes() : this.reminderMinutes,
    onboardingCompletedAt: onboardingCompletedAt != null
        ? onboardingCompletedAt()
        : this.onboardingCompletedAt,
  );

  @override
  bool operator ==(Object other) =>
      other is StudyProfile &&
      listEquals(other.examCodes, examCodes) &&
      other.targetExamDate == targetExamDate &&
      other.dailyStudyMinutes == dailyStudyMinutes &&
      other.reminderMinutes == reminderMinutes &&
      other.onboardingCompletedAt == onboardingCompletedAt;

  @override
  int get hashCode => Object.hash(
    Object.hashAll(examCodes),
    targetExamDate,
    dailyStudyMinutes,
    reminderMinutes,
    onboardingCompletedAt,
  );
}

/// Limits for study-profile values (validated before saving).
abstract final class StudyProfileRules {
  /// Daily study time choices offered in the UI, in minutes.
  static const dailyMinuteOptions = [15, 30, 45, 60, 90, 120, 180, 240];
  static const minDailyMinutes = 5;
  static const maxDailyMinutes = 720;

  static bool isValidDailyMinutes(int minutes) =>
      minutes >= minDailyMinutes && minutes <= maxDailyMinutes;

  static bool isValidReminderMinutes(int minutes) => minutes >= 0 && minutes < 24 * 60;
}

/// Days from [today] until the exam, or null when no date is set.
int? daysUntilExam(StudyProfile profile, CalendarDate today) =>
    profile.targetExamDate == null ? null : today.daysUntil(profile.targetExamDate!);
