import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/network/api_client.dart';
import '../../../core/utils/app_log.dart';
import '../../../core/utils/clock.dart';
import '../../question_bank/domain/question.dart';
import '../data/practice_repository.dart';
import '../domain/practice_models.dart';

final practiceRepositoryProvider = Provider<PracticeRepository>(
  (ref) => PracticeRepository(
    ref.watch(dioProvider),
    ref.watch(appDatabaseProvider),
    clock: ref.watch(clockProvider),
  ),
);

Duration? _noRetry(int retryCount, Object error) => null;

/// Replays answers saved offline (e.g. when the Practice tab opens). Never throws.
final pendingAnswersFlushProvider = FutureProvider.autoDispose<int>((ref) async {
  try {
    return await ref.read(practiceRepositoryProvider).flush();
  } on Object catch (error, stack) {
    logError('Replaying saved answers failed', error, stack);
    return 0;
  }
});

final mockTestsProvider = FutureProvider.autoDispose<List<MockTestView>>(
  (ref) => ref.watch(practiceRepositoryProvider).mockTests(),
  retry: _noRetry,
);

final sessionHistoryProvider = FutureProvider.autoDispose<List<SessionSummaryView>>(
  (ref) => ref.watch(practiceRepositoryProvider).history(),
  retry: _noRetry,
);

final bookmarkedQuestionsProvider = FutureProvider.autoDispose<List<BankQuestion>>(
  (ref) => ref.watch(practiceRepositoryProvider).bookmarks(),
  retry: _noRetry,
);

final incorrectQuestionsProvider = FutureProvider.autoDispose<List<BankQuestion>>(
  (ref) => ref.watch(practiceRepositoryProvider).incorrect(),
  retry: _noRetry,
);

@immutable
class SessionState {
  const SessionState({
    required this.session,
    required this.clockOffset,
    this.current = 0,
    this.queuedPositions = const {},
    this.submitting = false,
  });

  final PracticeSessionView session;

  /// server time − device time when the session was fetched. Used only to display the
  /// countdown; the deadline itself always comes from the server.
  final Duration clockOffset;

  /// Index into [PracticeSessionView.items].
  final int current;

  /// Answers saved on the device but not yet confirmed by the server.
  final Set<int> queuedPositions;
  final bool submitting;

  SessionItemView get item => session.items[current];

  SessionState copyWith({
    PracticeSessionView? session,
    int? current,
    Set<int>? queuedPositions,
    bool? submitting,
  }) => SessionState(
    session: session ?? this.session,
    clockOffset: clockOffset,
    current: current ?? this.current,
    queuedPositions: queuedPositions ?? this.queuedPositions,
    submitting: submitting ?? this.submitting,
  );

  /// Seconds left on a mock test, from the server deadline (null when untimed).
  int? remainingSeconds(DateTime deviceNow) {
    final deadline = session.deadlineAt;
    if (deadline == null || session.submitted) return null;
    final serverNow = deviceNow.add(clockOffset);
    final left = deadline.difference(serverNow).inSeconds;
    return left < 0 ? 0 : left;
  }
}

/// Drives one session screen. The server is the source of truth; answers go through the
/// offline queue, and an expired mock is submitted (idempotently) when its time is up.
class SessionController extends AsyncNotifier<SessionState> {
  SessionController(this.sessionId);

  final String sessionId;

  PracticeRepository get _repo => ref.read(practiceRepositoryProvider);

  @override
  Future<SessionState> build() async {
    final fetchedAt = ref.read(clockProvider)();
    final session = await _repo.session(sessionId);
    final current = session.items.indexWhere((i) => !i.answered);
    return SessionState(
      session: session,
      clockOffset: session.serverNow.difference(fetchedAt),
      current: session.submitted || current < 0 ? 0 : current,
    );
  }

  void goTo(int index) {
    final value = state.value;
    if (value == null || index < 0 || index >= value.session.items.length) return;
    state = AsyncData(value.copyWith(current: index));
  }

