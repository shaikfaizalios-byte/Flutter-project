import 'package:flutter/material.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../core/localization/generated/app_localizations.dart';
import '../../../core/widgets/section_card.dart';
import '../domain/practice_models.dart';
import 'session_screen.dart' show formatClock;

/// Submitted session: score, how it was computed, section/topic breakdown, and every
/// question with the learner's answer, the correct one and the explanation.
class ResultView extends StatelessWidget {
  const ResultView({super.key, required this.session});

  final PracticeSessionView session;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final result = session.result;
    if (result == null) return const SizedBox.shrink();
    final total = result.total;

    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: AppSpacing.maxContentWidth),
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.md),
          children: [
            Text(
              l10n.resultScore(_fmt(total.score), _fmt(total.maxScore)),
              style: theme.textTheme.headlineMedium,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(l10n.resultCounts(total.correct, total.wrong, total.unattempted)),
            Text(
              total.accuracy == null
                  ? l10n.resultAccuracyNone
                  : l10n.resultAccuracy((total.accuracy! * 100).round()),
            ),
            Text(l10n.resultTime(formatClock(result.timeTakenSeconds))),
            if (session.submitReason == 'time_up') Text(l10n.resultSubmittedTimeUp),
            const SizedBox(height: AppSpacing.md),
            SectionCard(
              icon: Icons.calculate_outlined,
              title: l10n.resultHowScored,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(result.markingNote, style: theme.textTheme.bodySmall),
                  const SizedBox(height: AppSpacing.xs),
                  SelectableText(total.explanation),
                ],
              ),
            ),
            if (result.sections.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.md),
              _TallyCard(
                icon: Icons.view_list,
                title: l10n.resultSections,
                tallies: result.sections,
              ),
            ],
            if (result.topics.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.md),
              _TallyCard(
                icon: Icons.topic_outlined,
                title: l10n.resultTopics,
                tallies: result.topics,
              ),
            ],
            const SizedBox(height: AppSpacing.md),
            Text(l10n.resultReviewAnswers, style: theme.textTheme.titleMedium),
            for (final item in session.items) _AnswerReview(item: item),
          ],
        ),
      ),
    );
  }
}

class _TallyCard extends StatelessWidget {
  const _TallyCard({required this.icon, required this.title, required this.tallies});

  final IconData icon;
  final String title;
  final List<TallyView> tallies;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      icon: icon,
      title: title,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final t in tallies) ...[
            Text(
              '${t.name}: ${_fmt(t.score)} / ${_fmt(t.maxScore)}',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            Text(t.explanation, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: AppSpacing.sm),
          ],
        ],
      ),
    );
  }
}

class _AnswerReview extends StatelessWidget {
  const _AnswerReview({required this.item});

  final SessionItemView item;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = Theme.of(context).colorScheme;
    final feedback = item.feedback;
    String labelOf(int? position) =>
        item.options.where((o) => o.position == position).firstOrNull?.label ?? '${position ?? ''}';
    final (icon, color) = switch (feedback?.isCorrect) {
      true => (Icons.check_circle, colors.primary),
      false => (Icons.cancel, colors.error),
      null => (Icons.remove_circle_outline, colors.outline),
    };
    return ExpansionTile(
      tilePadding: EdgeInsets.zero,
      leading: Icon(icon, color: color),
      title: Text(
        '${item.position}. ${item.stem ?? l10n.sessionQuestionRemoved}',
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        item.isTyped
            ? (item.typedAnswer == null
                  ? l10n.resultNotAnswered
                  : l10n.resultYourTypedAnswer(item.typedAnswer!))
            : item.selectedPosition == null
            ? l10n.resultNotAnswered
            : l10n.resultYourAnswer(labelOf(item.selectedPosition)),
      ),
      children: [
        if (feedback != null)
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final o in item.options) Text('(${o.label}) ${o.text}'),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  feedback.correctTypedAnswer != null
                      ? l10n.sessionCorrectTypedAnswer(feedback.correctTypedAnswer!)
                      : l10n.sessionCorrectAnswer(labelOf(feedback.correctPosition)),
                ),
                if (feedback.explanation != null) SelectableText(feedback.explanation!),
                const SizedBox(height: AppSpacing.sm),
              ],
            ),
          ),
      ],
    );
  }
}

String _fmt(double value) =>
    value == value.roundToDouble() ? value.toStringAsFixed(0) : value.toStringAsFixed(2);
