import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../core/localization/generated/app_localizations.dart';
import '../../../core/utils/calendar_date.dart';
import '../../../core/widgets/section_card.dart';
import '../../analytics/application/analytics_providers.dart';
import '../../analytics/domain/study_plan.dart';
import '../../analytics/presentation/analytics_widgets.dart';
import '../../exams/application/active_exam.dart';
import '../../practice/application/practice_providers.dart';
import '../../practice/domain/practice_models.dart';
import '../../practice/presentation/practice_hub_screen.dart';
import '../../revision/application/revision_providers.dart';
import '../../study_plan/presentation/study_profile_widgets.dart' show formatCalendarDate;
import '../application/weekly_review_providers.dart';
import '../domain/weekly_review.dart';

/// The last 7 days in real numbers, what to work on next week, and a short reflection.
class WeeklyReviewScreen extends ConsumerWidget {
  const WeeklyReviewScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final review = ref.watch(weeklyReviewProvider);
    final reflections = ref.watch(weeklyReflectionsProvider);
    final today = ref.watch(todayProvider);
    // The plan written in an earlier review (not one saved today).
    final previous = reflections.where((r) => r.savedOn != today).firstOrNull;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.weeklyTitle)),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: AppSpacing.maxContentWidth),
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.md),
            children: [
              Text(
                l10n.weeklyRange(
                  formatCalendarDate(context, review.start),
                  formatCalendarDate(context, review.end),
                ),
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: AppSpacing.md),
              if (previous != null && previous.nextWeek.isNotEmpty) ...[
                Card(
                  color: theme.colorScheme.secondaryContainer,
                  child: ListTile(
                    leading: const Icon(Icons.flag_outlined),
                    title: Text(l10n.weeklyLastPlan),
                    subtitle: Text(previous.nextWeek),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
              ],
              _NumbersCard(review: review),
              const SizedBox(height: AppSpacing.md),
              const _NextWeekCard(),
              const SizedBox(height: AppSpacing.md),
              _ReflectionCard(
                key: ValueKey(reflections.firstOrNull?.savedOn),
                today: today,
                saved: reflections.where((r) => r.savedOn == today).firstOrNull,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NumbersCard extends ConsumerWidget {
  const _NumbersCard({required this.review});

  final WeeklyReview review;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final now = review.thisWeek;
    final before = review.lastWeek;
    final offline = now.answered == null;

    Widget row(IconData icon, String label, String value, String previous) => Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        children: [
          Icon(icon, size: 20, color: theme.colorScheme.primary),
          const SizedBox(width: AppSpacing.sm),
          Expanded(child: Text(label)),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(value, style: theme.textTheme.titleMedium),
              Text(previous, style: theme.textTheme.bodySmall),
            ],
          ),
        ],
      ),
    );

    String accuracy(int? answered, double? share) => answered == null
        ? l10n.weeklyNoData
        : share == null
        ? '$answered'
        : l10n.weeklyAnsweredAccuracy(answered, formatPercent(context, share));

    return SectionCard(
      icon: Icons.insights_outlined,
      title: l10n.weeklyNumbersTitle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          row(
            Icons.event_available_outlined,
            l10n.weeklyActiveDays,
            l10n.weeklyOfDays(now.activeDays, WeeklyReviewRules.days),
            l10n.weeklyBefore(l10n.weeklyOfDays(before.activeDays, WeeklyReviewRules.days)),
          ),
          row(
            Icons.center_focus_strong,
            l10n.weeklyFocus,
            l10n.focusMinutes(now.focusMinutes),
            l10n.weeklyBefore(l10n.focusMinutes(before.focusMinutes)),
          ),
          row(
            Icons.quiz_outlined,
            l10n.weeklyAnswered,
            accuracy(now.answered, now.accuracy),
            l10n.weeklyBefore(accuracy(before.answered, before.accuracy)),
          ),
          row(
            Icons.style_outlined,
            l10n.weeklyReviews,
            '${now.reviews}',
            l10n.weeklyBefore('${before.reviews}'),
          ),
          row(
            Icons.psychology_outlined,
            l10n.weeklyRecall,
            '${now.recallChecks}',
            l10n.weeklyBefore('${before.recallChecks}'),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            offline ? '${l10n.weeklyRules} ${l10n.weeklyOffline}' : l10n.weeklyRules,
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

/// Weak topics to practise and the revision due in the coming week.
class _NextWeekCard extends ConsumerWidget {
  const _NextWeekCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final weak = (ref.watch(topicInsightsProvider).value?.weak ?? const [])
        .take(WeeklyReviewRules.focusTopics)
        .toList();
    final overview = ref.watch(revisionOverviewProvider).value;
    final due = overview == null
        ? null
        : overview.dueToday + overview.upcoming.take(WeeklyReviewRules.days - 1).fold<int>(0, _add);
    return SectionCard(
      icon: Icons.trending_up,
      title: l10n.weeklyNextTitle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (weak.isEmpty)
            Text(l10n.weeklyNoWeak)
          else ...[
            Text(l10n.weeklyWeakIntro),
            for (final topic in weak)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(topic.name),
                subtitle: Text(
                  [
                    topic.subject,
                    if (topic.counts.accuracy case final share?)
                      l10n.topicAccuracy(formatPercent(context, share), topic.counts.answered),
                  ].join(' · '),
                ),
                trailing: topic.topicId == null
                    ? null
                    : TextButton(
                        onPressed: () => startAndOpen(
                          context,
                          () => ref
                              .read(practiceRepositoryProvider)
                              .startPractice(
                                PracticeRequest(
                                  examCode: ref.read(activeExamProvider),
                                  topicId: topic.topicId,
                                  count: PlanRules.practiceQuestions,
                                ),
                              ),
                        ),
                        child: Text(l10n.masteryPractise),
                      ),
              ),
          ],
          if (due != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(l10n.weeklyDueCards(due), style: theme.textTheme.titleSmall),
          ],
        ],
      ),
    );
  }

  static int _add(int a, int b) => a + b;
}

