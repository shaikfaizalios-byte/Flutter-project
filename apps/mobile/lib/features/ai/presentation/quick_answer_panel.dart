import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../core/localization/generated/app_localizations.dart';
import '../application/ai_providers.dart';
import '../application/quick_answers.dart';
import 'ai_widgets.dart';

/// A short AI answer to a search with no match in the papers, labelled as unchecked AI.
/// Offered once ("Ask AI") because the search text goes to the AI provider; after that it
/// answers by itself until the learner stops it. Shown only when the server has AI.
class QuickAnswerPanel extends ConsumerWidget {
  const QuickAnswerPanel({super.key, required this.query});

  final String query;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final enabled = ref.watch(aiStatusProvider).value?.enabled ?? false;
    if (!enabled) return const SizedBox.shrink();
    final on = ref.watch(quickAnswersOnProvider);

    final Widget body;
    if (!on) {
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.quickAnswerOffer, style: theme.textTheme.bodySmall),
          const SizedBox(height: AppSpacing.xs),
          FilledButton.tonalIcon(
            icon: const Icon(Icons.auto_awesome),
            label: Text(l10n.quickAnswerAsk),
            onPressed: () => ref.read(quickAnswersOnProvider.notifier).set(on: true),
          ),
        ],
      );
    } else {
      body = switch (ref.watch(quickAnswerProvider(query))) {
        AsyncData(value: final a?) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SelectableText(a.answer),
            const SizedBox(height: AppSpacing.xs),
            Text(l10n.quickAnswerCaution(a.model), style: theme.textTheme.bodySmall),
            TextButton(
              onPressed: () => ref.read(quickAnswersOnProvider.notifier).set(on: false),
              child: Text(l10n.quickAnswerTurnOff),
            ),
          ],
        ),
        AsyncError(:final error) => Row(
          children: [
            Expanded(child: Text(aiErrorMessage(l10n, error), style: theme.textTheme.bodySmall)),
            TextButton(
              onPressed: () => ref.invalidate(quickAnswerProvider(query)),
              child: Text(l10n.retry),
            ),
          ],
        ),
        _ => Row(
          children: [
            const SizedBox.square(dimension: 16, child: CircularProgressIndicator(strokeWidth: 2)),
            const SizedBox(width: AppSpacing.sm),
            Text(l10n.quickAnswerLoading, style: theme.textTheme.bodySmall),
          ],
        ),
      };
    }

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppSpacing.sm),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            header: true,
            child: Text(l10n.quickAnswerTitle, style: theme.textTheme.titleSmall),
          ),
          const SizedBox(height: AppSpacing.xs),
          body,
        ],
      ),
    );
  }
}
