import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../core/widgets/adaptive_action.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../core/localization/generated/app_localizations.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/section_card.dart';
import '../../revision/application/revision_providers.dart';
import '../../study_plan/presentation/study_profile_widgets.dart';
import '../application/analytics_providers.dart';
import '../domain/analytics_models.dart';
import '../domain/weak_topics.dart';
import 'analytics_widgets.dart';

/// Progress tab: only recorded data — practice answers (server) and flashcard reviews
/// (device). Every judgement states the data it is based on.
class ProgressScreen extends ConsumerWidget {
  const ProgressScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final practice = ref.watch(practiceAnalyticsProvider);
    final revision = ref.watch(revisionStatsProvider);
    final insights = ref.watch(topicInsightsProvider);

    final Widget body;
    if (revision.isLoading || practice.isLoading) {
      body = const Center(child: CircularProgressIndicator());
    } else if (practice.value?.total.answered == 0 &&
        (revision.value?.reviews ?? 0) == 0 &&
        (practice.value?.mocks.isEmpty ?? true)) {
      body = EmptyState(
        icon: Icons.show_chart,
        title: l10n.progressEmptyTitle,
        message: l10n.progressEmptyMessage,
      );
    } else {
      body = RefreshIndicator(
        onRefresh: () => ref.refresh(practiceAnalyticsProvider.future),
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: AppSpacing.maxContentWidth),
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(AppSpacing.md),
              children: [
                switch (practice) {
                  AsyncData(:final value) => _PracticeSections(stats: value),
                  _ => Card(
                    child: ListTile(
                      leading: const Icon(Icons.cloud_off),
                      title: Text(l10n.progressOffline),
                      trailing: TextButton(
                        onPressed: () => ref.invalidate(practiceAnalyticsProvider),
                        child: Text(l10n.retry),
                      ),
                    ),
                  ),
                },
                const SizedBox(height: AppSpacing.md),
                if (insights case AsyncData(:final value)) _TopicsCard(insights: value),
                const SizedBox(height: AppSpacing.md),
                if (revision case AsyncData(:final value)) _RevisionCard(stats: value),
                const SizedBox(height: AppSpacing.md),
                MutedLine(
                  l10n.progressRules(
                    formatPercent(context, AnalyticsRules.weakAccuracy),
                    AnalyticsRules.minAnswers,
                    formatPercent(context, AnalyticsRules.weakForgetRate),
                    AnalyticsRules.minReviews,
                    AnalyticsRules.recentDays,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.progressTitle),
        actions: [
          AdaptiveAction(
            label: l10n.weeklyTitle,
            icon: Icons.event_note_outlined,
            onPressed: () => context.push(AppRoutes.weeklyReview),
          ),
        ],
      ),
      body: body,
    );
  }
}

class _PracticeSections extends StatelessWidget {
  const _PracticeSections({required this.stats});

