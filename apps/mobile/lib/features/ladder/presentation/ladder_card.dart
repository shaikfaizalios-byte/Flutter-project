import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../core/localization/generated/app_localizations.dart';
import '../../exams/application/active_exam.dart';
import '../application/ladder_providers.dart';
import '../domain/ladder_models.dart';
import 'ladder_icon.dart';

/// Home entry: one tap into a ladder on a repeated topic, or any topic. The best shown is the
/// learner's own; nothing here is about other users.
class LadderCard extends ConsumerWidget {
  const LadderCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (ref.watch(activeExamProvider) == null) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final overview = ref.watch(ladderOverviewProvider).value;
    if (overview?.available == false) return const SizedBox.shrink();
    final best = overview?.best;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const LadderIcon(),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Semantics(
                        header: true,
                        child: Text(l10n.ladderTitle, style: theme.textTheme.titleMedium),
                      ),
                      Text(l10n.ladderTagline, style: theme.textTheme.bodyMedium),
                      if (best != null)
                        Text(
                          l10n.ladderBest(best.step, best.topicName),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.primary,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.sm,
              children: [
                for (final topic in overview?.repeated ?? const <LadderTopic>[])
                  ActionChip(
                    label: Text(topic.name),
                    onPressed: () => context.push(AppRoutes.ladderRun(topic.topicId, topic.name)),
                  ),
                ActionChip(
                  avatar: const Icon(Icons.search, size: 18),
                  label: Text(l10n.ladderAnyTopic),
                  onPressed: () => context.push(AppRoutes.ladderTopics),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
