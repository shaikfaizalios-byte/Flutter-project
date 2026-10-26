import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/utils/app_log.dart';
import '../../analytics/application/analytics_providers.dart';
import '../../focus/application/focus_controller.dart';
import '../../revision/application/revision_providers.dart';
import '../domain/weekly_review.dart';

/// `app_settings` key of the learner's weekly reflections (device only; erased on sign-out).
const weeklyReflectionsKey = 'weekly_reflections';

/// Saved reflections, newest first.
class WeeklyReflections extends Notifier<List<WeeklyReflection>> {
  @override
  List<WeeklyReflection> build() {
    _load();
    return const [];
  }

  Future<void> _load() async {
    try {
      final db = ref.read(appDatabaseProvider);
      final row = await (db.select(
        db.appSettings,
      )..where((s) => s.key.equals(weeklyReflectionsKey))).getSingleOrNull();
      if (row != null && ref.mounted) state = parseReflections(row.value);
    } on Object catch (error, stack) {
      logError('Loading weekly reflections failed', error, stack);
    }
  }

  Future<void> save(WeeklyReflection reflection) async {
    state = addReflection(state, reflection);
    try {
      final db = ref.read(appDatabaseProvider);
      await db
          .into(db.appSettings)
          .insertOnConflictUpdate(
            AppSettingsCompanion.insert(
              key: weeklyReflectionsKey,
              value: jsonEncode([for (final r in state) r.toJson()]),
            ),
          );
    } on Object catch (error, stack) {
      logError('Saving a weekly reflection failed', error, stack);
    }
  }
}

final weeklyReflectionsProvider = NotifierProvider<WeeklyReflections, List<WeeklyReflection>>(
  WeeklyReflections.new,
);

/// The last 7 days against the 7 before, from real data only. Practice numbers need the
/// server; without it they are left out (null), never guessed.
final weeklyReviewProvider = Provider.autoDispose<WeeklyReview>((ref) {
  final practice = ref.watch(practiceAnalyticsProvider).value;
  return buildWeeklyReview(
    today: ref.watch(todayProvider),
    focusLog: ref.watch(focusLogProvider),
    recallLog: ref.watch(recallLogProvider),
    reviewsByDay: ref.watch(revisionStatsProvider).value?.daily ?? const {},
    activeDays: ref.watch(activityDaysProvider),
    practiceDaily: practice?.daily,
  );
});

/// Home suggests a weekly review when one is due.
final weeklyReviewDueProvider = Provider.autoDispose<bool>(
  (ref) => reviewDue(
    today: ref.watch(todayProvider),
    last: ref.watch(weeklyReflectionsProvider).firstOrNull,
    activeDaysThisWeek: ref.watch(weeklyReviewProvider).thisWeek.activeDays,
  ),
);
