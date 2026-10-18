import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/questions_repository.dart';
import '../domain/question.dart';

// Server-backed data: show errors (offline, server down) instead of retrying silently.
Duration? _noRetry(int retryCount, Object error) => null;

final questionListProvider = FutureProvider.autoDispose
    .family<(List<BankQuestion>, int), QuestionQuery>(
      (ref, query) => ref.watch(questionsRepositoryProvider).list(query),
      retry: _noRetry,
    );

final questionProvider = FutureProvider.autoDispose.family<BankQuestion, String>(
  (ref, id) => ref.watch(questionsRepositoryProvider).get(id),
  retry: _noRetry,
);

final parseSummaryProvider = FutureProvider.autoDispose.family<ParseSummary, String>(
  (ref, documentId) => ref.watch(questionsRepositoryProvider).parseSummary(documentId),
  retry: _noRetry,
);

/// Topics for one exam (null: every exam the learner can see).
final topicsProvider = FutureProvider.family<List<TopicRef>, String?>(
  (ref, examCode) => ref.watch(questionsRepositoryProvider).topics(examCode: examCode),
  retry: _noRetry,
);

/// Figure images never change (a re-parse creates new ids), so they stay cached.
final figureBytesProvider = FutureProvider.family<Uint8List, (String, String)>(
  (ref, key) => ref.watch(questionsRepositoryProvider).figure(key.$1, key.$2),
  retry: _noRetry,
);

final patternsProvider = FutureProvider<List<PatternRef>>(
  (ref) => ref.watch(questionsRepositoryProvider).patterns(),
  retry: _noRetry,
);

final sourcePageTextProvider = FutureProvider.autoDispose.family<String, (String, int)>(
  (ref, key) => ref.watch(questionsRepositoryProvider).pageText(key.$1, key.$2),
  retry: _noRetry,
);

/// Search text and filters on the question bank screen.
class BankQueryController extends Notifier<QuestionQuery> {
  @override
  QuestionQuery build() => const QuestionQuery();

  void setText(String text) => state = QuestionQuery(
    examCode: state.examCode,
    status: state.status,
    hasIssues: state.hasIssues,
    text: text,
  );

  void setExam(String? exam) => state = QuestionQuery(
    examCode: exam,
    status: state.status,
    hasIssues: state.hasIssues,
    text: state.text,
  );

  /// One review filter at a time: all, needs attention, verified, rejected.
  void setReviewFilter(ReviewFilter filter) => state = QuestionQuery(
    examCode: state.examCode,
    text: state.text,
    status: switch (filter) {
      ReviewFilter.verified => VerificationStatus.verified,
      ReviewFilter.rejected => VerificationStatus.rejected,
      ReviewFilter.needsAttention => VerificationStatus.unverified,
      ReviewFilter.all => null,
    },
    hasIssues: filter == ReviewFilter.needsAttention ? true : null,
  );
}

enum ReviewFilter { all, needsAttention, verified, rejected }

ReviewFilter reviewFilterOf(QuestionQuery query) => switch (query) {
  QuestionQuery(status: VerificationStatus.verified) => ReviewFilter.verified,
  QuestionQuery(status: VerificationStatus.rejected) => ReviewFilter.rejected,
  QuestionQuery(hasIssues: true) => ReviewFilter.needsAttention,
  _ => ReviewFilter.all,
};

final bankQueryProvider = NotifierProvider<BankQueryController, QuestionQuery>(
  BankQueryController.new,
);
