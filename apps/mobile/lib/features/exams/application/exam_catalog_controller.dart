import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/exams/exam_catalog.dart';
import '../../../core/utils/app_log.dart';
import '../data/exams_repository.dart';
import '../domain/exam_topics.dart';

/// Device cache of the last catalog (catalog + own exams of the signed-in learner), so exam
/// names show offline. Erased with the learner's other device data.
const examCatalogCacheKey = 'exam_catalog';

/// Loaded at start-up from the cache (built-in SSC exams until the first refresh).
final initialExamCatalogProvider = Provider<List<ExamOption>>((ref) => builtInExams);

Future<List<ExamOption>> loadCachedExamCatalog(AppDatabase db) async {
  final row = await (db.select(
    db.appSettings,
  )..where((s) => s.key.equals(examCatalogCacheKey))).getSingleOrNull();
  if (row == null) return builtInExams;
  try {
    final list = [
      for (final e in jsonDecode(row.value) as List<dynamic>)
        ExamOption.fromJson(e as Map<String, dynamic>),
    ];
    return list.isEmpty ? builtInExams : list;
  } on Object catch (error, stack) {
    logError('Reading the cached exam list failed', error, stack);
    return builtInExams;
  }
}

/// Exams the learner can choose: the server catalog plus their own. Refreshed from the server
/// after sign-in and after creating, renaming or deleting an own exam.
class ExamCatalogController extends Notifier<List<ExamOption>> {
  @override
  List<ExamOption> build() => ref.watch(initialExamCatalogProvider);

  Future<void> refresh() async {
    try {
      final exams = await ref.read(examsRepositoryProvider).exams();
      if (exams.isEmpty) return;
      state = exams;
      final db = ref.read(appDatabaseProvider);
      await db
          .into(db.appSettings)
          .insertOnConflictUpdate(
            AppSettingsCompanion.insert(
              key: examCatalogCacheKey,
              value: jsonEncode([for (final e in exams) e.toJson()]),
            ),
          );
    } on Object catch (error, stack) {
      logError('Refreshing the exam list failed', error, stack); // keep the cached list
    }
  }

  /// After sign-out: back to the built-in list (the cache is erased with user data).
  void reset() => state = builtInExams;

  Future<ExamOption> create(String name) async {
    final exam = await ref.read(examsRepositoryProvider).createExam(name);
    await refresh();
    return exam;
  }

  Future<void> rename(String code, String name) async {
    await ref.read(examsRepositoryProvider).renameExam(code, name);
    await refresh();
  }

  Future<void> delete(String code) async {
    await ref.read(examsRepositoryProvider).deleteExam(code);
    await refresh();
  }
}

final examCatalogProvider = NotifierProvider<ExamCatalogController, List<ExamOption>>(
  ExamCatalogController.new,
);

/// Display name of an exam (the code until the catalog knows it).
final examNameProvider = Provider.family<String, String>(
  (ref, code) => examShortNameIn(ref.watch(examCatalogProvider), code),
);

/// Topics that apply to an exam (shared + own). Errors are shown, not retried silently.
final examTopicsProvider = FutureProvider.autoDispose.family<List<ExamTopic>, String>(
  (ref, code) => ref.watch(examsRepositoryProvider).topics(code),
  retry: (_, _) => null,
);
