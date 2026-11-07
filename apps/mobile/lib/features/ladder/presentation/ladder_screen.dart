import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_features.dart';
import '../../../app/routes.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../core/database/app_database.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/localization/generated/app_localizations.dart';
import '../../../core/widgets/rich_question_text.dart';
import '../../ai/application/ai_providers.dart';
import '../../ai/presentation/ai_widgets.dart';
import '../../exams/application/active_exam.dart';
import '../../plus/presentation/plus_prompt.dart';
import '../../practice/application/practice_providers.dart';
import '../../practice/domain/practice_models.dart';
import '../../practice/presentation/format_answers.dart';
import '../../practice/presentation/practice_hub_screen.dart' show startAndOpen;
import '../../question_bank/domain/question.dart' show QuestionOption;
import '../../settings/application/app_preferences.dart';
import '../application/ladder_providers.dart';
import '../domain/ladder_models.dart';
import 'ladder_icon.dart';

/// Marks without a needless ".0".
String ladderMarksText(double marks) =>
    marks == marks.roundToDouble() ? marks.toInt().toString() : marks.toString();

/// A ladder step as the practice answer widgets expect it.
SessionItemView _asItem(LadderStep step) => SessionItemView(
  position: step.step,
  options: [
    for (final (index, text) in step.options.indexed)
      QuestionOption(position: index + 1, label: String.fromCharCode(65 + index), text: text),
  ],
  verified: false,
  bookmarked: false,
  stem: step.stem,
  format: step.format,
  formatData: step.formatData,
  response: step.result?.response,
);

String ladderDifficultyLabel(AppLocalizations l10n, LadderDifficulty difficulty) =>
    switch (difficulty) {
      LadderDifficulty.easy => l10n.ladderEasy,
      LadderDifficulty.medium => l10n.ladderMedium,
      LadderDifficulty.mediumHard => l10n.ladderMediumHard,
      LadderDifficulty.hard => l10n.ladderHard,
      LadderDifficulty.extremeHard => l10n.ladderExtremeHard,
    };

/// Why this question looks the way it does: a real paper question, or the pattern it follows.
String ladderBasis(AppLocalizations l10n, LadderStep step) {
  if (step.fromPaper) return l10n.ladderFromPapers(step.paperLabel ?? '');
  if (step.basisPapers > 0 && step.basisWeb) return l10n.ladderBasisBoth(step.basisPapers);
  if (step.basisPapers > 0) return l10n.ladderBasisPapers(step.basisPapers);
  return l10n.ladderBasisWeb;
}

/// One ladder on a topic: the start note, the steps filling in, the questions, the results.
class LadderScreen extends ConsumerWidget {
  const LadderScreen({super.key, required this.topicId, required this.topicName});

  final String topicId;
  final String topicName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final exam = ref.watch(activeExamProvider);
    final status = ref.watch(aiStatusProvider).value;

    final Widget body;
    if (exam == null || status == null) {
      body = const Center(child: CircularProgressIndicator());
    } else if (status.enabled && status.needsPlus) {
      body = PlusPrompt(message: l10n.ladderPlusMessage);
    } else if (!status.enabled) {
      body = _Unavailable(topicId: topicId, message: l10n.ladderAiOff);
    } else {
      final language = ref
          .watch(appPreferencesProvider)
          .aiLanguageFor(Localizations.localeOf(context));
      final key = (examCode: exam, topicId: topicId, topicName: topicName, language: language);
      final state = ref.watch(ladderRunProvider(key));
      final run = ref.read(ladderRunProvider(key).notifier);
      body = switch (state.stage) {
        LadderStage.intro => _Intro(topicName: topicName, onStart: () => _start(context, ref, run)),
        LadderStage.writing => _Writing(written: state.written, round: state.round),
        LadderStage.question => _Question(key: ValueKey(state.current), state: state, run: run),
        LadderStage.results => _Results(state: state, run: run),
        LadderStage.failed => _Failed(state: state, run: run, topicId: topicId),
      };
    }
    return Scaffold(
      appBar: AppBar(title: Text(topicName)),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: AppSpacing.maxContentWidth),
          child: ListView(padding: const EdgeInsets.all(AppSpacing.md), children: [body]),
        ),
      ),
    );
  }

  /// Before the first ladder, says what goes to the AI service.
  Future<void> _start(BuildContext context, WidgetRef ref, LadderRun run) async {
    final l10n = AppLocalizations.of(context);
    final db = ref.read(appDatabaseProvider);
    if (!await ladderConsentGiven(db)) {
      if (!context.mounted) return;
      final agreed = await showDialog<bool>(
        context: context,
        builder: (dialog) => AlertDialog(
          title: Text(l10n.ladderConsentTitle),
          content: Text(l10n.ladderConsentBody),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialog).pop(false),
              child: Text(l10n.ladderConsentNo),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialog).pop(true),
              child: Text(l10n.ladderConsentYes),
            ),
          ],
        ),
      );
      if (agreed != true) return;
      await saveLadderConsent(db);
    }
    await run.start();
  }
}

