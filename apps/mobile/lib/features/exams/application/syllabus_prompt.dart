import '../../../core/database/app_database.dart';

/// `app_settings` key prefix: the learner chose to import papers without a syllabus for an exam
/// (device setting; erased on sign-out).
const syllabusSkippedPrefix = 'syllabus_skipped:';

Future<bool> syllabusSkipped(AppDatabase db, String examCode) async {
  final row = await (db.select(
    db.appSettings,
  )..where((s) => s.key.equals('$syllabusSkippedPrefix$examCode'))).getSingleOrNull();
  return row != null;
}

Future<void> skipSyllabus(AppDatabase db, String examCode) => db
    .into(db.appSettings)
    .insertOnConflictUpdate(
      AppSettingsCompanion.insert(key: '$syllabusSkippedPrefix$examCode', value: 'true'),
    );
