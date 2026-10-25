import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../core/localization/generated/app_localizations.dart';
import '../../../core/utils/app_log.dart';
import '../../analytics/application/analytics_providers.dart';
import '../../analytics/domain/study_plan.dart';
import '../../analytics/domain/weak_topics.dart';
import '../../analytics/presentation/analytics_widgets.dart';
import '../../exams/application/active_exam.dart';
import '../../exams/application/exam_catalog_controller.dart';
import '../../exams/data/exams_repository.dart';
import '../../practice/application/practice_providers.dart';
import '../../practice/domain/practice_models.dart';
import '../../practice/presentation/practice_hub_screen.dart';
import '../application/mastery_providers.dart';
import '../domain/mastery.dart';

String masteryLabel(AppLocalizations l10n, MasteryLevel level) => switch (level) {
  MasteryLevel.notStarted => l10n.masteryNotStarted,
  MasteryLevel.learning => l10n.masteryLearning,
  MasteryLevel.practising => l10n.masteryPractising,
  MasteryLevel.strong => l10n.masteryStrong,
  MasteryLevel.mastered => l10n.masteryMastered,
};

/// What the learner can do to reach the next level.
String masteryNextStep(BuildContext context, TopicMastery topic) {
  final l10n = AppLocalizations.of(context);
  return switch (topic.level) {
    MasteryLevel.notStarted => l10n.masteryNextNotStarted,
    MasteryLevel.learning => l10n.masteryNextLearning(topic.answersToJudge),
    MasteryLevel.practising => l10n.masteryNextPractising(
      formatPercent(context, MasteryRules.strongAccuracy),
    ),
    MasteryLevel.strong => l10n.masteryNextStrong(
      MasteryRules.masteredAnswers,
      formatPercent(context, MasteryRules.masteredAccuracy),
    ),
    MasteryLevel.mastered => l10n.masteryNextMastered,
  };
}

/// A topic's level as a small coloured label (calm colours: no level is shown as an error).
class MasteryChip extends StatelessWidget {
  const MasteryChip({super.key, required this.level});

  final MasteryLevel level;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = Theme.of(context).colorScheme;
    final (background, foreground) = switch (level) {
      MasteryLevel.notStarted => (colors.surfaceContainerHighest, colors.onSurfaceVariant),
      MasteryLevel.learning => (colors.secondaryContainer, colors.onSecondaryContainer),
      MasteryLevel.practising => (colors.tertiaryContainer, colors.onTertiaryContainer),
      MasteryLevel.strong => (colors.primaryContainer, colors.onPrimaryContainer),
      MasteryLevel.mastered => (colors.primary, colors.onPrimary),
    };
    return Semantics(
      label: l10n.masteryLevelLabel(masteryLabel(l10n, level)),
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 2),
        decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(12)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              level == MasteryLevel.mastered ? Icons.workspace_premium : Icons.signal_cellular_alt,
              size: 14,
              color: foreground,
            ),
            const SizedBox(width: 4),
            Text(
              masteryLabel(l10n, level),
              style: Theme.of(context).textTheme.labelSmall?.copyWith(color: foreground),
            ),
          ],
        ),
      ),
    );
  }
}

/// Four steps that fill up as a topic moves from learning to mastered.
class MasteryMeter extends StatelessWidget {
  const MasteryMeter({super.key, required this.level});