class _HonestNote extends StatelessWidget {
  const _HonestNote();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text(
      AppLocalizations.of(context).ladderHonestNote,
      style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
    );
  }
}

class _Intro extends ConsumerWidget {
  const _Intro({required this.topicName, required this.onStart});

  final String topicName;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final topic = ref
        .watch(ladderOverviewProvider)
        .value
        ?.topics
        .where((t) => t.name == topicName)
        .firstOrNull;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Center(child: LadderIcon(size: 96)),
        const SizedBox(height: AppSpacing.md),
        Text(l10n.ladderTagline, style: theme.textTheme.titleMedium),
        const SizedBox(height: AppSpacing.sm),
        if (topic != null && topic.papers == 0) ...[
          Text(l10n.ladderWebOnly),
          const SizedBox(height: AppSpacing.sm),
        ],
        const _HonestNote(),
        const SizedBox(height: AppSpacing.md),
        FilledButton.icon(
          icon: const Icon(Icons.play_arrow),
          label: Text(l10n.ladderStart),
          onPressed: onStart,
        ),
      ],
    );
  }
}

/// The five steps fill in as each question passes its checks.
class _Writing extends StatelessWidget {
  const _Writing({required this.written, required this.round});

  final int written;
  final LadderRound? round;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final steps = round?.steps ?? const <LadderStep>[];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.ladderWriting, style: theme.textTheme.titleMedium),
        const SizedBox(height: AppSpacing.xs),
        Text(l10n.ladderWritingHint, style: theme.textTheme.bodySmall),
        const SizedBox(height: AppSpacing.md),
        for (var i = steps.length - 1; i >= 0; i--)
          ListTile(
            contentPadding: EdgeInsets.zero,
            dense: true,
            leading: i < written
                ? Icon(Icons.check_circle, color: ladderStepColors[i])
                : i == written
                ? const SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.radio_button_unchecked),
            title: Text(
              l10n.ladderStepLabel(i + 1, ladderDifficultyLabel(l10n, steps[i].difficulty)),
            ),
          ),
      ],
    );
  }
}

class _Question extends ConsumerStatefulWidget {
  const _Question({super.key, required this.state, required this.run});

  final LadderRunState state;
  final LadderRun run;

  @override
  ConsumerState<_Question> createState() => _QuestionState();
}

class _QuestionState extends ConsumerState<_Question> {
  bool _timerOn = false;
  int _elapsed = 0;
  Timer? _ticker;

  LadderStep get _step => widget.state.step!;

  void _toggleTimer(bool on) {
    setState(() => _timerOn = on);
    _ticker?.cancel();
    if (on) {
      _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted && !_step.answered) setState(() => _elapsed++);
      });
    }
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final step = _step;
    final result = step.result;
    final total = widget.state.round!.steps.length;
    final target = step.timeTargetSeconds;
    final showMarks = ref.watch(appFeaturesProvider).examProfiles;
    final model = step.secondModelName == null
        ? step.modelName
        : '${step.modelName} + ${step.secondModelName}';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.ladderStepOf(step.step, total, ladderDifficultyLabel(l10n, step.difficulty)),
          style: theme.textTheme.titleMedium?.copyWith(color: ladderStepColors[step.step - 1]),
        ),
        if (model != null) Text(model, style: theme.textTheme.bodySmall),
        Text(ladderBasis(l10n, step), style: theme.textTheme.bodySmall),
        if (target != null)
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            dense: true,
            title: Text(
              _timerOn ? l10n.ladderTimerRunning(_elapsed, target) : l10n.ladderTimer(target),
            ),
            value: _timerOn,
            onChanged: _toggleTimer,
          ),
        const SizedBox(height: AppSpacing.sm),
        RichQuestionText(step.stem ?? '', style: theme.textTheme.bodyLarge),
        const SizedBox(height: AppSpacing.sm),
        if (step.takesResponse)
          ResponseAnswer(
            item: _asItem(step),
            locked: result != null,
            onSubmit: (response) async {
              await widget.run.answerResponse(response);
              return true;
            },
          )
        else if (step.typed)
          _NumberAnswer(locked: result != null, onSubmit: widget.run.answerTyped)
        else
          for (final (index, option) in step.options.indexed)
            Card(
              color: result == null
                  ? null
                  : index == result.answerIndex
                  ? theme.colorScheme.primaryContainer
                  : index == result.selectedIndex
                  ? theme.colorScheme.errorContainer
                  : null,
              child: ListTile(
                title: Text(option),
                onTap: result == null ? () => widget.run.answer(index) : null,
              ),
            ),
        if (result != null) ...[
          const SizedBox(height: AppSpacing.sm),
          Text(
            result.correct
                ? l10n.ladderRight
                : result.partlyRight
                ? l10n.ladderPartlyRight
                : l10n.ladderWrong,
            style: theme.textTheme.titleMedium,
          ),
          if (showMarks && result.marks != null && result.marksPossible != null)
            Text(
              l10n.ladderMarks(
                ladderMarksText(result.marks!),
                ladderMarksText(result.marksPossible!),
              ),
            ),
          if (result.answerLines.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(l10n.ladderCorrectAnswer, style: theme.textTheme.labelLarge),
            for (final line in result.answerLines) Text(line),
          ],
          if (result.solution.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(l10n.ladderSolution, style: theme.textTheme.labelLarge),
            for (final (index, line) in result.solution.indexed) Text('${index + 1}. $line'),
          ],
          if (result.shortcut.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(l10n.ladderShortcut, style: theme.textTheme.labelLarge),
            Text(result.shortcut),
          ],
          const SizedBox(height: AppSpacing.md),
          FilledButton(
            onPressed: widget.run.next,
            child: Text(step.step == total ? l10n.ladderSeeResults : l10n.ladderNext),
          ),
        ],
      ],
    );
  }
}

