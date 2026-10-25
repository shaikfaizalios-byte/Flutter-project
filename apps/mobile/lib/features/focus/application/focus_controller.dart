import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/utils/app_log.dart';
import '../../../core/utils/calendar_date.dart';
import '../../../core/utils/clock.dart';
import '../../analytics/application/analytics_providers.dart';
import '../../analytics/domain/analytics_models.dart';
import '../../revision/application/revision_providers.dart';
import '../domain/focus.dart';

/// `app_settings` keys (device settings; erased on sign-out like the others).
const focusSessionKey = 'focus_session';
const focusLogKey = 'focus_log';

Future<String?> _read(AppDatabase db, String key) async =>
    (await (db.select(db.appSettings)..where((s) => s.key.equals(key))).getSingleOrNull())?.value;

Future<void> _write(AppDatabase db, String key, String? value) async {
  if (value == null) {
    await (db.delete(db.appSettings)..where((s) => s.key.equals(key))).go();
  } else {
    await db
        .into(db.appSettings)
        .insertOnConflictUpdate(AppSettingsCompanion.insert(key: key, value: value));
  }
}

/// Focus minutes per day on this device.
class FocusLog extends Notifier<Map<CalendarDate, int>> {
  @override
  Map<CalendarDate, int> build() {
    _load();
    return const {};
  }

  Future<void> _load() async {
    try {
      final raw = await _read(ref.read(appDatabaseProvider), focusLogKey);
      if (raw == null || !ref.mounted) return;
      final json = jsonDecode(raw) as Map<String, dynamic>;
      state = {
        for (final entry in json.entries) ?CalendarDate.tryParse(entry.key): entry.value as int,
      };
    } on Object catch (error, stack) {
      logError('Loading the focus log failed', error, stack);
    }
  }

  Future<void> add(CalendarDate day, int minutes) async {
    if (minutes <= 0) return;
    state = addFocusMinutes(state, day, minutes, ref.read(todayProvider));
    try {
      await _write(
        ref.read(appDatabaseProvider),
        focusLogKey,
        jsonEncode({for (final e in state.entries) e.key.toIsoString(): e.value}),
      );
    } on Object catch (error, stack) {
      logError('Saving the focus log failed', error, stack);
    }
  }
}

final focusLogProvider = NotifierProvider<FocusLog, Map<CalendarDate, int>>(FocusLog.new);

/// The running focus session (null when none). Survives a reload of the app.
class FocusController extends Notifier<FocusSession?> {
  @override
  FocusSession? build() {
    _load();
    return null;
  }

  DateTime _now() => ref.read(clockProvider)();

  Future<void> _load() async {
    try {
      final raw = await _read(ref.read(appDatabaseProvider), focusSessionKey);
      if (raw == null || !ref.mounted || state != null) return;
      state = FocusSession.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } on Object catch (error, stack) {
      logError('Loading the focus session failed', error, stack);
    }
  }

  Future<void> start(int minutes) async {
    final session = FocusSession(
      startedAt: _now().toUtc(),
      minutes: minutes.clamp(FocusRules.minMinutes, FocusRules.maxMinutes),
    );
    state = session;
    try {
      await _write(ref.read(appDatabaseProvider), focusSessionKey, jsonEncode(session.toJson()));
    } on Object catch (error, stack) {
      logError('Saving the focus session failed', error, stack);
    }
  }

  /// Ends the session (finished or stopped early) and logs the minutes focused. Returns them.
  Future<int> end() async {
    final session = state;
    if (session == null) return 0;
    final now = _now();
    final minutes = session.elapsedMinutes(now);
    state = null;
    await ref
        .read(focusLogProvider.notifier)
        .add(CalendarDate.fromDateTime(session.startedAt), minutes);
    try {
      await _write(ref.read(appDatabaseProvider), focusSessionKey, null);
    } on Object catch (error, stack) {
      logError('Clearing the focus session failed', error, stack);
    }
    return minutes;
  }
}

final focusProvider = NotifierProvider<FocusController, FocusSession?>(FocusController.new);

/// Days on which flashcards were reviewed on this device.
final reviewDaysProvider = StreamProvider.autoDispose<Set<CalendarDate>>((ref) {
  final db = ref.watch(appDatabaseProvider);
  final since = ref.watch(clockProvider)().subtract(const Duration(days: FocusRules.logDays));
  final query = db.selectOnly(db.cardReviews)
    ..addColumns([db.cardReviews.reviewedAt])
    ..where(db.cardReviews.reviewedAt.isBiggerOrEqualValue(since));
  return query.watch().map(
    (rows) => {
      for (final row in rows)
        if (row.read(db.cardReviews.reviewedAt) case final at?) CalendarDate.fromDateTime(at),
    },
  );
});

/// Days with any study activity: practice answers (from the server, when reachable),
/// flashcard reviews and focus sessions (this device). Only real activity counts.
final activityDaysProvider = Provider.autoDispose<Set<CalendarDate>>((ref) {
  final practice = ref.watch(practiceAnalyticsProvider).value;
  final reviews = ref.watch(reviewDaysProvider).value ?? const <CalendarDate>{};
  final focus = ref.watch(focusLogProvider);
  return {
    for (final day in practice?.daily ?? const <DailyStats>[])
      if (day.answered > 0) day.date,
    ...reviews,
    for (final entry in focus.entries)
      if (entry.value > 0) entry.key,
  };
});

/// Today's numbers for the Home "momentum" card (all real counts).
class TodayProgress {
  const TodayProgress({
    required this.focusMinutes,
    required this.answered,
    required this.reviewed,
    required this.streak,
  });

  final int focusMinutes;
  final int? answered; // null when practice data couldn't be loaded (offline)
  final int reviewed;
  final int streak;
}

final reviewedTodayProvider = StreamProvider.autoDispose<int>((ref) {
  final db = ref.watch(appDatabaseProvider);
  final today = ref.watch(todayProvider);
  final start = DateTime(today.year, today.month, today.day);
  final count = db.cardReviews.id.count();
  final query = db.selectOnly(db.cardReviews)
    ..addColumns([count])
    ..where(db.cardReviews.reviewedAt.isBiggerOrEqualValue(start));
  return query.watchSingle().map((row) => row.read(count) ?? 0);
});

final todayProgressProvider = Provider.autoDispose<TodayProgress>((ref) {
  final today = ref.watch(todayProvider);
  final practice = ref.watch(practiceAnalyticsProvider).value;
  int? answered;
  if (practice != null) {
    answered = 0;
    for (final day in practice.daily) {
      if (day.date == today) answered = day.answered;
    }
  }
  return TodayProgress(
    focusMinutes: ref.watch(focusLogProvider)[today] ?? 0,
    answered: answered,
    reviewed: ref.watch(reviewedTodayProvider).value ?? 0,
    streak: currentStreak(ref.watch(activityDaysProvider), today),
  );
});
