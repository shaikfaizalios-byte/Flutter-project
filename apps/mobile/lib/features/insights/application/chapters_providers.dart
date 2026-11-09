import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../study_plan/application/study_profile_controller.dart';
import '../data/insights_repository.dart';
import '../domain/chapters.dart';

Duration? _noRetry(int count, Object error) => null;

final chapterReportProvider = FutureProvider.autoDispose.family<ChapterReport, String>(
  (ref, exam) => ref.watch(insightsRepositoryProvider).chapters(exam),
  retry: _noRetry,
);

/// Hints are extra: without them the screen still stands.
final conceptHintsProvider = FutureProvider.autoDispose.family<List<ConceptHint>, String>(
  (ref, exam) => ref.watch(insightsRepositoryProvider).conceptHints(exam),
  retry: _noRetry,
);

/// Chapters shared by the exams this learner prepares for; none with a single exam.
final sharedChaptersProvider = FutureProvider.autoDispose<List<SharedChapter>>((ref) async {
  final exams = ref.watch(studyProfileProvider.select((p) => p.examCodes));
  if (exams.length < 2) return const [];
  return ref.watch(insightsRepositoryProvider).sharedChapters(exams.take(4).toList());
}, retry: _noRetry);
