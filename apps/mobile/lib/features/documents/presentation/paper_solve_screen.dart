import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/localization/generated/app_localizations.dart';
import '../../../core/utils/app_log.dart';
import '../../../core/widgets/empty_state.dart';
import '../../ai/application/ai_providers.dart';
import '../../ai/data/ai_repository.dart';
import '../../ai/presentation/ai_widgets.dart';
import '../../question_bank/domain/question.dart';
import '../../question_bank/presentation/figure_view.dart';
import '../application/paper_providers.dart';
import '../domain/paper_solve.dart';

/// Solving a paper: its questions only, one at a time. Multiple-choice questions show their
/// options; the rest get a box to type the answer, compared with the paper's answer, or (for
/// written answers) checked by AI together with the paper's answer. Marked on the device;
/// nothing is saved and it doesn't count as practice.
class PaperSolveScreen extends ConsumerWidget {
  const PaperSolveScreen({super.key, required this.documentId, required this.name});

  final String documentId;
  final String name;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final Widget body = switch (ref.watch(paperQuestionsProvider(documentId))) {
      AsyncData(value: final questions) when questions.isEmpty => EmptyState(
        icon: Icons.quiz_outlined,
        title: l10n.paperSolveEmpty,
      ),
      AsyncData(value: final questions) => _SolveRun(questions: questions),
      AsyncError(:final error) => EmptyState(
        icon: Icons.cloud_off_outlined,
        title: aiErrorMessage(l10n, error),
        action: FilledButton(
          onPressed: () => ref.invalidate(paperQuestionsProvider(documentId)),
          child: Text(l10n.retry),
        ),
      ),
      _ => const Center(child: CircularProgressIndicator()),
    };
    return Scaffold(
      appBar: AppBar(title: Text(l10n.paperSolveTitle(name))),
      body: body,
    );
  }
}

class _SolveRun extends StatefulWidget {
  const _SolveRun({required this.questions});

  final List<BankQuestion> questions;

  @override
  State<_SolveRun> createState() => _SolveRunState();
}

class _SolveRunState extends State<_SolveRun> {
  int _index = 0;

  /// Questions opened so far, in the order first opened. They stay built (hidden), so an
  /// answered question still shows its answer when the learner comes back to it.
  final _opened = <int>[0];

  /// Result per question id once answered: true right, false wrong, null not marked.
  final _results = <String, bool?>{};

  void _record(String id, bool? correct) => setState(() => _results[id] = correct);