  final MasteryLevel level;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return ExcludeSemantics(
      child: Row(
        children: [
          for (var step = 1; step < MasteryLevel.values.length; step++) ...[
            if (step > 1) const SizedBox(width: 4),
            Expanded(
              child: Container(
                height: 6,
                decoration: BoxDecoration(
                  color: step <= level.index ? colors.primary : colors.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// How the levels are decided (shown so learners can trust them).
class MasteryRulesNote extends ConsumerWidget {
  const MasteryRulesNote({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final style = Theme.of(context).textTheme.bodySmall
        ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant);
    final offline = ref.watch(practiceAnalyticsProvider).hasError;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (offline) Text(l10n.masteryOffline, style: style),
        Text(
          l10n.masteryRules(
            AnalyticsRules.windowDays,
            MasteryRules.minAnswers,
            formatPercent(context, MasteryRules.strongAccuracy),
            MasteryRules.masteredAnswers,
            formatPercent(context, MasteryRules.masteredAccuracy),
          ),
          style: style,
        ),
      ],
    );
  }
}

/// The current exam's subjects with how many topics are strong; tapping one opens it.
class SyllabusOverviewCard extends ConsumerWidget {
  const SyllabusOverviewCard({super.key, required this.onSubject});

  final ValueChanged<String> onSubject;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final exam = ref.watch(activeExamProvider);
    final subjects = ref.watch(examMasteryProvider).value;
    if (subjects == null) return const SizedBox.shrink();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.account_tree_outlined, color: theme.colorScheme.primary),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Semantics(
                    header: true,
                    child: Text(l10n.masterySyllabusTitle, style: theme.textTheme.titleMedium),
                  ),
                ),
                if (exam != null)
                  TextButton(
                    onPressed: () => context.push(AppRoutes.examTopics(exam)),
                    child: Text(
                      subjects.isEmpty ? l10n.masteryAddSyllabus : l10n.masteryEditSyllabus,
                    ),
                  ),
              ],
            ),
            if (subjects.isEmpty)
              Text(l10n.masteryNoSyllabus, style: theme.textTheme.bodyMedium)
            else ...[
              for (final subject in subjects)
                InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: () => onSubject(subject.name),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(child: Text(subject.name, style: theme.textTheme.titleSmall)),
                            Text(
                              l10n.masterySubjectProgress(
                                subject.strongOrBetter,
                                subject.topics.length,
                              ),
                              style: theme.textTheme.bodySmall,
                            ),
                            const Icon(Icons.chevron_right),
                          ],
                        ),
                        const SizedBox(height: 4),
                        _LevelBar(counts: subject.levelCounts),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: AppSpacing.sm),
              const MasteryRulesNote(),
            ],
          ],
        ),
      ),
    );
  }
}

/// Topics of a subject at each level, as one stacked bar.
class _LevelBar extends StatelessWidget {
  const _LevelBar({required this.counts});

  final List<int> counts;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final fill = [
      colors.surfaceContainerHighest,
      colors.secondary.withValues(alpha: 0.45),
      colors.tertiary.withValues(alpha: 0.6),
      colors.primary.withValues(alpha: 0.65),
      colors.primary,
    ];
    return ExcludeSemantics(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: SizedBox(
          height: 8,
          child: Row(
            children: [
              for (var i = 0; i < counts.length; i++)
                if (counts[i] > 0)
                  Expanded(
                    flex: counts[i],
                    child: ColoredBox(color: fill[i]),
                  ),
            ],
          ),
        ),
      ),
    );
  }
}

SubjectMastery? _subjectNamed(List<SubjectMastery> subjects, String name) =>
    subjects.where((s) => s.name.toLowerCase() == name.trim().toLowerCase()).firstOrNull;

/// One subject's topics with their levels; tapping a topic opens it.
class SubjectMasteryCard extends ConsumerWidget {
  const SubjectMasteryCard({super.key, required this.subject, required this.onTopic});

  final String subject;
  final ValueChanged<String> onTopic;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final subjects = ref.watch(examMasteryProvider).value;
    final mastery = subjects == null ? null : _subjectNamed(subjects, subject);
    if (mastery == null) return const SizedBox.shrink();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Semantics(header: true, child: Text(mastery.name, style: theme.textTheme.titleMedium)),
            const SizedBox(height: 4),
            Text(
              l10n.masterySubjectProgress(mastery.strongOrBetter, mastery.topics.length),
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: AppSpacing.sm),
            _LevelBar(counts: mastery.levelCounts),
            const SizedBox(height: AppSpacing.sm),
            for (final topic in mastery.topics)
              InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () => onTopic(topic.name),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                  child: Row(
                    children: [
                      Expanded(child: Text(topic.name)),
                      const SizedBox(width: AppSpacing.sm),
                      MasteryChip(level: topic.level),
                      const Icon(Icons.chevron_right),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: AppSpacing.sm),
            const MasteryRulesNote(),
          ],
        ),
      ),
    );
  }
}