  /// Returns false when the answer could not be saved (e.g. the session closed).
  Future<bool> select(int optionPosition) async {
    final value = state.value;
    if (value == null || value.session.submitted) return false;
    final item = value.item;
    // Practice answers are final once given.
    if (value.session.mode == SessionMode.practice && item.answered) return false;
    final next = value.session.mode == SessionMode.mock && item.selectedPosition == optionPosition
        ? null // tapping the chosen option again clears it in a mock
        : optionPosition;

    state = AsyncData(
      value.copyWith(session: value.session.withItem(item.copyWith(selectedPosition: () => next))),
    );
    try {
      final outcome = await _repo.answer(sessionId, item.position, next);
      final latest = state.value!;
      final queued = {...latest.queuedPositions};
      outcome.queued ? queued.add(item.position) : queued.remove(item.position);
      var updated = latest.session.items.firstWhere((i) => i.position == item.position);
      if (!outcome.queued) {
        updated = updated.copyWith(
          selectedPosition: () => outcome.applied ? next : outcome.selectedPosition ?? next,
          feedback: () => outcome.feedback,
        );
      }
      state = AsyncData(
        latest.copyWith(session: latest.session.withItem(updated), queuedPositions: queued),
      );
      return true;
    } on ServerFailure catch (failure) {
      if (failure.code == 'session_closed') {
        ref.invalidateSelf(); // reload the submitted session and its result
      }
      return false;
    } on Object catch (error, stack) {
      logError('Saving answer failed', error, stack);
      return false;
    }
  }

  /// Saves the answer of a typed-in question. Returns false when it could not be saved.
  Future<bool> submitTyped(String text) async {
    final value = state.value;
    final answer = text.trim();
    if (value == null || value.session.submitted || answer.isEmpty) return false;
    final item = value.item;
    if (!item.isTyped) return false;
    if (value.session.mode == SessionMode.practice && item.answered) return false;
    state = AsyncData(
      value.copyWith(session: value.session.withItem(item.copyWith(typedAnswer: () => answer))),
    );
    try {
      final outcome = await _repo.answer(sessionId, item.position, null, typedAnswer: answer);
      final latest = state.value!;
      final queued = {...latest.queuedPositions};
      outcome.queued ? queued.add(item.position) : queued.remove(item.position);
      var updated = latest.session.items.firstWhere((i) => i.position == item.position);
      if (!outcome.queued) {
        updated = updated.copyWith(
          typedAnswer: () => outcome.applied ? answer : outcome.typedAnswer ?? answer,
          feedback: () => outcome.feedback,
        );
      }
      state = AsyncData(
        latest.copyWith(session: latest.session.withItem(updated), queuedPositions: queued),
      );
      return true;
    } on ServerFailure catch (failure) {
      if (failure.code == 'session_closed') ref.invalidateSelf();
      return false;
    } on Object catch (error, stack) {
      logError('Saving typed answer failed', error, stack);
      return false;
    }
  }

  Future<void> submit() async {
    final value = state.value;
    if (value == null || value.session.submitted || value.submitting) return;
    state = AsyncData(value.copyWith(submitting: true));
    try {
      final submitted = await _repo.submit(sessionId);
      state = AsyncData(SessionState(session: submitted, clockOffset: value.clockOffset));
      ref
        ..invalidate(sessionHistoryProvider)
        ..invalidate(incorrectQuestionsProvider);
    } on Object catch (error, stack) {
      if (error is! AppFailure) logError('Submitting failed', error, stack);
      state = AsyncData(value.copyWith(submitting: false));
      rethrow;
    }
  }

  Future<void> toggleBookmark() async {
    final value = state.value;
    final questionId = value?.item.questionId;
    if (value == null || questionId == null) return;
    final item = value.item;
    await _repo.setBookmark(questionId, bookmarked: !item.bookmarked);
    final latest = state.value!;
    state = AsyncData(
      latest.copyWith(
        session: latest.session.withItem(item.copyWith(bookmarked: !item.bookmarked)),
      ),
    );
    ref.invalidate(bookmarkedQuestionsProvider);
  }
}

final sessionControllerProvider = AsyncNotifierProvider.autoDispose
    .family<SessionController, SessionState, String>(SessionController.new, retry: _noRetry);
