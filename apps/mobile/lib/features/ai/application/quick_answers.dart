import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/utils/app_log.dart';
import '../../exams/application/active_exam.dart';
import '../data/ai_repository.dart';
import 'ai_providers.dart';

/// `app_settings` key: the learner switched on quick AI answers for searches with no match in
/// their papers (device setting; erased on sign-out). Off until they ask once, because the
/// search text goes to the AI provider.
const quickAnswersKey = 'quick_answers_on';

class QuickAnswersOn extends Notifier<bool> {
  @override
  bool build() {
    _load();
    return false;
  }

  Future<void> _load() async {
    try {
      final db = ref.read(appDatabaseProvider);
      final row = await (db.select(
        db.appSettings,
      )..where((s) => s.key.equals(quickAnswersKey))).getSingleOrNull();
      if (row != null && ref.mounted) state = row.value == 'true';
    } on Object catch (error, stack) {
      logError('Loading the quick answer setting failed', error, stack);
    }
  }

  Future<void> set({required bool on}) async {
    state = on;
    try {
      final db = ref.read(appDatabaseProvider);
      await db
          .into(db.appSettings)
          .insertOnConflictUpdate(
            AppSettingsCompanion.insert(key: quickAnswersKey, value: on ? 'true' : 'false'),
          );
    } on Object catch (error, stack) {
      logError('Saving the quick answer setting failed', error, stack);
    }
  }
}

final quickAnswersOnProvider = NotifierProvider<QuickAnswersOn, bool>(QuickAnswersOn.new);

/// How long the search must stay unchanged before the AI is asked (on top of the paper
/// search's own wait), so typing doesn't spend AI requests.
const quickAnswerSettle = Duration(milliseconds: 800);

/// The AI's short answer to [text] for the current exam.
final quickAnswerProvider = FutureProvider.autoDispose.family<QuickAnswer?, String>((
  ref,
  text,
) async {
  final exam = ref.watch(activeExamProvider);
  await Future<void>.delayed(quickAnswerSettle);
  if (!ref.mounted) return null;
  return ref.read(aiRepositoryProvider).quickAnswer(text, examCode: exam);
}, retry: (_, _) => null);

/// The AI's answer to [text] from the learner's own material for the current exam (RAG).
/// Null while there is no exam or the search changed during the wait.
final searchAnswerProvider = FutureProvider.autoDispose.family<SearchAnswer?, String>((
  ref,
  text,
) async {
  final exam = ref.watch(activeExamProvider);
  if (exam == null) return null;
  await Future<void>.delayed(quickAnswerSettle);
  if (!ref.mounted) return null;
  return ref.read(aiRepositoryProvider).searchAnswer(text, examCode: exam);
}, retry: (_, _) => null);
