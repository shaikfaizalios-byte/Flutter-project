import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_timezone/flutter_timezone.dart';

import '../../../app/app_features.dart';
import '../../../core/network/api_client.dart';
import '../../../core/utils/app_log.dart';
import '../../practice/application/practice_providers.dart';
import '../../practice/domain/practice_models.dart';
import '../../revision/application/revision_providers.dart';
import '../../study_plan/application/study_profile_controller.dart';
import '../data/analytics_repository.dart';
import '../domain/analytics_models.dart';
import '../domain/study_plan.dart';
import '../domain/weak_topics.dart';
import '../../exams/application/active_exam.dart';
import '../domain/speed.dart';
import '../../../core/database/app_database.dart';

/// The device's IANA timezone (server statistics are bucketed by the learner's local days).
final localTimezoneProvider = FutureProvider<String>(
  (ref) async => (await FlutterTimezone.getLocalTimezone()).identifier,
);

final analyticsRepositoryProvider = Provider<AnalyticsRepository>(
  (ref) => AnalyticsRepository(ref.watch(dioProvider)),
);

Duration? _noRetry(int retryCount, Object error) => null;

/// Topics shared by the learner's exams. Asked only with two or more exams, under the flag.
final canonicalStatsProvider = FutureProvider.autoDispose<List<CanonicalTopic>>((ref) async {
  if (!ref.watch(appFeaturesProvider).examProfiles) return const [];
  final exams = ref.watch(studyProfileProvider.select((p) => p.examCodes));
  if (exams.length < 2) return const [];
  return ref.watch(analyticsRepositoryProvider).canonical(exams);
}, retry: (_, _) => null);

/// Server practice statistics of the current exam (needs a connection).
final practiceAnalyticsProvider = FutureProvider.autoDispose<PracticeAnalytics>((ref) async {
  final exam = ref.watch(activeExamProvider);
  final timezone = await ref.watch(localTimezoneProvider.future);
  try {
    return await ref
        .watch(analyticsRepositoryProvider)
        .overview(timezone: timezone, examCode: exam);
  } on Object catch (error, stack) {
    logError('Loading practice statistics failed', error, stack);
    rethrow;
  }
}, retry: _noRetry);

/// Flashcard reviews over the analysis window (device data, always available).
final revisionStatsProvider = StreamProvider.autoDispose<RevisionStats>((ref) {
  final since = ref.watch(todayProvider).addDays(-(AnalyticsRules.windowDays - 1));
  return ref.watch(revisionRepositoryProvider).watchStats(since: since);
}, retry: _noRetry);

/// Topic judgements plus whether server statistics were available.
@immutable
class TopicInsights {
  const TopicInsights({required this.topics, required this.practice});

  final List<TopicAssessment> topics;

  /// Null when practice statistics could not be loaded (offline).
  final PracticeAnalytics? practice;

  List<TopicAssessment> get weak => [
    for (final t in topics)
      if (t.isWeak) t,
  ];
}

/// Combines server practice statistics and on-device flashcard recall. When the server
/// is unreachable it still assesses flashcard recall and says so.
final topicInsightsProvider = Provider.autoDispose<AsyncValue<TopicInsights>>((ref) {
  final revision = ref.watch(revisionStatsProvider);
  final practice = ref.watch(practiceAnalyticsProvider);
  if (revision is AsyncError<RevisionStats>) {
    return AsyncError(revision.error, revision.stackTrace);
  }
  final stats = revision.value;
  if (stats == null || practice.isLoading) return const AsyncLoading();
  final server = practice.value;
  return AsyncData(TopicInsights(topics: assessTopics(server, stats), practice: server));
});

/// Today's plan from due revision, weak topics, the daily goal, the exam date and mocks.
final studyPlanProvider = Provider.autoDispose<AsyncValue<StudyPlan>>((ref) {
  final overview = ref.watch(revisionOverviewProvider);
  final insights = ref.watch(topicInsightsProvider);
  final mocks = ref.watch(mockTestsProvider);
  final profile = ref.watch(studyProfileProvider);
  if (overview case AsyncError(:final error, :final stackTrace)) {
    return AsyncError(error, stackTrace);
  }
  if (insights case AsyncError(:final error, :final stackTrace)) {
    return AsyncError(error, stackTrace);
  }
  final revision = overview.value;
  final topics = insights.value;
  if (revision == null || topics == null || mocks.isLoading) return const AsyncLoading();

  final practice = topics.practice;
  final mock = (mocks.value ?? const <MockTestView>[])
      .where(
        (m) =>
            m.available &&
            m.durationMinutes != null &&
            (profile.examCodes.isEmpty || m.examCode == ref.watch(activeExamProvider)),
      )
      .firstOrNull;
  return AsyncData(
    buildStudyPlan(
      today: ref.watch(todayProvider),
      dueCards: revision.dueToday,
      overdueCards: revision.overdue,
      topics: topics.topics,
      practiceDataAvailable: practice != null,
      answeredTotal: practice?.total.answered ?? 0,
      dailyMinutes: profile.dailyStudyMinutes,
      examDate: profile.targetExamDate,
      mock: mock == null
          ? null
          : AvailableMock(code: mock.code, name: mock.name, minutes: mock.durationMinutes!),
      lastMockOn: practice?.mocks.firstOrNull?.localDate,
    ),
  );
});

/// `app_settings` key of the learner's own seconds per question for an exam without a
/// verified format.
String speedTargetKey(String exam) => 'speed_target:$exam';

/// The learner's own target for the current exam (null when not set).
final ownSpeedTargetProvider = FutureProvider.autoDispose<double?>((ref) async {
  final exam = ref.watch(activeExamProvider);
  if (exam == null) return null;
  final db = ref.watch(appDatabaseProvider);
  final row = await (db.select(
    db.appSettings,
  )..where((s) => s.key.equals(speedTargetKey(exam)))).getSingleOrNull();
  return double.tryParse(row?.value ?? '');
});

Future<void> saveOwnSpeedTarget(AppDatabase db, String exam, int seconds) => db
    .into(db.appSettings)
    .insertOnConflictUpdate(
      AppSettingsCompanion.insert(key: speedTargetKey(exam), value: '$seconds'),
    );

/// Speed per question type for the current exam (needs a connection).
final speedReportProvider = FutureProvider.autoDispose<SpeedReport?>((ref) async {
  final exam = ref.watch(activeExamProvider);
  if (exam == null) return null;
  final own = await ref.watch(ownSpeedTargetProvider.future);
  return ref.watch(analyticsRepositoryProvider).speed(exam, ownTargetSeconds: own);
}, retry: _noRetry);
