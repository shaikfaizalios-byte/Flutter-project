import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_destinations.dart';
import '../../../app/routes.dart';
import '../../../app/theme/app_spacing.dart';
import '../../exams/application/exam_catalog_controller.dart';
import '../../../core/localization/generated/app_localizations.dart';
import '../../../core/widgets/section_card.dart';
import '../../analytics/application/analytics_providers.dart';
import '../../analytics/domain/weak_topics.dart';
import '../../analytics/presentation/analytics_widgets.dart';
import '../../revision/application/revision_providers.dart';
import '../../revision/domain/revision_card.dart';
import '../../revision/presentation/revision_widgets.dart';
import '../../study_plan/application/study_profile_controller.dart';
import '../../study_plan/domain/study_profile.dart';
import '../../exams/presentation/exam_switcher.dart';
import '../../exams/application/active_exam.dart';
import '../../focus/presentation/focus_widgets.dart';
import '../../documents/application/documents_providers.dart';
import '../../insights/data/insights_repository.dart';
import '../../practice/application/practice_providers.dart';
import '../../practice/domain/practice_models.dart';
import '../../practice/presentation/practice_hub_screen.dart' show startAndOpen;
import '../../analytics/domain/study_plan.dart';
import '../../documents/presentation/import_progress.dart';
import '../../../app/app_features.dart';
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
              // One card answers "what do I do today": the plan, then focus time and streak.
              _TodayCard(profile: profile),
              if (ref.watch(appFeaturesProvider).quotes) ...[
                const SizedBox(height: AppSpacing.sm),
                const QuoteCard(),
              ],
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
              const _WeakSection(),
              const SizedBox(height: AppSpacing.md),
              const _ShortcutsSection(),
            ],
          ),
        ),
      ),
    );
  }
}

/// Today in one card: what to do (the plan, each item with its reason and a start button),
/// how long, how far the exam is, then focus time and the streak. With nothing planned it
/// points to the two ways to start.
class _TodayCard extends ConsumerWidget {
  const _TodayCard({required this.profile});

  final StudyProfile profile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final onCard = theme.colorScheme.onPrimaryContainer;
    final muted = theme.textTheme.bodyMedium?.copyWith(color: onCard.withValues(alpha: 0.8));
    final revision = ref.watch(revisionOverviewProvider);
    final plan = ref.watch(studyPlanProvider);
    final today = ref.watch(todayProvider);
    final days = daysUntilExam(profile, today);
    final items = plan.value?.items ?? const [];

    return MomentumCard(
      top: [
        Row(
          children: [
            Icon(Icons.today_outlined, color: onCard),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Semantics(
                header: true,
                child: Text(
                  l10n.todayTitle,
                  style: theme.textTheme.titleLarge?.copyWith(color: onCard),
                ),
              ),
            ),
          ],
        ),
        Text(
          [
            if (items.isNotEmpty) l10n.todayTasks(items.length),
            if (days != null) days >= 0 ? l10n.homeExamCountdown(days) : l10n.homeExamPassed,
          ].join(' · '),
          style: muted,
        ),
        const SizedBox(height: AppSpacing.sm),
        // Papers still being imported: their step and progress.
        ImportsInProgress(color: onCard),
        // No papers of your own yet: start from the starter papers.
        const _StarterPapers(),
        switch (plan) {
          AsyncData(:final value) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (!value.practiceDataAvailable) Text(l10n.planOffline, style: muted),
              // The tasks sit on a plain surface so their text and buttons read clearly.
              if (value.items.isNotEmpty)
                Material(
                  color: theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                    child: Column(
                      children: [for (final item in value.items) PlanItemTile(item: item)],
                    ),
                  ),
                ),
              if (value.items.isNotEmpty) const SizedBox(height: AppSpacing.xs),
              if (value.items.isNotEmpty)
                Text(
                  value.budgetMinutes == null
                      ? l10n.planNoGoal
                      : l10n.planGoal(value.plannedMinutes, value.budgetMinutes!),
                  style: muted,
                )
              else ...[
                Text(l10n.todayNothingPlanned, style: muted),
                const SizedBox(height: AppSpacing.sm),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: [
                    FilledButton.tonalIcon(
                      icon: const Icon(Icons.quiz_outlined),
                      label: Text(l10n.focusDoPractice),
                      onPressed: () => context.go(AppRoutes.practice),
                    ),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.picture_as_pdf_outlined),
                      label: Text(l10n.todayImportPaper),
                      onPressed: () => context.push(AppRoutes.documents),
                    ),
                  ],
                ),
              ],
            ],
          ),
          AsyncError() => Text(l10n.revisionLoadError, style: muted),
          _ => const LinearProgressIndicator(),
        },
        if (revision case AsyncData(:final value) when value.dueToday == 0) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(switch (value) {
            RevisionOverview(nextDue: final next?) => l10n.homeRevisionNoneToday(
              formatDue(context, today, next),
            ),
            _ => l10n.homeRevisionEmpty,
          }, style: muted),
        ],
        Divider(height: AppSpacing.lg, color: onCard.withValues(alpha: 0.2)),
      ],
    );
  }
}

/// The shared bank's starter papers for the current exam, offered while the learner has no
/// papers of their own: practise them now, or see which topics repeat in them.
class _StarterPapers extends ConsumerWidget {
  const _StarterPapers();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final exam = ref.watch(activeExamProvider);
    final starter = exam == null ? null : ref.watch(sharedBankProvider).value?[exam];
    if (starter == null || starter.papers == 0) return const SizedBox.shrink();
    // Only asked when there are starter papers to offer.
    final own = ref.watch(documentListProvider).value;
    if (own == null || own.isNotEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Material(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.sm + 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.public, color: theme.colorScheme.primary),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(child: Text(l10n.starterTitle, style: theme.textTheme.titleSmall)),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                l10n.starterReady(
                  starter.papers,
                  ref.watch(examNameProvider(exam!)),
                  starter.questions,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: [
                  FilledButton.icon(
                    icon: const Icon(Icons.quiz_outlined),
                    label: Text(l10n.starterPractise),
                    onPressed: () => startAndOpen(
                      context,
                      () => ref
                          .read(practiceRepositoryProvider)
                          .startPractice(
                            PracticeRequest(examCode: exam, count: PlanRules.practiceQuestions),
                          ),
                    ),
                  ),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.repeat),
                    label: Text(l10n.starterRepeats),
                    onPressed: () => context.push(AppRoutes.repeatsShared),
                  ),
                ],
              ),
            ],
          ),
        ),
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
