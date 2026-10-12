import 'package:drift/drift.dart';

import '../../../core/database/app_database.dart';
import '../../../core/exams/exam_catalog.dart';
import '../../../core/utils/calendar_date.dart';
import '../domain/study_profile.dart';

/// Persists the single [StudyProfile] row in the local database.
class StudyProfileRepository {
  StudyProfileRepository(this._db, {DateTime Function()? clock}) : _clock = clock ?? DateTime.now;

  final AppDatabase _db;
  final DateTime Function() _clock;

  static const _rowId = 1;

  Future<StudyProfile> load() async {
    final row = await (_db.select(
      _db.studyProfiles,
    )..where((p) => p.id.equals(_rowId))).getSingleOrNull();
    if (row == null) return const StudyProfile();
    final known = supportedExams.map((e) => e.code).toSet();
    return StudyProfile(
      // Ignore codes this app version doesn't know (e.g. written by a newer version).
      examCodes: row.examCodes.where(known.contains).toList(),
      targetExamDate: CalendarDate.tryParse(row.targetExamDate),
      dailyStudyMinutes: _validOrNull(row.dailyStudyMinutes, StudyProfileRules.isValidDailyMinutes),
      reminderMinutes: _validOrNull(row.reminderMinutes, StudyProfileRules.isValidReminderMinutes),
      onboardingCompletedAt: row.onboardingCompletedAt,
    );
  }

  Future<void> save(StudyProfile profile) {
    final daily = profile.dailyStudyMinutes;
    final reminder = profile.reminderMinutes;
    if (daily != null && !StudyProfileRules.isValidDailyMinutes(daily)) {
      throw ArgumentError.value(daily, 'dailyStudyMinutes');
    }
    if (reminder != null && !StudyProfileRules.isValidReminderMinutes(reminder)) {
      throw ArgumentError.value(reminder, 'reminderMinutes');
    }
    return _db
        .into(_db.studyProfiles)
        .insertOnConflictUpdate(
          StudyProfilesCompanion.insert(
            id: const Value(_rowId),
            examCodes: Value(profile.examCodes),
            targetExamDate: Value(profile.targetExamDate?.toIsoString()),
            dailyStudyMinutes: Value(daily),
            reminderMinutes: Value(reminder),
            onboardingCompletedAt: Value(profile.onboardingCompletedAt?.toUtc()),
            updatedAt: _clock().toUtc(),
          ),
        );
  }

  static int? _validOrNull(int? value, bool Function(int) isValid) =>
      value != null && isValid(value) ? value : null;
}