/// Two short questions; saved on this device only.
class _ReflectionCard extends ConsumerStatefulWidget {
  const _ReflectionCard({super.key, required this.today, required this.saved});

  final CalendarDate today;
  final WeeklyReflection? saved;

  @override
  ConsumerState<_ReflectionCard> createState() => _ReflectionCardState();
}

class _ReflectionCardState extends ConsumerState<_ReflectionCard> {
  late final _wentWell = TextEditingController(text: widget.saved?.wentWell ?? '');
  late final _nextWeek = TextEditingController(text: widget.saved?.nextWeek ?? '');

  @override
  void dispose() {
    _wentWell.dispose();
    _nextWeek.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    FocusScope.of(context).unfocus();
    await ref
        .read(weeklyReflectionsProvider.notifier)
        .save(
          WeeklyReflection(
            savedOn: widget.today,
            wentWell: _wentWell.text.trim(),
            nextWeek: _nextWeek.text.trim(),
          ),
        );
    messenger.showSnackBar(SnackBar(content: Text(l10n.weeklySaved)));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    InputDecoration decoration(String label) =>
        InputDecoration(labelText: label, border: const OutlineInputBorder());
    return SectionCard(
      icon: Icons.edit_note,
      title: l10n.weeklyReflectTitle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _wentWell,
            minLines: 2,
            maxLines: 5,
            maxLength: WeeklyReviewRules.maxText,
            decoration: decoration(l10n.weeklyWentWell),
          ),
          const SizedBox(height: AppSpacing.sm),
          TextField(
            controller: _nextWeek,
            minLines: 2,
            maxLines: 5,
            maxLength: WeeklyReviewRules.maxText,
            decoration: decoration(l10n.weeklyNextWeek),
          ),
          Text(l10n.weeklyPrivate, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: AppSpacing.sm),
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: FilledButton(onPressed: _save, child: Text(l10n.weeklySave)),
          ),
        ],
      ),
    );
  }
}
