import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../core/localization/generated/app_localizations.dart';
import '../../ai/data/ai_repository.dart';
import '../../ai/presentation/ai_widgets.dart';
import '../../analytics/presentation/analytics_widgets.dart';
import '../application/learn_providers.dart';
import '../domain/quiz_rules.dart';
import 'learn_widgets.dart';

/// AI questions that check a topic the learner says they know. Marked on the device, one at
/// a time with the explanation; the result says whether to learn the topic first. Nothing is
/// saved and nothing counts toward progress (the questions aren't reviewed).
class TopicQuizScreen extends StatelessWidget {
  const TopicQuizScreen({super.key, required this.choice});

  final TopicChoice choice;

  @override
  Widget build(BuildContext context) => LearnScreenFrame(
    title: AppLocalizations.of(context).learnQuizTitle(choice.topic),
    choice: choice,
    body: (request) => _QuizBody(request: request),
  );
}

class _QuizBody extends ConsumerWidget {
  const _QuizBody({required this.request});

  final LearnRequest request;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    return switch (ref.watch(topicQuizProvider(request))) {
      // A new quiz (new questions) starts the run over.
      AsyncData(:final value) => _QuizRun(
        key: ObjectKey(value),
        quiz: value,
        onAgain: () => ref.invalidate(topicQuizProvider(request)),
      ),
      AsyncError(:final error) => LearnError(
        error: error,
        onRetry: () => ref.invalidate(topicQuizProvider(request)),
      ),
      _ => LearnLoading(l10n.learnQuizLoading),
    };
  }
}

class _QuizRun extends StatefulWidget {
  const _QuizRun({super.key, required this.quiz, required this.onAgain});

  final TopicQuiz quiz;
  final VoidCallback onAgain;

  @override
  State<_QuizRun> createState() => _QuizRunState();
}

class _QuizRunState extends State<_QuizRun> {
  int _index = 0;
  int _correct = 0;

  /// The chosen option (1-based) for the current question, once answered.
  int? _chosen;
  bool _finished = false;

  void _choose(int option) {
    if (_chosen != null) return;
    setState(() {
      _chosen = option;
      if (option == widget.quiz.questions[_index].correctOption) _correct++;
    });
  }

  void _next() => setState(() {
    if (_index + 1 < widget.quiz.questions.length) {
      _index++;
      _chosen = null;
    } else {
      _finished = true;
    }
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final quiz = widget.quiz;
    final note = [
      Align(alignment: Alignment.centerLeft, child: AiLabel(l10n.learnAiLabel)),
      Text(l10n.learnQuizNote, style: theme.textTheme.bodySmall),
      const SizedBox(height: AppSpacing.md),
    ];
    if (_finished) {
      return ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          ...note,
          _Result(quiz: quiz, correct: _correct, onAgain: widget.onAgain),
        ],
      );
    }

    final question = quiz.questions[_index];
    final last = _index + 1 == quiz.questions.length;
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: [
        ...note,
        Wrap(
          spacing: AppSpacing.sm,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              l10n.learnQuizProgress(_index + 1, quiz.questions.length),
              style: theme.textTheme.labelLarge,
            ),
            // Every question carries its own label: it looks like an exam question but isn't one.
            AiLabel(l10n.learnQuizQuestionLabel),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        SelectableText(question.stem, style: theme.textTheme.titleMedium),
        const SizedBox(height: AppSpacing.sm),
        for (var i = 1; i <= question.options.length; i++)
          _OptionTile(
            label: question.options[i - 1],
            letter: String.fromCharCode(64 + i),
            state: switch (_chosen) {
              null => _OptionState.open,
              _ when i == question.correctOption => _OptionState.correct,
              final chosen when chosen == i => _OptionState.wrong,
              _ => _OptionState.other,
            },
            onTap: () => _choose(i),
          ),
        if (_chosen != null) ...[
          const SizedBox(height: AppSpacing.sm),
          Text(
            _chosen == question.correctOption
                ? l10n.learnQuizCorrect
                : l10n.learnQuizWrong(String.fromCharCode(64 + question.correctOption)),
            style: theme.textTheme.titleSmall,
          ),
          const SizedBox(height: AppSpacing.xs),
          SelectableText(question.explanation),
          const SizedBox(height: AppSpacing.xs),
          Text(
            l10n.learnQuizKeyCaveat,
            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: AppSpacing.md),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton(
              onPressed: _next,
              child: Text(last ? l10n.learnQuizFinish : l10n.learnQuizNext),
            ),
          ),
        ],
      ],
    );
  }
}

enum _OptionState { open, correct, wrong, other }

class _OptionTile extends StatelessWidget {
  const _OptionTile({
    required this.label,
    required this.letter,
    required this.state,
    required this.onTap,
  });

  final String label;
  final String letter;
  final _OptionState state;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final (Color? background, IconData? icon) = switch (state) {
      _OptionState.correct => (colors.primaryContainer, Icons.check_circle),
      _OptionState.wrong => (colors.errorContainer, Icons.cancel),
      _ => (null, null),
    };
    return Card(
      color: background,
      child: ListTile(
        leading: CircleAvatar(radius: 14, child: Text(letter)),
        title: Text(label),
        trailing: icon == null ? null : Icon(icon),
        onTap: state == _OptionState.open ? onTap : null,
      ),
    );
  }
}

class _Result extends StatelessWidget {
  const _Result({required this.quiz, required this.correct, required this.onAgain});

  final TopicQuiz quiz;
  final int correct;
  final VoidCallback onAgain;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final total = quiz.questions.length;
    final verdict = quizVerdict(correct, total);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          header: true,
          child: Text(l10n.learnQuizScore(correct, total), style: theme.textTheme.headlineSmall),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(switch (verdict) {
          QuizVerdict.knowsIt => l10n.learnQuizKnowsIt,
          QuizVerdict.partly => l10n.learnQuizPartly,
          QuizVerdict.learnFirst => l10n.learnQuizLearnFirst,
          QuizVerdict.tooFew => l10n.learnQuizTooFew,
        }),
        const SizedBox(height: AppSpacing.xs),
        Text(
          l10n.learnQuizRules(
            formatPercent(context, QuizRules.knowIt),
            formatPercent(context, QuizRules.partly),
            QuizRules.minQuestions,
          ),
          style: theme.textTheme.bodySmall,
        ),
        const SizedBox(height: AppSpacing.md),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            if (verdict == QuizVerdict.knowsIt || verdict == QuizVerdict.tooFew)
              FilledButton(onPressed: onAgain, child: Text(l10n.learnQuizAgain)),
            if (verdict != QuizVerdict.knowsIt)
              FilledButton.icon(
                icon: const Icon(Icons.school_outlined),
                label: Text(l10n.learnQuizLearn),
                onPressed: () => context.pushReplacement(
                  AppRoutes.topicLesson(quiz.topic, subject: quiz.subject),
                ),
              ),
            if (verdict == QuizVerdict.partly || verdict == QuizVerdict.learnFirst)
              OutlinedButton(onPressed: onAgain, child: Text(l10n.learnQuizAgain)),
            TextButton(onPressed: () => context.pop(), child: Text(l10n.learnQuizDone)),
          ],
        ),
      ],
    );
  }
}
