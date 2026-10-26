import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_destinations.dart';
import '../../../app/routes.dart';
import '../../../app/theme/app_spacing.dart';
import '../../exams/application/exam_catalog_controller.dart';
import '../../../core/localization/generated/app_localizations.dart';
import '../../../core/utils/calendar_date.dart';
import '../../../core/utils/clock.dart';
import '../../../core/widgets/section_card.dart';
import '../../analytics/application/analytics_providers.dart';
import '../../analytics/domain/weak_topics.dart';
import '../../analytics/presentation/analytics_widgets.dart';
import '../../concepts/application/concepts_providers.dart';
import '../../revision/application/revision_providers.dart';
import '../../revision/domain/revision_card.dart';
import '../../revision/presentation/revision_widgets.dart';
import '../../study_plan/application/study_profile_controller.dart';
import '../../study_plan/domain/study_profile.dart';
import '../../study_plan/presentation/study_profile_widgets.dart';
import '../../exams/presentation/exam_switcher.dart';
import '../../exams/application/active_exam.dart';
import '../../focus/presentation/focus_widgets.dart';
import '../../weekly_review/application/weekly_review_providers.dart';

/// Dashboard. Answers the three core questions from real local data only;
/// where no data exists yet, each section says so honestly (no sample stats).
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final profile = ref.watch(studyProfileProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.appTitle),
        // The one place to switch exams (beside the sidebar, the sidebar's button is).
        actions: [
          if (profile.examCodes.isNotEmpty &&
              FormFactor.ofWidth(MediaQuery.sizeOf(context).width) != FormFactor.desktop)
            const ExamSwitcher(),
        ],
      ),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: AppSpacing.maxContentWidth),
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.md),
            children: [
              Semantics(
                header: true,
                child: Text(l10n.homeHeadline, style: theme.textTheme.headlineSmall),
              ),
              const SizedBox(height: AppSpacing.sm),
              if (profile.examCodes.isEmpty)
                Card(
                  color: theme.colorScheme.secondaryContainer,
                  child: ListTile(
                    leading: const Icon(Icons.flag_outlined),
                    title: Text(l10n.homeChooseExamTitle),
                    subtitle: Text(l10n.homeChooseExamMessage),
                    trailing: TextButton(
                      onPressed: () => context.push(AppRoutes.myExams),
                      child: Text(l10n.homeChooseExamAction),
                    ),
                  ),
                )
              else
                Text(
                  l10n.examSwitcherShowing(
                    ref.watch(examNameProvider(ref.watch(activeExamProvider)!)),
                  ),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              const SizedBox(height: AppSpacing.md),
              // Momentum first: streak, today's focus against the goal, one clear next step.
              const MomentumCard(),
              const SizedBox(height: AppSpacing.sm),
              const QuoteCard(),
              const SizedBox(height: AppSpacing.md),
              if (ref.watch(weeklyReviewDueProvider)) ...[
                Card(
                  color: theme.colorScheme.secondaryContainer,
                  child: ListTile(
                    leading: const Icon(Icons.event_note_outlined),
                    title: Text(l10n.weeklyHomeTitle),
                    subtitle: Text(l10n.weeklyHomeMessage),
                    trailing: TextButton(
                      onPressed: () => context.push(AppRoutes.weeklyReview),
                      child: Text(l10n.weeklyHomeOpen),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
              ],
              _TodaySection(profile: profile),
              const SizedBox(height: AppSpacing.md),
              const _WeakSection(),
              const SizedBox(height: AppSpacing.md),
              _UpcomingSection(profile: profile),
              const SizedBox(height: AppSpacing.md),
              const _ShortcutsSection(),
            ],
          ),
        ),
      ),
    );
  }
}

class _TodaySection extends ConsumerWidget {
  const _TodaySection({required this.profile});

  final StudyProfile profile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final count = ref.watch(activeConceptCountProvider);
    final revision = ref.watch(revisionOverviewProvider);
    final plan = ref.watch(studyPlanProvider);
    final today = ref.watch(todayProvider);
    final minutes = profile.dailyStudyMinutes;