/// One topic: its level, the evidence, the next step and ways to work on it.
class TopicMasteryCard extends ConsumerStatefulWidget {
  const TopicMasteryCard({super.key, required this.topic, this.subject});

  final String topic;

  /// Narrows the lookup when two subjects have a topic of the same name.
  final String? subject;

  @override
  ConsumerState<TopicMasteryCard> createState() => _TopicMasteryCardState();
}

class _TopicMasteryCardState extends ConsumerState<TopicMasteryCard> {
  bool _busy = false;

  TopicMastery? _find(List<SubjectMastery> subjects) {
    final name = widget.topic.trim().toLowerCase();
    for (final s in subjects) {
      if (widget.subject != null && s.name.toLowerCase() != widget.subject!.trim().toLowerCase()) {
        continue;
      }
      for (final t in s.topics) {
        if (t.name.toLowerCase() == name) return t;
      }
    }
    return null;
  }

  Future<void> _setRevised(TopicMastery topic, String exam, bool revised) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      await ref.read(examsRepositoryProvider).setCompleted(topic.topicId!, completed: revised);
      ref.invalidate(examTopicsProvider(exam));
    } on Object catch (error, stack) {
      logError('Marking a topic revised failed', error, stack);
      messenger.showSnackBar(SnackBar(content: Text(l10n.masteryUpdateFailed)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final exam = ref.watch(activeExamProvider);
    final subjects = ref.watch(examMasteryProvider).value;
    final topic = subjects == null ? null : _find(subjects);
    if (topic == null) return const SizedBox.shrink();
    final evidence = [
      if (topic.counts.accuracy case final accuracy?)
        l10n.topicAccuracy(formatPercent(context, accuracy), topic.counts.answered)
      else
        l10n.masteryNoAnswers(AnalyticsRules.windowDays),
      if (topic.reviews > 0) l10n.topicForgotten(topic.forgot, topic.reviews),
    ];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Semantics(
                    header: true,
                    child: Text(topic.name, style: theme.textTheme.titleMedium),
                  ),
                ),
                MasteryChip(level: topic.level),
              ],
            ),
            Text(topic.subject, style: theme.textTheme.bodySmall),
            const SizedBox(height: AppSpacing.sm),
            MasteryMeter(level: topic.level),
            const SizedBox(height: AppSpacing.sm),
            Text(evidence.join(' · '), style: theme.textTheme.bodySmall),
            const SizedBox(height: 4),
            Text(masteryNextStep(context, topic), style: theme.textTheme.bodyMedium),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                if (topic.topicId != null)
                  FilledButton.tonalIcon(
                    icon: const Icon(Icons.quiz_outlined),
                    label: Text(l10n.masteryPractise),
                    onPressed: () => startAndOpen(
                      context,
                      () => ref
                          .read(practiceRepositoryProvider)
                          .startPractice(
                            PracticeRequest(
                              examCode: exam,
                              topicId: topic.topicId,
                              count: PlanRules.practiceQuestions,
                            ),
                          ),
                    ),
                  ),
                OutlinedButton.icon(
                  icon: const Icon(Icons.add),
                  label: Text(l10n.masteryAddConcept),
                  onPressed: () => context.push(AppRoutes.newConceptIn(topic.subject, topic.name)),
                ),
                if (topic.topicId != null && exam != null)
                  FilterChip(
                    label: Text(l10n.topicRevised),
                    selected: topic.revised,
                    onSelected: _busy ? null : (on) => _setRevised(topic, exam, on),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
