import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../analytics/application/analytics_providers.dart';
import '../../analytics/domain/analytics_models.dart';
import '../../concepts/application/concepts_providers.dart';
import '../../exams/application/active_exam.dart';
import '../../exams/application/exam_catalog_controller.dart';
import '../../revision/application/revision_providers.dart';
import '../../study_plan/application/study_profile_controller.dart';
import '../domain/mastery.dart';
import '../domain/readiness.dart';

/// Mastery per subject and topic of the current exam: its syllabus topics (server) plus the
/// subjects and topics of the learner's concepts. Practice statistics are optional (offline,
/// levels use flashcard recall and the "revised" marks only); without the topic list (offline)
/// only the concepts' topics are shown.
final examMasteryProvider = Provider.autoDispose<AsyncValue<List<SubjectMastery>>>((ref) {
  final exam = ref.watch(activeExamProvider);
  final topics = exam == null ? null : ref.watch(examTopicsProvider(exam));
  final revision = ref.watch(revisionStatsProvider);
  final practice = ref.watch(practiceAnalyticsProvider);
  final facets = ref.watch(conceptFacetsProvider);
  // Flashcard recall (device) fills in once loaded; it never holds the levels back.
  if ((topics?.isLoading ?? false) || practice.isLoading) {
    return const AsyncLoading();
  }
  final concepts = facets.value;
  return AsyncData(
    examMastery(
      topics: topics?.value ?? const [],
      practice: practice.value,
      revision: revision.value ?? const RevisionStats(),
      conceptTopics: concepts == null
          ? const {}
          : {for (final s in concepts.subjects) s: concepts.topicsFor(s)},
    ),
  );
});

/// Readiness for the current exam: coverage of its syllabus topics (the learner's own concept
/// topics are left out) and the practice evidence behind it. Never a prediction.
final readinessProvider = Provider.autoDispose<AsyncValue<Readiness>>((ref) {
  final exam = ref.watch(activeExamProvider);
  final topics = exam == null ? null : ref.watch(examTopicsProvider(exam));
  final revision = ref.watch(revisionStatsProvider);
  final practice = ref.watch(practiceAnalyticsProvider);
  if ((topics?.isLoading ?? false) || practice.isLoading) return const AsyncLoading();
  return AsyncData(
    buildReadiness(
      subjects: examMastery(
        topics: topics?.value ?? const [],
        practice: practice.value,
        revision: revision.value ?? const RevisionStats(),
      ),
      today: ref.watch(todayProvider),
      practice: practice.value,
      examDate: ref.watch(studyProfileProvider.select((p) => p.targetExamDate)),
    ),
  );
});
