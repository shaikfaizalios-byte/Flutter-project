import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_features.dart';
import '../../../app/routes.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../core/localization/generated/app_localizations.dart';
import '../application/descriptive_providers.dart';

/// Home entry for an exam with a written paper. Other exams never see it.
class DescriptiveCard extends ConsumerWidget {
  const DescriptiveCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(appFeaturesProvider).examProfiles) return const SizedBox.shrink();
    if (ref.watch(descriptiveOverviewProvider).value?.available != true) {
      return const SizedBox.shrink();
    }
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.sm),
      child: Card(
        child: ListTile(
          leading: const Icon(Icons.edit_note),
          title: Text(l10n.descriptiveTitle, style: theme.textTheme.titleMedium),
          subtitle: Text(l10n.descriptiveTagline),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => context.push(AppRoutes.descriptiveTopics),
        ),
      ),
    );
  }
}

/// The exam's topics to practise written answers on.
class DescriptiveTopicsScreen extends ConsumerWidget {
  const DescriptiveTopicsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final overview = ref.watch(descriptiveOverviewProvider);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.descriptiveTitle)),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: AppSpacing.maxContentWidth),
          child: switch (overview) {
            AsyncData(:final value) when (value?.topics ?? const []).isEmpty => Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Text(l10n.descriptiveNoTopics),
            ),
            AsyncData(:final value) => ListView(
              children: [
                for (final topic in value!.topics)
                  ListTile(
                    title: Text(topic.name),
                    subtitle: Text(topic.subject),
                    onTap: () => context.push(AppRoutes.descriptiveRun(topic.topicId, topic.name)),
                  ),
              ],
            ),
            AsyncError() => Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Text(l10n.ladderNoConnection),
            ),
            _ => const Center(child: CircularProgressIndicator()),
          },
        ),
      ),
    );
  }
}
