import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/network/api_client.dart';
import '../../../core/utils/app_log.dart';
import '../../../core/utils/clock.dart';
import '../../exams/application/active_exam.dart';
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

/// Replays answers saved offline and uploads offline sessions (e.g. when the Practice tab
/// opens), then refreshes the questions saved for offline practice. Never throws.
final pendingAnswersFlushProvider = FutureProvider.autoDispose<int>((ref) async {
  final repo = ref.read(practiceRepositoryProvider);
  var sent = 0;
  try {
    sent = await repo.flush();
  } on Object catch (error, stack) {
    logError('Replaying saved answers failed', error, stack);
  }
  try {
    await repo.refreshOfflinePack();
  } on AppFailure {
    // Offline or server unavailable: keep the questions already saved.
  } on Object catch (error, stack) {
    logError('Refreshing the offline pack failed', error, stack);
  }
  ref.invalidate(offlineStatusProvider);
  return sent;
});

/// Questions saved for offline practice, and offline sessions waiting to upload.
final offlineStatusProvider = FutureProvider.autoDispose<({int questions, int toUpload})>((
  ref,
) async {
  final repo = ref.watch(practiceRepositoryProvider);
  return (
    questions: await repo.offlineQuestionCount(),
    toUpload: await repo.offlineSessionsToUpload(),
  );
});

// Mock tests, history, bookmarks and questions to revisit show the current exam only.
final mockTestsProvider = FutureProvider.autoDispose<List<MockTestView>>((ref) async {
  final exam = ref.watch(activeExamProvider);
  final mocks = await ref.watch(practiceRepositoryProvider).mockTests();
  return [
    for (final m in mocks)
      if (exam == null || m.examCode == exam) m,
  ];
}, retry: _noRetry);

final sessionHistoryProvider = FutureProvider.autoDispose<List<SessionSummaryView>>((ref) async {
  final exam = ref.watch(activeExamProvider);
  final sessions = await ref.watch(practiceRepositoryProvider).history();
  // Sessions from before exams were separated (no exam) stay visible everywhere.
  return [
    for (final s in sessions)
      if (exam == null || s.examCode == null || s.examCode == exam) s,
  ];
}, retry: _noRetry);

final bookmarkedQuestionsProvider = FutureProvider.autoDispose<List<BankQuestion>>((ref) async {
  final exam = ref.watch(activeExamProvider);
  final questions = await ref.watch(practiceRepositoryProvider).bookmarks();
  return [
    for (final q in questions)
      if (exam == null || q.examCode == exam) q,
  ];
}, retry: _noRetry);

final incorrectQuestionsProvider = FutureProvider.autoDispose<List<BankQuestion>>((ref) async {
  final exam = ref.watch(activeExamProvider);
  final questions = await ref.watch(practiceRepositoryProvider).incorrect();
  return [
    for (final q in questions)
      if (exam == null || q.examCode == exam) q,
  ];
}, retry: _noRetry);

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

  /// Seconds left on a mock test, from the server deadline (null when untimed). In a
  /// sectionally timed mock this is the open section's time.
  int? remainingSeconds(DateTime deviceNow) {
    final deadline = session.sectional ? session.sectionDeadlineAt : session.deadlineAt;
    if (deadline == null || session.submitted) return null;
    final serverNow = deviceNow.add(clockOffset);
    final left = deadline.difference(serverNow).inSeconds;
    return left < 0 ? 0 : left;
  }
}

/// Where to start in [session]: the first unanswered question that can be answered now.
int _startIndex(PracticeSessionView session) {
  if (session.submitted) return 0;
  final open = [
    for (final (i, item) in session.items.indexed)
      if (session.isOpen(item.position)) i,
  ];
  if (open.isEmpty) return 0;
  return open.firstWhere((i) => !session.items[i].answered, orElse: () => open.first);
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
    return SessionState(
      session: session,
      clockOffset: session.serverNow.difference(fetchedAt),
      current: _startIndex(session),
    );
  }

  void goTo(int index) {
    final value = state.value;
    if (value == null || index < 0 || index >= value.session.items.length) return;
    if (!value.session.isOpen(value.session.items[index].position)) return;
    state = AsyncData(value.copyWith(current: index));
  }

  /// Closes the open section early in a sectionally timed mock; the next one opens (the
  /// last one submits the test).
  Future<void> finishSection() async {
    final value = state.value;
    final section = value?.session.currentSection;
    if (value == null || section == null || value.session.submitted || value.submitting) return;
    state = AsyncData(value.copyWith(submitting: true));
    try {
      final updated = await _repo.finishSection(sessionId, section);
      _replace(updated, value.clockOffset);
    } on Object catch (error, stack) {
      if (error is! AppFailure) logError('Finishing a section failed', error, stack);
      state = AsyncData(value.copyWith(submitting: false));
      rethrow;
    }
  }

  /// Reloads the session from the server (a section's time ran out: the server opens the
  /// next one, or submits after the last).
  Future<void> refresh() async {
    final value = state.value;
    if (value == null) return;
    final fetchedAt = ref.read(clockProvider)();
    final updated = await _repo.session(sessionId);
    _replace(updated, updated.serverNow.difference(fetchedAt));
  }

  void _replace(PracticeSessionView session, Duration clockOffset) {
    state = AsyncData(
      SessionState(session: session, clockOffset: clockOffset, current: _startIndex(session)),
    );
    if (session.submitted) {
      ref
        ..invalidate(sessionHistoryProvider)
        ..invalidate(incorrectQuestionsProvider);
    }
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
      if (failure.code == 'session_closed' || failure.code == 'section_closed') {
        ref.invalidateSelf(); // reload: the session was submitted or its section closed
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
      if (failure.code == 'session_closed' || failure.code == 'section_closed') {
        ref.invalidateSelf();
      }
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
