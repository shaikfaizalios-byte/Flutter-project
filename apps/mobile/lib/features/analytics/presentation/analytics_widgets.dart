import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../app/routes.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../core/localization/generated/app_localizations.dart';
import '../../../core/utils/calendar_date.dart';
import '../../practice/application/practice_providers.dart';
import '../../practice/domain/practice_models.dart';
import '../../practice/presentation/practice_hub_screen.dart' show startAndOpen;
import '../domain/study_plan.dart';
import '../domain/weak_topics.dart';

String formatPercent(BuildContext context, double value) =>
    NumberFormat.percentPattern(Localizations.localeOf(context).toLanguageTag()).format(value);

/// One line of evidence for a topic: accuracy over N answers and/or flashcard forgetting.
String topicEvidence(BuildContext context, TopicAssessment topic) {
  final l10n = AppLocalizations.of(context);
  final parts = <String>[
    if (topic.counts.answered > 0)
      l10n.topicAccuracy(formatPercent(context, topic.counts.accuracy!), topic.counts.answered),
    if (topic.reviews > 0) l10n.topicForgotten(topic.forgot, topic.reviews),
  ];
  return parts.join(' · ');
}

String planTitle(AppLocalizations l10n, PlanItem item) => switch (item.kind) {
  PlanItemKind.revision => l10n.planRevisionTitle((item.reason as CardsDue).due),
  PlanItemKind.weakTopic => l10n.planWeakTopicTitle(item.topicName ?? ''),
  PlanItemKind.practiceMixed => l10n.planMixedTitle,
  PlanItemKind.mockTest => l10n.planMockTitle(item.mockName ?? ''),
};

String planReason(BuildContext context, PlanItem item) {
  final l10n = AppLocalizations.of(context);
  return switch (item.reason) {
    CardsDue(:final due, :final overdue) =>
      overdue > 0 ? l10n.reasonCardsDueOverdue(due, overdue) : l10n.reasonCardsDue(due),
    WeakTopicEvidence(:final topic) => [
      topicEvidence(context, topic),
      l10n.reasonBelowThreshold(formatPercent(context, AnalyticsRules.weakAccuracy)),
    ].where((s) => s.isNotEmpty).join(' · '),
    NoPracticeDataYet() => l10n.reasonNoPracticeData,
    NoWeakTopicFound() => l10n.reasonNoWeakTopic(AnalyticsRules.minAnswers),
    MockDue(:final daysSinceLastMock, :final daysToExam) => [
      daysSinceLastMock == null ? l10n.reasonMockNever : l10n.reasonMockSince(daysSinceLastMock),
      if (daysToExam != null) l10n.reasonExamIn(daysToExam),
    ].join(' '),
  };
}

/// A plan item with its reason, estimated time and a button to start it.
class PlanItemTile extends ConsumerWidget {
  const PlanItemTile({super.key, required this.item});

  final PlanItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(switch (item.kind) {
              PlanItemKind.revision => Icons.style_outlined,
              PlanItemKind.weakTopic => Icons.trending_up,
              PlanItemKind.practiceMixed => Icons.quiz_outlined,
              PlanItemKind.mockTest => Icons.timer_outlined,
            }, color: theme.colorScheme.primary),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(planTitle(l10n, item), style: theme.textTheme.titleSmall),
                Text(
                  '${planReason(context, item)} · ${l10n.planMinutes(item.minutes)}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          TextButton(onPressed: () => _start(context, ref), child: Text(l10n.planStart)),
        ],
      ),
    );
  }

  Future<void> _start(BuildContext context, WidgetRef ref) async {
    final practice = ref.read(practiceRepositoryProvider);
    switch (item.kind) {
      case PlanItemKind.revision:
        await context.push(AppRoutes.revisionReview);
      case PlanItemKind.weakTopic:
        await startAndOpen(
          context,
          () => practice.startPractice(
            PracticeRequest(topicId: item.topicId, count: PlanRules.practiceQuestions),
          ),
        );
      case PlanItemKind.practiceMixed:
        await startAndOpen(
          context,
          () => practice.startPractice(const PracticeRequest(count: PlanRules.practiceQuestions)),
        );
      case PlanItemKind.mockTest:
        // The hub shows the mock with its rules and asks for confirmation.
        context.go(AppRoutes.practice);
    }
  }
}

/// Simple daily bar chart (no chart package): one bar per day, labelled for screen readers.
class DailyBars extends StatelessWidget {
  const DailyBars({
    super.key,
    required this.today,
    required this.days,
    required this.values,
    required this.semanticsLabel,
  });

  final CalendarDate today;
  final int days;
  final Map<CalendarDate, int> values;
  final String semanticsLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final locale = Localizations.localeOf(context).toLanguageTag();
    final dates = [for (var i = days - 1; i >= 0; i--) today.addDays(-i)];
    final maxValue = math.max(1, dates.map((d) => values[d] ?? 0).fold(0, math.max));
    final dateFormat = DateFormat.MMMd(locale);
    return Semantics(
      label: semanticsLabel,
      excludeSemantics: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 64,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (final date in dates)
                  Expanded(
                    child: Tooltip(
                      message: '${dateFormat.format(date.toLocalDateTime())}: ${values[date] ?? 0}',
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 1),
                        height: math.max(2, 64 * (values[date] ?? 0) / maxValue),
                        decoration: BoxDecoration(
                          color: (values[date] ?? 0) == 0
                              ? theme.colorScheme.surfaceContainerHighest
                              : theme.colorScheme.primary,
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(2)),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                dateFormat.format(dates.first.toLocalDateTime()),
                style: theme.textTheme.bodySmall,
              ),
              Text(dateFormat.format(today.toLocalDateTime()), style: theme.textTheme.bodySmall),
            ],
          ),
        ],
      ),
    );
  }
}