  void _go(int index) => setState(() {
    _index = index;
    if (!_opened.contains(index)) _opened.add(index);
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final total = widget.questions.length;
    final correct = _results.values.where((r) => r == true).length;
    // Answers that couldn't be marked (no answer key) are not counted as wrong.
    final marked = _results.values.where((r) => r != null).length;
    final unmarked = _results.length - marked;

    return Column(
      children: [
        Expanded(
          child: IndexedStack(
            index: _opened.indexOf(_index),
            children: [
              for (final i in _opened)
                KeyedSubtree(
                  key: ValueKey(widget.questions[i].id),
                  child: _QuestionView(
                    question: widget.questions[i],
                    header: [
                      l10n.paperSolveProgress(i + 1, total),
                      if (widget.questions[i].sourceNumber != null)
                        l10n.paperSolveNumber(widget.questions[i].sourceNumber!),
                      l10n.paperSolveScore(correct, marked),
                      if (unmarked > 0) l10n.paperSolveUnmarked(unmarked),
                    ],
                    answered: _results.containsKey(widget.questions[i].id),
                    onResult: (r) => _record(widget.questions[i].id, r),
                  ),
                ),
            ],
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Row(
              children: [
                OutlinedButton(
                  onPressed: _index == 0 ? null : () => _go(_index - 1),
                  child: Text(l10n.sessionPrevious),
                ),
                const Spacer(),
                FilledButton(
                  onPressed: _index + 1 == total ? null : () => _go(_index + 1),
                  child: Text(l10n.sessionNext),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// One question: where it is in the paper, its text and figures, and the way to answer it.
class _QuestionView extends StatelessWidget {
  const _QuestionView({
    required this.question,
    required this.header,
    required this.answered,
    required this.onResult,
  });

  final BankQuestion question;

  /// Position first, then the paper's number and the score.
  final List<String> header;
  final bool answered;
  final ValueChanged<bool?> onResult;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant);
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: AppSpacing.maxContentWidth),
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.md),
          children: [
            Wrap(
              spacing: AppSpacing.sm,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(header.first, style: theme.textTheme.labelLarge),
                for (final part in header.skip(1)) Text(part, style: muted),
              ],
            ),
            if (question.status != VerificationStatus.verified) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(l10n.paperSolveUnreviewed, style: muted),
            ],
            if (question.passage != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Card(
                margin: EdgeInsets.zero,
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: SelectableText(question.passage!.text),
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.md),
            SelectableText(question.stem, style: theme.textTheme.titleMedium),
            QuestionFigures(questionId: question.id, figures: question.figures),
            const SizedBox(height: AppSpacing.md),
            switch (solveKind(question)) {
              SolveKind.choice => _ChoicePanel(question: question, onResult: onResult),
              SolveKind.typed => _TypedPanel(question: question, onResult: onResult),
              SolveKind.written => _WrittenPanel(question: question, onResult: onResult),
              // Its options weren't read from the PDF: nothing to pick from yet.
              SolveKind.unreadable => Text(l10n.paperSolveNoOptions),
            },
            if (answered && question.explanation != null) ...[
              const SizedBox(height: AppSpacing.md),
              Text(l10n.paperSolveExplanation, style: theme.textTheme.titleSmall),
              SelectableText(question.explanation!),
            ],
          ],
        ),
      ),
    );
  }
}

/// Multiple choice: tap an option; the paper's answer key marks it.
class _ChoicePanel extends ConsumerStatefulWidget {
  const _ChoicePanel({required this.question, required this.onResult});

  final BankQuestion question;
  final ValueChanged<bool?> onResult;

  @override
  ConsumerState<_ChoicePanel> createState() => _ChoicePanelState();
}

class _ChoicePanelState extends ConsumerState<_ChoicePanel> {
  int? _chosen;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final question = widget.question;
    final correct = question.correctPosition;
    final chosen = _chosen;
    final colors = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final option in question.options)
          Card(
            color: switch ((chosen, correct)) {
              (null, _) => null,
              (_, final c?) when option.position == c => colors.primaryContainer,
              (final c, _) when option.position == c => colors.errorContainer,
              _ => null,
            },
            child: ListTile(
              leading: Text(
                '(${option.label})',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              title: switch (optionFigure(question.figures, option.position)) {
                final f? => Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (option.text.isNotEmpty) Text(option.text),
                    QuestionFigureView(questionId: question.id, figure: f, zoomable: false),
                  ],
                ),
                null => Text(option.text),
              },
              trailing: chosen == option.position ? const Icon(Icons.radio_button_checked) : null,
              onTap: chosen != null
                  ? null
                  : () {
                      setState(() => _chosen = option.position);
                      widget.onResult(choiceCorrect(question, option.position));
                    },
            ),
          ),
        if (chosen != null) ...[
          const SizedBox(height: AppSpacing.sm),
          if (correct == null) ...[
            Text(l10n.paperSolveNoKey),
            _AiChecker(
              questionId: question.id,
              hasFigure: hasFigure(question),
              answer: () => _optionText(question, chosen),
              onResult: widget.onResult,
            ),
          ] else
            Text(
              chosen == correct
                  ? l10n.paperSolveCorrect
                  : l10n.paperSolveWrong(_optionLabel(question, correct)),
              style: Theme.of(context).textTheme.titleSmall,
            ),
        ],
      ],
    );
  }
}

String _optionLabel(BankQuestion question, int position) =>
    question.options.where((o) => o.position == position).firstOrNull?.label ?? '$position';

String _optionText(BankQuestion question, int position) {
  final option = question.options.where((o) => o.position == position).firstOrNull;
  return option == null ? '$position' : '(${option.label}) ${option.text}';
}

/// A short typed-in answer, compared with the paper's (numbers by value).
class _TypedPanel extends StatefulWidget {
  const _TypedPanel({required this.question, required this.onResult});

  final BankQuestion question;
  final ValueChanged<bool?> onResult;

  @override
  State<_TypedPanel> createState() => _TypedPanelState();
}

class _TypedPanelState extends State<_TypedPanel> {
  final _answer = TextEditingController();
  bool? _correct;
  bool _checked = false;

  @override
  void dispose() {
    _answer.dispose();
    super.dispose();
  }

  void _check() {
    if (_answer.text.trim().isEmpty) return;
    FocusScope.of(context).unfocus();
    final correct = typedCorrect(widget.question, _answer.text);
    setState(() {
      _checked = true;
      _correct = correct;
    });
    widget.onResult(correct);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final expected = widget.question.typedAnswer;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: AppSpacing.sm,
      children: [
        TextField(
          controller: _answer,
          enabled: !_checked,
          maxLength: 100,
          keyboardType: widget.question.typedAnswerNumeric
              ? const TextInputType.numberWithOptions(decimal: true, signed: true)
              : TextInputType.text,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _check(),
          decoration: InputDecoration(labelText: l10n.paperSolveTypeAnswer),
        ),
        if (!_checked)
          FilledButton(onPressed: _check, child: Text(l10n.paperSolveCheck))
        else if (expected == null) ...[
          Text(l10n.paperSolveNoKey),
          _AiChecker(
            questionId: widget.question.id,
            hasFigure: hasFigure(widget.question),
            answer: () => _answer.text,
            onResult: widget.onResult,
          ),
        ] else
          Text(
            _correct == true ? l10n.paperSolveCorrect : l10n.paperSolveTypedWrong(expected),
            style: Theme.of(context).textTheme.titleSmall,
          ),
      ],
    );
  }
}

