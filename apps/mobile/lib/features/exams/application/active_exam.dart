import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/utils/app_log.dart';
import '../../study_plan/application/study_profile_controller.dart';

/// `app_settings` key of the exam the app is showing (device setting; erased on sign-out).
const activeExamKey = 'active_exam';

/// The learner's explicit choice of exam, loaded from the device (null until chosen/loaded).
class ActiveExamChoice extends Notifier<String?> {
  @override
  String? build() {
    _load();
    return null;
  }

  Future<void> _load() async {
    try {
      final db = ref.read(appDatabaseProvider);
      final row = await (db.select(
        db.appSettings,
      )..where((s) => s.key.equals(activeExamKey))).getSingleOrNull();
      if (row != null && state == null && ref.mounted) state = row.value;
    } on Object catch (error, stack) {
      logError('Loading the current exam failed', error, stack);
    }
  }

  /// Shows [code]'s papers, questions and practice from now on.
  Future<void> choose(String code) async {
    state = code;
    try {
      final db = ref.read(appDatabaseProvider);
      await db
          .into(db.appSettings)
          .insertOnConflictUpdate(AppSettingsCompanion.insert(key: activeExamKey, value: code));
    } on Object catch (error, stack) {
      logError('Saving the current exam failed', error, stack);
    }
  }
}

final activeExamChoiceProvider = NotifierProvider<ActiveExamChoice, String?>(ActiveExamChoice.new);

/// The exam the app is showing: the learner's choice while it is one of their exams, else
/// their first exam (null when they have chosen none). Imported papers, the question bank,
/// practice, mock tests and repeated models show only this exam's content.
final activeExamProvider = Provider<String?>((ref) {
  final exams = ref.watch(studyProfileProvider.select((p) => p.examCodes));
  final choice = ref.watch(activeExamChoiceProvider);
  if (choice != null && exams.contains(choice)) return choice;
  return exams.isEmpty ? null : exams.first;
});