    return SectionCard(
      icon: Icons.today_outlined,
      title: l10n.homeTodayTitle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (minutes != null) ...[
            Text(l10n.homeDailyGoal(formatStudyDuration(l10n, minutes))),
            const SizedBox(height: AppSpacing.xs),
          ],
          switch (count) {
            AsyncData(value: final n) when n > 0 => Text(l10n.homeConceptCount(n)),
            AsyncData() => _Muted(l10n.homeTodayEmpty),
            AsyncError() => _Muted(l10n.conceptsLoadError),
            _ => const LinearProgressIndicator(),
          },
          const SizedBox(height: AppSpacing.xs),
          switch (plan) {
            AsyncData(:final value) => Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (!value.practiceDataAvailable) _Muted(l10n.planOffline),
                if (value.items.isEmpty)
                  _Muted(l10n.planEmpty)
                else
                  for (final item in value.items) PlanItemTile(item: item),
                if (value.items.isNotEmpty)
                  _Muted(
                    value.budgetMinutes == null
                        ? l10n.planNoGoal
                        : l10n.planGoal(value.plannedMinutes, value.budgetMinutes!),
                  ),
              ],
            ),
            AsyncError() => _Muted(l10n.revisionLoadError),
            _ => const LinearProgressIndicator(),
          },
          if (revision case AsyncData(:final value) when value.dueToday == 0) ...[
            const SizedBox(height: AppSpacing.xs),
            switch (value) {
              RevisionOverview(nextDue: final next?) => _Muted(
                l10n.homeRevisionNoneToday(formatDue(context, today, next)),
              ),
              _ => _Muted(l10n.homeRevisionEmpty),
            },
          ],
          const SizedBox(height: AppSpacing.sm),
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: TextButton(
              onPressed: () => context.go(AppRoutes.study),
              child: Text(l10n.homeOpenConcepts),
            ),
          ),
        ],
      ),
    );
  }
}

class _WeakSection extends ConsumerWidget {
  const _WeakSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final insights = ref.watch(topicInsightsProvider);
    return SectionCard(
      icon: Icons.insights_outlined,
      title: l10n.homeWeakTitle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          switch (insights) {
            AsyncData(:final value) when value.weak.isNotEmpty => Column(
              children: [
                for (final topic in value.weak.take(3))
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text('${topic.name} · ${topic.subject}'),
                    subtitle: Text(topicEvidence(context, topic)),
                  ),
              ],
            ),
            AsyncData(:final value) when value.practice == null => _Muted(l10n.homeWeakOffline),
            AsyncData(:final value)
                when value.practice!.total.answered == 0 && value.topics.isEmpty =>
              _Muted(l10n.homeWeakEmpty),
            AsyncData(:final value) when value.topics.any((t) => t.hasEnoughData) => _Muted(
              l10n.homeWeakNone(formatPercent(context, AnalyticsRules.weakAccuracy)),
            ),
            AsyncData() => _Muted(
              l10n.homeWeakNeedMore(AnalyticsRules.minAnswers, AnalyticsRules.minReviews),
            ),
            AsyncError() => _Muted(l10n.revisionLoadError),
            _ => const LinearProgressIndicator(),
          },
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: TextButton(
              onPressed: () => context.go(AppRoutes.progress),
              child: Text(l10n.homeSeeProgress),
            ),
          ),
        ],
      ),
    );
  }
}

class _UpcomingSection extends ConsumerWidget {
  const _UpcomingSection({required this.profile});

  final StudyProfile profile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final today = CalendarDate.fromDateTime(ref.watch(clockProvider)());
    final days = daysUntilExam(profile, today);
    final date = profile.targetExamDate;

    return SectionCard(
      icon: Icons.event_outlined,
      title: l10n.homeUpcomingTitle,
      child: switch (days) {
        null => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [_Muted(l10n.homeUpcomingEmpty), _Muted(l10n.homeSetExamDate)],
        ),
        < 0 => Text(l10n.homeExamPassed),
        _ => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.homeExamCountdown(days),
              style: theme.textTheme.titleLarge?.copyWith(color: theme.colorScheme.primary),
            ),
            Text(l10n.homeExamOn(formatCalendarDate(context, date!))),
          ],
        ),
      },
    );
  }
}

/// Every feature screen by name, so none has to be found behind an icon in another tab.
class _ShortcutsSection extends StatelessWidget {
  const _ShortcutsSection();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = Theme.of(context).colorScheme;
    return SectionCard(
      icon: Icons.near_me_outlined,
      title: l10n.homeShortcutsTitle,
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Two columns on phones, three when the card is wide enough.
          final columns = constraints.maxWidth >= 520 ? 3 : 2;
          final width = (constraints.maxWidth - AppSpacing.sm * (columns - 1)) / columns;
          return Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              for (final d in featureShortcuts(l10n))
                SizedBox(
                  width: width,
                  child: Material(
                    color: colors.surfaceContainer,
                    borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                      onTap: () => context.push(d.route),
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpacing.sm + 4),
                        child: Row(
                          children: [
                            Icon(d.icon, color: colors.primary),
                            const SizedBox(width: AppSpacing.sm + 2),
                            Expanded(child: Text(d.label, maxLines: 2)),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _Muted extends StatelessWidget {
  const _Muted(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text(
      text,
      style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
    );
  }
}
