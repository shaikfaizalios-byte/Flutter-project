import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/localization/content_language.dart';
import '../../../core/utils/app_log.dart';
import '../../../core/utils/clock.dart';
import '../../exams/application/active_exam.dart';
import '../../practice/application/practice_providers.dart' show timeOnQuestion;
import '../data/ladder_repository.dart';
import '../domain/ladder_models.dart';

/// `app_settings` key: the learner agreed that their paper questions go to the AI service to
/// create practice questions. Asked once, before the first ladder.
const ladderConsentKey = 'ladder_ai_consent';

/// Topics and the learner's best climb for the current exam.
final ladderOverviewProvider = FutureProvider.autoDispose<LadderOverview?>((ref) async {
  final exam = ref.watch(activeExamProvider);
  if (exam == null) return null;
  return ref.watch(ladderRepositoryProvider).overview(exam);
}, retry: (_, _) => null);

Future<bool> ladderConsentGiven(AppDatabase db) async {
  final row = await (db.select(
    db.appSettings,
  )..where((s) => s.key.equals(ladderConsentKey))).getSingleOrNull();
  return row?.value == 'true';
}

Future<void> saveLadderConsent(AppDatabase db) => db
    .into(db.appSettings)
    .insertOnConflictUpdate(AppSettingsCompanion.insert(key: ladderConsentKey, value: 'true'));

enum LadderStage { intro, writing, question, results, failed }

/// Which ladder: the topic, the exam and the language to write in.
typedef LadderKey = ({String examCode, String topicId, String topicName, ContentLanguage language});

@immutable
class LadderRunState {
  const LadderRunState({
    this.stage = LadderStage.intro,
    this.round,
    this.current = 0,
    this.written = 0,
    this.failure,
  });

  final LadderStage stage;
  final LadderRound? round;

  /// Index of the step on screen.
  final int current;

  /// Steps whose question has passed its checks (the loading ladder).
  final int written;
  final Object? failure;

  LadderStep? get step => round?.steps[current];

  LadderRunState copyWith({
    LadderStage? stage,
    LadderRound? round,
    int? current,
    int? written,
    Object? Function()? failure,
  }) => LadderRunState(
    stage: stage ?? this.stage,
    round: round ?? this.round,
    current: current ?? this.current,
    written: written ?? this.written,
    failure: failure == null ? this.failure : failure(),
  );
}

/// One run of the ladder. Questions are asked for one at a time, so the loading ladder fills in
/// as each passes its checks; the first question appears only after all five have.
class LadderRun extends Notifier<LadderRunState> {
  LadderRun(this.key);

  final LadderKey key;

  /// When the question on screen appeared (for the time spent on it).
  DateTime? _shownAt;

  LadderRepository get _repo => ref.read(ladderRepositoryProvider);

  @override
  LadderRunState build() => const LadderRunState();

  Future<void> start() async {
    state = state.copyWith(stage: LadderStage.writing, written: 0, failure: () => null);
    try {
      final round = await _repo.start(
        examCode: key.examCode,
        topicId: key.topicId,
        language: key.language,
      );
      await _write(round);
    } on Object catch (error, stack) {
      _fail(error, stack);
    }
  }

  /// "Test me more".
  Future<void> more() async {
    final previous = state.round;
    if (previous == null) return;
    state = state.copyWith(stage: LadderStage.writing, written: 0, failure: () => null);
    try {
      await _write(await _repo.nextRound(previous.sessionId));
    } on Object catch (error, stack) {
      _fail(error, stack);
    }
  }

  /// After a failure: goes on from what is already written.
  Future<void> retry() async {
    final round = state.round;
    if (round == null || round.allReady) return start();
    state = state.copyWith(stage: LadderStage.writing, failure: () => null);
    try {
      await _write(round);
    } on Object catch (error, stack) {
      _fail(error, stack);
    }
  }

  Future<void> _write(LadderRound planned) async {
    var round = planned;
    state = state.copyWith(round: round, current: 0, written: _ready(round));
    for (final step in planned.steps.where((s) => !s.ready)) {
      final written = await _repo.generate(round.sessionId, round.roundNumber, step.step);
      if (!ref.mounted) return;
      round = round.withStep(written);
      state = state.copyWith(round: round, written: _ready(round));
    }
    _shownAt = ref.read(clockProvider)();
    state = state.copyWith(stage: LadderStage.question, round: round, current: 0);
  }

  int _ready(LadderRound round) => round.steps.where((s) => s.ready).length;

  Future<void> answer(int selectedIndex) => _send(selectedIndex: selectedIndex);

  /// The answer to a question that takes a number.
  Future<void> answerTyped(String text) => _send(typedAnswer: text);

  /// The answer to a question with several options or pairs.
  Future<void> answerResponse(Map<String, dynamic> response) => _send(response: response);

  Future<void> _send({
    int? selectedIndex,
    String? typedAnswer,
    Map<String, dynamic>? response,
  }) async {
    final round = state.round;
    final step = state.step;
    if (round == null || step == null || step.answered) return;
    try {
      final answered = await _repo.answer(
        round.sessionId,
        round.roundNumber,
        step.step,
        selectedIndex: selectedIndex,
        typedAnswer: typedAnswer,
        response: response,
        timeSpentMs: timeOnQuestion(_shownAt, ref.read(clockProvider)()),
      );
      if (ref.mounted) state = state.copyWith(round: round.withStep(answered));
    } on Object catch (error, stack) {
      _fail(error, stack);
    }
  }

  void next() {
    final round = state.round;
    if (round == null) return;
    if (state.current + 1 >= round.steps.length) {
      state = state.copyWith(stage: LadderStage.results);
      ref.invalidate(ladderOverviewProvider); // a new best may have been set
    } else {
      _shownAt = ref.read(clockProvider)();
      state = state.copyWith(current: state.current + 1);
    }
  }

  void _fail(Object error, StackTrace stack) {
    if (error is! AppFailure) logError('Challenge Ladder failed', error, stack);
    if (ref.mounted) state = state.copyWith(stage: LadderStage.failed, failure: () => error);
  }
}

final ladderRunProvider = NotifierProvider.autoDispose.family<LadderRun, LadderRunState, LadderKey>(
  LadderRun.new,
);