  final PracticeAnalytics stats;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final accuracy = stats.total.accuracy;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionCard(
          icon: Icons.insights_outlined,
          title: l10n.progressSummaryTitle,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l10n.progressAnswered(stats.total.answered), style: theme.textTheme.titleLarge),
              if (accuracy != null) Text(l10n.progressAccuracy(formatPercent(context, accuracy))),
              Text(l10n.progressSessions(stats.sessions)),
              const SizedBox(height: AppSpacing.md),
              Text(l10n.progressDailyTitle(stats.days), style: theme.textTheme.labelLarge),
              const SizedBox(height: AppSpacing.xs),
              DailyBars(
                today: stats.today,
                days: stats.days,
                values: {for (final d in stats.daily) d.date: d.answered},
                semanticsLabel: l10n.progressChartSummary(
                  stats.daily.fold(0, (sum, d) => sum + d.answered),
                  stats.days,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        SectionCard(
          icon: Icons.category_outlined,
          title: l10n.progressSubjectsTitle,
          child: stats.subjects.isEmpty
              ? MutedLine(l10n.progressNoAnswers)
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [for (final s in stats.subjects) _SubjectRow(subject: s)],
                ),
        ),
        const SizedBox(height: AppSpacing.md),
        SectionCard(
          icon: Icons.timer_outlined,
          title: l10n.progressMocksTitle,
          child: stats.mocks.isEmpty
              ? MutedLine(l10n.progressMocksEmpty)
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final mock in stats.mocks)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(mock.name ?? l10n.historyPractice),
                        subtitle: Text(
                          [
                            formatCalendarDate(context, mock.localDate),
                            if (mock.timeUp) l10n.progressMockTimeUp,
                            ?mock.markingNote,
                          ].join(' · '),
                        ),
                        trailing: Text(
                          l10n.progressMockScore(
                            mock.score.toStringAsFixed(2),
                            mock.maxScore.toStringAsFixed(2),
                          ),
                          style: theme.textTheme.titleSmall,
                        ),
                      ),
                  ],
                ),
        ),
      ],
    );
  }
}

class _SubjectRow extends StatelessWidget {
  const _SubjectRow({required this.subject});

  final SubjectStats subject;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final counts = subject.counts;
    final enough = counts.answered >= AnalyticsRules.minAnswers;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(subject.name),
          const SizedBox(height: 2),
          LinearProgressIndicator(value: enough ? counts.accuracy : 0),
          const SizedBox(height: 2),
          MutedLine(
            enough
                ? l10n.progressSubjectRow(formatPercent(context, counts.accuracy!), counts.answered)
                : l10n.progressNotEnough(counts.answered, AnalyticsRules.minAnswers),
          ),
        ],
      ),
    );
  }
}

class _TopicsCard extends StatelessWidget {
  const _TopicsCard({required this.insights});

  final TopicInsights insights;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final judged = [
      for (final t in insights.topics)
        if (t.hasEnoughData) t,
    ];
    final waiting = insights.topics.length - judged.length;
    return SectionCard(
      icon: Icons.trending_up,
      title: l10n.progressTopicsTitle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (insights.topics.isEmpty) MutedLine(l10n.progressTopicsEmpty),
          for (final topic in judged)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text('${topic.name} · ${topic.subject}'),
              subtitle: Text(
                [
                  topicEvidence(context, topic),
                  if (topic.trend != null) _trendLabel(l10n, topic.trend!),
                ].join(' · '),
              ),
              trailing: topic.isWeak
                  ? Chip(label: Text(l10n.progressWeakBadge), visualDensity: VisualDensity.compact)
                  : null,
            ),
          if (waiting > 0) MutedLine(l10n.progressNeedsData(waiting)),
        ],
      ),
    );
  }

  static String _trendLabel(AppLocalizations l10n, Trend trend) => switch (trend) {
    Trend.improving => l10n.progressTrendImproving,
    Trend.steady => l10n.progressTrendSteady,
    Trend.declining => l10n.progressTrendDeclining,
  };
}

class _RevisionCard extends ConsumerWidget {
  const _RevisionCard({required this.stats});

  final RevisionStats stats;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    const days = AnalyticsRules.windowDays;
    return SectionCard(
      icon: Icons.style_outlined,
      title: l10n.progressRevisionTitle,
      child: stats.reviews == 0
          ? MutedLine(l10n.progressRevisionEmpty(days))
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(l10n.progressRevisionSummary(stats.reviews, stats.forgot, days)),
                const SizedBox(height: AppSpacing.sm),
                DailyBars(
                  today: ref.watch(todayProvider),
                  days: days,
                  values: stats.daily,
                  semanticsLabel: l10n.progressChartSummary(stats.reviews, days),
                ),
              ],
            ),
    );
  }
}

/// Muted helper text line.
class MutedLine extends StatelessWidget {
  const MutedLine(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text(
      text,
      style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
    );
  }
}
