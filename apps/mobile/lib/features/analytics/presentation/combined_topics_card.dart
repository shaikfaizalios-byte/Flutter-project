import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/app_features.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../core/localization/generated/app_localizations.dart';
import '../../../core/widgets/section_card.dart';
import '../../exams/application/exam_catalog_controller.dart';
import '../application/analytics_providers.dart';

/// For a learner preparing for several exams: topics that mean the same across them, combined and
/// per exam. Raw counts only. Hidden until there is something to show.
class CombinedTopicsCard extends ConsumerWidget {
  const CombinedTopicsCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(appFeaturesProvider).examProfiles) return const SizedBox.shrink();
    final topics = ref.watch(canonicalStatsProvider).value ?? const [];
    if (topics.isEmpty) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: SectionCard(
        icon: Icons.join_inner,
        title: l10n.progressCombinedTitle,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final topic in topics)
              ListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                title: Text(topic.name),
                subtitle: Text(
                  [
                    for (final exam in topic.exams)
                      l10n.progressCombinedExam(
                        ref.watch(examNameProvider(exam.examCode)),
                        exam.correct,
                        exam.answered,
                      ),
                  ].join(' · '),
                ),
                trailing: Text(l10n.progressCombinedTotal(topic.correct, topic.answered)),
              ),
          ],
        ),
      ),
    );
  }
}
