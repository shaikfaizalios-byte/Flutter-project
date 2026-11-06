import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/localization/content_language.dart';
import '../../../core/utils/app_log.dart';
import '../../exams/application/active_exam.dart';
import '../data/descriptive_repository.dart';
import '../domain/descriptive_models.dart';

/// Whether the current exam has written practice, and its topics.
final descriptiveOverviewProvider = FutureProvider.autoDispose<DescriptiveOverview?>((ref) async {
  final exam = ref.watch(activeExamProvider);
  if (exam == null) return null;
  return ref.watch(descriptiveRepositoryProvider).overview(exam);
}, retry: (_, _) => null);

/// A photo chosen from the device.
typedef PickedPhoto = ({String name, List<int> bytes});

/// Opens the file picker for one photo; null if the learner cancels. Overridden in tests.
final photoPickerProvider = Provider<Future<PickedPhoto?> Function()>((ref) => _pickPhoto);

Future<PickedPhoto?> _pickPhoto() async {
  final file = await FilePicker.pickFile(
    type: FileType.custom,
    allowedExtensions: ['jpg', 'jpeg', 'png'],
  );
  if (file == null) return null;
  return (name: file.name, bytes: await file.readAsBytes());
}

enum DescriptiveStage { intro, writing, question, marking, finished, failed }

typedef DescriptiveKey = ({String examCode, String topicId, ContentLanguage language});

@immutable
class DescriptiveRunState {
  const DescriptiveRunState({
    this.stage = DescriptiveStage.intro,
    this.session,
    this.current = 0,
    this.failure,
  });

  final DescriptiveStage stage;
  final DescriptiveSession? session;

  /// Index of the step on screen.
  final int current;
  final Object? failure;

  DescriptiveStep? get step => session?.steps[current];

  DescriptiveRunState copyWith({
    DescriptiveStage? stage,
    DescriptiveSession? session,
    int? current,
    Object? Function()? failure,
  }) => DescriptiveRunState(
    stage: stage ?? this.stage,
    session: session ?? this.session,
    current: current ?? this.current,
    failure: failure == null ? this.failure : failure(),
  );
}

/// One written practice session. Each level's question is written when the learner reaches it.
class DescriptiveRun extends Notifier<DescriptiveRunState> {
  DescriptiveRun(this.key);

  final DescriptiveKey key;

  /// Real questions from the learner's papers, not AI-written ones.
  bool _fromPapers = false;

  DescriptiveRepository get _repo => ref.read(descriptiveRepositoryProvider);

  @override
  DescriptiveRunState build() => const DescriptiveRunState();

  Future<void> start({bool fromPapers = false}) async {
    _fromPapers = fromPapers;
    state = state.copyWith(stage: DescriptiveStage.writing, failure: () => null);
    try {
      final session = await _repo.start(
        examCode: key.examCode,
        topicId: key.topicId,
        language: key.language,
        fromPapers: fromPapers,
      );
      await _write(session, 0);
    } on Object catch (error, stack) {
      _fail(error, stack);
    }
  }

  Future<void> _write(DescriptiveSession session, int index) async {
    state = state.copyWith(stage: DescriptiveStage.writing, session: session, current: index);
    final written = await _repo.generate(session.sessionId, session.steps[index].step);
    if (!ref.mounted) return;
    state = state.copyWith(stage: DescriptiveStage.question, session: session.withStep(written));
  }

  /// Marks the answer. On failure the screen keeps the text, so it can be sent again.
  Future<void> submit(String text, {required bool fromPhoto}) async {
    final session = state.session;
    final step = state.step;
    if (session == null || step == null) return;
    state = state.copyWith(stage: DescriptiveStage.marking, failure: () => null);
    try {
      final marked = await _repo.answer(
        session.sessionId,
        step.step,
        text: text,
        fromPhoto: fromPhoto,
      );
      if (!ref.mounted) return;
      state = state.copyWith(stage: DescriptiveStage.question, session: session.withStep(marked));
    } on Object catch (error, stack) {
      if (error is! AppFailure) logError('Written practice failed', error, stack);
      if (ref.mounted) {
        state = state.copyWith(stage: DescriptiveStage.question, failure: () => error);
      }
    }
  }

  Future<void> next() async {
    final session = state.session;
    if (session == null) return;
    final index = state.current + 1;
    if (index >= session.steps.length) {
      state = state.copyWith(stage: DescriptiveStage.finished);
      return;
    }
    try {
      await _write(session, index);
    } on Object catch (error, stack) {
      _fail(error, stack);
    }
  }

  /// After a failure: writes the question that failed, or starts again.
  Future<void> retry() async {
    final session = state.session;
    if (session == null) return start(fromPapers: _fromPapers);
    state = state.copyWith(failure: () => null);
    try {
      await _write(session, state.current);
    } on Object catch (error, stack) {
      _fail(error, stack);
    }
  }

  void _fail(Object error, StackTrace stack) {
    if (error is! AppFailure) logError('Written practice failed', error, stack);
    if (ref.mounted) state = state.copyWith(stage: DescriptiveStage.failed, failure: () => error);
  }
}

final descriptiveRunProvider = NotifierProvider.autoDispose
    .family<DescriptiveRun, DescriptiveRunState, DescriptiveKey>(DescriptiveRun.new);
