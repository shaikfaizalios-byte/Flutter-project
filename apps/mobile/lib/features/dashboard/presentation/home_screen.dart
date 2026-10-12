import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../core/exams/exam_catalog.dart';
import '../../../core/localization/generated/app_localizations.dart';
import '../../../core/utils/calendar_date.dart';
import '../../../core/utils/clock.dart';
import '../../../core/widgets/section_card.dart';
import '../../concepts/application/concepts_providers.dart';
import '../../study_plan/application/study_profile_controller.dart';
import '../../study_plan/domain/study_profile.dart';
import '../../study_plan/presentation/study_profile_widgets.dart';

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
      appBar: AppBar(title: Text(l10n.appTitle)),
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
                      onPressed: () => context.go(AppRoutes.profile),
                      child: Text(l10n.homeChooseExamAction),
                    ),
                  ),
                )
              else
                Wrap(
                  spacing: AppSpacing.sm,
                  children: [
                    for (final code in profile.examCodes)
                      Chip(
                        avatar: const Icon(Icons.flag_outlined, size: 18),
                        label: Text(examShortName(code)),
                      ),
                  ],
                ),
              const SizedBox(height: AppSpacing.md),
              _TodaySection(profile: profile),
              const SizedBox(height: AppSpacing.md),
              SectionCard(
                icon: Icons.insights_outlined,
                title: l10n.homeWeakTitle,
                child: _Muted(l10n.homeWeakEmpty),
              ),
              const SizedBox(height: AppSpacing.md),
              _UpcomingSection(profile: profile),
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
          _Muted(l10n.homePlanComingSoon),
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
