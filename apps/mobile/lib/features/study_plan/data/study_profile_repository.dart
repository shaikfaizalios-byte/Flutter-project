import 'package:drift/drift.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/sync_outbox.dart';
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
    return StudyProfile(
      // Any exam code: catalog exams load from the server, own exams are `MY_...`.
      examCodes: row.examCodes,
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
    return _db.transaction(() async {
      await _db
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
      await _db.markDirty(SyncEntity.studyProfile, SyncEntity.profileId);
    });
  }

  static int? _validOrNull(int? value, bool Function(int) isValid) =>
      value != null && isValid(value) ? value : null;
}
