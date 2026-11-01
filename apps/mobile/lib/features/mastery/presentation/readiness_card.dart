import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../core/localization/generated/app_localizations.dart';
import '../../../core/widgets/section_card.dart';
import '../../analytics/domain/weak_topics.dart';
import '../../analytics/presentation/analytics_widgets.dart';
import '../../analytics/presentation/progress_screen.dart' show MutedLine;
import '../../study_plan/presentation/study_profile_widgets.dart';
import '../application/mastery_providers.dart';
import '../domain/readiness.dart';

/// Readiness for the current exam: syllabus coverage and the evidence behind it. No score or
/// pass chance is shown (the card says so).
class ReadinessCard extends ConsumerWidget {
  const ReadinessCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final readiness = ref.watch(readinessProvider).value;
    if (readiness == null) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return SectionCard(
      icon: Icons.flag_outlined,
      title: l10n.readinessTitle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!readiness.hasSyllabus)
            MutedLine(l10n.readinessNoSyllabus)
          else ...[
            Text(
              l10n.readinessCoverage(readiness.practised, readiness.topics),
              style: theme.textTheme.titleSmall,
            ),
            const SizedBox(height: AppSpacing.xs),
            LinearProgressIndicator(value: readiness.practised / readiness.topics),
            const SizedBox(height: AppSpacing.xs),
            Text(l10n.readinessStrong(readiness.strong)),
            for (final subject in readiness.subjects)
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text(subject.name),
                trailing: Text(
                  l10n.readinessSubject(subject.practised, subject.topics, subject.strong),
                ),
              ),
          ],
          const SizedBox(height: AppSpacing.sm),
          Text(l10n.readinessEvidenceTitle, style: theme.textTheme.titleSmall),
          ..._evidence(context, readiness).map(Text.new),
          const SizedBox(height: AppSpacing.sm),
          MutedLine(l10n.readinessNotPrediction),
        ],
      ),
    );
  }

  List<String> _evidence(BuildContext context, Readiness readiness) {
    final l10n = AppLocalizations.of(context);
    final answers = readiness.recentAnswers;
    final mock = readiness.latestMock;
    String number(double value) =>
        NumberFormat.decimalPattern(Localizations.localeOf(context).toLanguageTag()).format(value);
    return [
      if (answers == null)
        l10n.readinessOffline
      else if (answers == 0)
        l10n.readinessNoRecent(AnalyticsRules.recentDays)
      else
        l10n.readinessRecent(
          answers,
          AnalyticsRules.recentDays,
          formatPercent(context, readiness.recentCorrect / answers),
        ),
      if (answers != null)
        mock == null
            ? l10n.readinessNoMock
            : l10n.readinessMocks(
                readiness.mocksInWindow ?? 0,
                AnalyticsRules.windowDays,
                number(mock.score),
                number(mock.maxScore),
                formatCalendarDate(context, mock.localDate),
              ),
      if (readiness.daysToExam != null) l10n.reasonExamIn(readiness.daysToExam!),
    ];
  }
}
