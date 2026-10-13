import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_timezone/flutter_timezone.dart';

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

/// The device's IANA timezone (server statistics are bucketed by the learner's local days).
final localTimezoneProvider = FutureProvider<String>(
  (ref) async => (await FlutterTimezone.getLocalTimezone()).identifier,
);

final analyticsRepositoryProvider = Provider<AnalyticsRepository>(
  (ref) => AnalyticsRepository(ref.watch(dioProvider)),
);

Duration? _noRetry(int retryCount, Object error) => null;

/// Server practice statistics (needs a connection).
final practiceAnalyticsProvider = FutureProvider.autoDispose<PracticeAnalytics>((ref) async {
  final timezone = await ref.watch(localTimezoneProvider.future);
  try {
    return await ref.watch(analyticsRepositoryProvider).overview(timezone: timezone);
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
            (profile.examCodes.isEmpty || profile.examCodes.contains(m.examCode)),
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