/// A written answer in the learner's own words: checked by AI (with the paper's answer), or
/// compared by the learner with the answer printed in the paper.
class _WrittenPanel extends StatefulWidget {
  const _WrittenPanel({required this.question, required this.onResult});

  final BankQuestion question;
  final ValueChanged<bool?> onResult;

  @override
  State<_WrittenPanel> createState() => _WrittenPanelState();
}

class _WrittenPanelState extends State<_WrittenPanel> {
  final _answer = TextEditingController();
  bool _paperShown = false;

  @override
  void dispose() {
    _answer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final paperAnswer = widget.question.modelAnswer;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: AppSpacing.sm,
      children: [
        TextField(
          controller: _answer,
          minLines: 3,
          maxLines: 10,
          maxLength: 4000,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            labelText: l10n.paperSolveTypeAnswer,
            alignLabelWithHint: true,
            border: const OutlineInputBorder(),
          ),
        ),
        _AiChecker(
          questionId: widget.question.id,
          hasFigure: hasFigure(widget.question),
          answer: () => _answer.text,
          enabled: _answer.text.trim().isNotEmpty,
          onResult: widget.onResult,
        ),
        if (paperAnswer != null)
          if (_paperShown)
            _PaperAnswer(text: paperAnswer)
          else
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: () => setState(() => _paperShown = true),
                child: Text(l10n.paperSolveShowPaperAnswer),
              ),
            )
        else
          Text(
            l10n.paperSolveNoKey,
            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
      ],
    );
  }
}

class _PaperAnswer extends StatelessWidget {
  const _PaperAnswer({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppSpacing.sm),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            AppLocalizations.of(context).paperSolvePaperAnswer,
            style: theme.textTheme.titleSmall,
          ),
          const SizedBox(height: AppSpacing.xs),
          SelectableText(text),
        ],
      ),
    );
  }
}

/// "Check with AI": sends the answer, then shows the AI's verdict, a good answer and how it
/// compares with the paper's. Shown only when the server has AI and this account may use it.
class _AiChecker extends ConsumerStatefulWidget {
  const _AiChecker({
    required this.questionId,
    required this.answer,
    required this.onResult,
    this.enabled = true,
    this.hasFigure = false,
  });

  final String questionId;

  /// The question depends on a figure the AI can't see, so it can't check the answer.
  final bool hasFigure;
  final String Function() answer;
  final ValueChanged<bool?> onResult;
  final bool enabled;

  @override
  ConsumerState<_AiChecker> createState() => _AiCheckerState();
}

class _AiCheckerState extends ConsumerState<_AiChecker> {
  bool _busy = false;
  AnswerCheck? _check;
  Object? _error;

  Future<void> _run() async {
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final check = await ref
          .read(aiRepositoryProvider)
          .checkAnswer(widget.questionId, widget.answer().trim());
      if (!mounted) return;
      setState(() => _check = check);
      widget.onResult(check.verdict == AnswerVerdict.correct);
    } on Object catch (error, stack) {
      if (error is! AppFailure) logError('Checking an answer with AI failed', error, stack);
      if (mounted) setState(() => _error = error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final status = ref.watch(aiStatusProvider).value;
    if (!(status?.enabled ?? false) || status!.needsPlus) return const SizedBox.shrink();
    if (widget.hasFigure) {
      return Text(
        l10n.paperSolveAiNoFigures,
        style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
      );
    }
    final check = _check;
    if (check == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_busy)
            Row(
              children: [
                const SizedBox.square(
                  dimension: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                const SizedBox(width: AppSpacing.sm),
                Text(l10n.paperSolveCheckingAi),
              ],
            )
          else
            FilledButton.tonalIcon(
              icon: const Icon(Icons.auto_awesome),
              label: Text(l10n.paperSolveCheckAi),
              onPressed: widget.enabled ? _run : null,
            ),
          if (_error != null)
            Text(
              aiErrorMessage(l10n, _error!),
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error),
            ),
        ],
      );
    }
    final muted = theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: AppSpacing.xs,
      children: [
        AiLabel(l10n.learnAiLabel),
        Text(switch (check.verdict) {
          AnswerVerdict.correct => l10n.paperSolveVerdictCorrect,
          AnswerVerdict.partly => l10n.paperSolveVerdictPartly,
          AnswerVerdict.incorrect => l10n.paperSolveVerdictIncorrect,
        }, style: theme.textTheme.titleSmall),
        SelectableText(check.feedback),
        if (!check.confident) Text(l10n.paperSolveNotConfident, style: muted),
        const SizedBox(height: AppSpacing.xs),
        Text(l10n.paperSolveIdeal, style: theme.textTheme.titleSmall),
        SelectableText(check.idealAnswer),
        if (check.paperAnswer != null) ...[
          const SizedBox(height: AppSpacing.xs),
          _PaperAnswer(text: check.paperAnswer!),
          Text(
            check.paperAgrees == true ? l10n.paperSolvePaperAgrees : l10n.paperSolvePaperDiffers,
            style: muted,
          ),
        ],
        Text(l10n.paperSolveAiCaution(check.model), style: muted),
      ],
    );
  }
}