/// Answers a question that takes a number.
class _NumberAnswer extends StatefulWidget {
  const _NumberAnswer({required this.locked, required this.onSubmit});

  final bool locked;
  final Future<void> Function(String text) onSubmit;

  @override
  State<_NumberAnswer> createState() => _NumberAnswerState();
}

class _NumberAnswerState extends State<_NumberAnswer> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    FocusScope.of(context).unfocus();
    unawaited(widget.onSubmit(text));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: AppSpacing.sm,
      children: [
        TextField(
          controller: _controller,
          enabled: !widget.locked,
          maxLength: 100,
          keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _submit(),
          decoration: InputDecoration(labelText: l10n.sessionTypedAnswerLabel),
        ),
        if (!widget.locked)
          FilledButton(onPressed: _submit, child: Text(l10n.sessionTypedAnswerSave)),
      ],
    );
  }
}

class _Results extends ConsumerWidget {
  const _Results({required this.state, required this.run});

  final LadderRunState state;
  final LadderRun run;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final round = state.round!;
    final summary = LadderSummary.of(round);
    final seconds = summary.timeSpent.inSeconds;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.ladderResultsTitle, style: theme.textTheme.titleLarge),
        Text(l10n.ladderScore(summary.correct, summary.total)),
        if (ref.watch(appFeaturesProvider).examProfiles &&
            summary.marks != null &&
            summary.marksPossible != null)
          Text(
            l10n.ladderMarks(
              ladderMarksText(summary.marks!),
              ladderMarksText(summary.marksPossible!),
            ),
          ),
        if (seconds > 0) Text(l10n.ladderTime(seconds ~/ 60, seconds % 60)),
        const SizedBox(height: AppSpacing.sm),
        for (final step in round.steps.reversed)
          ListTile(
            contentPadding: EdgeInsets.zero,
            dense: true,
            leading: Icon(
              step.result?.correct ?? false ? Icons.check_circle : Icons.cancel_outlined,
              color: step.result?.correct ?? false
                  ? ladderStepColors[step.step - 1]
                  : theme.colorScheme.error,
            ),
            title: Text(
              l10n.ladderStepLabel(step.step, ladderDifficultyLabel(l10n, step.difficulty)),
            ),
            subtitle: Text(step.result?.correct ?? false ? l10n.ladderCleared : l10n.ladderMissed),
          ),
        if (summary.byModel.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.sm),
          Text(l10n.ladderByModel, style: theme.textTheme.labelLarge),
          for (final MapEntry(key: name, value: (right, all)) in summary.byModel.entries)
            Text(l10n.ladderModelScore(name, right, all)),
        ],
        const SizedBox(height: AppSpacing.md),
        const _HonestNote(),
        const SizedBox(height: AppSpacing.md),
        FilledButton(onPressed: run.more, child: Text(l10n.ladderMore)),
        TextButton(
          onPressed: () => context.pushReplacement(AppRoutes.ladderTopics),
          child: Text(l10n.ladderAnother),
        ),
      ],
    );
  }
}

class _Failed extends StatelessWidget {
  const _Failed({required this.state, required this.run, required this.topicId});

  final LadderRunState state;
  final LadderRun run;
  final String topicId;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final failure = state.failure;
    return _Unavailable(
      topicId: topicId,
      message: failure is NetworkFailure || failure is TimeoutFailure
          ? l10n.ladderNoConnection
          : failure == null
          ? l10n.ladderNoConnection
          : aiErrorMessage(l10n, failure),
      onRetry: run.retry,
    );
  }
}

/// AI can't help right now: says so and offers real questions from the learner's papers.
class _Unavailable extends ConsumerWidget {
  const _Unavailable({required this.topicId, required this.message, this.onRetry});

  final String topicId;
  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(message),
        const SizedBox(height: AppSpacing.md),
        FilledButton.tonal(
          onPressed: () => startAndOpen(
            context,
            () => ref
                .read(practiceRepositoryProvider)
                .startPractice(
                  PracticeRequest(examCode: ref.read(activeExamProvider), topicId: topicId),
                ),
          ),
          child: Text(l10n.ladderPractiseReal),
        ),
        if (onRetry != null) TextButton(onPressed: onRetry, child: Text(l10n.retry)),
      ],
    );
  }
}
