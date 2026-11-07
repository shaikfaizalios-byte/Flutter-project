import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/app_features.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../core/localization/generated/app_localizations.dart';
import '../../../core/widgets/section_card.dart';
import '../application/practice_providers.dart';

String _clock(int ms) {
  final seconds = ms ~/ 1000;
  return '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}';
}

String _number(double value) =>
    value == value.roundToDouble() ? value.toStringAsFixed(0) : value.toStringAsFixed(2);

/// After a mock: chapters, time per question and the learner's own history. A percentile appears
/// only when real attempts allow one, and says what it is. There are no ranks.
class MockAnalysisCard extends ConsumerWidget {
  const MockAnalysisCard({super.key, required this.sessionId});

  final String sessionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(appFeaturesProvider).examProfiles) return const SizedBox.shrink();
    final analysis = ref.watch(mockAnalysisProvider(sessionId)).value;
    if (analysis == null) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context);
    final small = Theme.of(context).textTheme.bodySmall;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: SectionCard(
        icon: Icons.analytics_outlined,
        title: l10n.analysisTitle,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (analysis.percent != null && analysis.accounts != null)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: Text(l10n.analysisPercentile(analysis.percent!, analysis.accounts!)),
              ),
            if (analysis.history.length > 1) ...[
              Text(l10n.analysisHistory, style: Theme.of(context).textTheme.titleSmall),
              for (final attempt in analysis.history)
                Text(
                  [
                    if (attempt.submittedAt != null)
                      MaterialLocalizations.of(context)
                          .formatShortDate(attempt.submittedAt!.toLocal()),
                    '${_number(attempt.score)} / ${_number(attempt.maxScore)}',
                    if (attempt.current) l10n.analysisThisTest,
                  ].join(' · '),
                ),
              const SizedBox(height: AppSpacing.sm),
            ],
            if (analysis.chapters.isNotEmpty) ...[
              Text(l10n.analysisChapters, style: Theme.of(context).textTheme.titleSmall),
              for (final chapter in analysis.chapters)
                Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.xs),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(chapter.name),
                      Text(
                        [
                          l10n.analysisCounts(chapter.correct, chapter.wrong, chapter.unattempted),
                          if (chapter.accuracy != null) l10n.analysisAccuracy(chapter.accuracy!),
                          _clock(chapter.timeMs),
                        ].join(' · '),
                        style: small,
                      ),
                    ],
                  ),
                ),
            ],
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              title: Text(l10n.analysisTimes),
              children: [
                for (final question in analysis.questions)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    title: Text(
                      [l10n.analysisQuestion(question.position), ?question.topic].join(' · '),
                    ),
                    subtitle: Text(
                      [
                        switch (question.status) {
                          'correct' => l10n.sessionCorrect,
                          'wrong' => l10n.sessionIncorrect,
                          'dropped' => l10n.analysisDropped,
                          _ => l10n.analysisUnattempted,
                        },
                        _number(question.marks),
                      ].join(' · '),
                    ),
                    trailing: question.timeMs == null ? null : Text(_clock(question.timeMs!)),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
