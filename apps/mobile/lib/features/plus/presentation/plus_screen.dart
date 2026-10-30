import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/localization/generated/app_localizations.dart';
import '../../../core/utils/app_log.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/section_card.dart';
import '../../ai/application/ai_providers.dart';
import '../data/plus_repository.dart';

/// PrepLoop Plus: what it includes, the account's status and this month's AI use. Payments are
/// not built yet; a development server offers a free test subscription instead.
class PlusScreen extends ConsumerStatefulWidget {
  const PlusScreen({super.key});

  @override
  ConsumerState<PlusScreen> createState() => _PlusScreenState();
}

class _PlusScreenState extends ConsumerState<PlusScreen> {
  bool _busy = false;

  Future<void> _change(Future<PlusStatus> Function(PlusRepository repo) action) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      await action(ref.read(plusRepositoryProvider));
      ref
        ..invalidate(plusStatusProvider)
        // AI panels unlock (or lock) with the subscription.
        ..invalidate(aiStatusProvider);
    } on Object catch (error, stack) {
      if (error is! AppFailure) {
        logError('Changing the Plus test subscription failed', error, stack);
      }
      messenger.showSnackBar(SnackBar(content: Text(l10n.plusChangeFailed)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final status = ref.watch(plusStatusProvider);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.plusTitle)),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: AppSpacing.maxContentWidth),
          child: switch (status) {
            AsyncData(:final value) => _PlusDetails(
              status: value,
              busy: _busy,
              onStartTest: () => _change((repo) => repo.startTest()),
              onEndTest: () => _change((repo) => repo.endTest()),
            ),
            AsyncError() => EmptyState(
              icon: Icons.cloud_off,
              title: l10n.plusLoadFailed,
              action: OutlinedButton(
                onPressed: () => ref.invalidate(plusStatusProvider),
                child: Text(l10n.retry),
              ),
            ),
            _ => const Center(child: CircularProgressIndicator()),
          },
        ),
      ),
    );
  }
}

class _PlusDetails extends ConsumerWidget {
  const _PlusDetails({
    required this.status,
    required this.busy,
    required this.onStartTest,
    required this.onEndTest,
  });

  final PlusStatus status;
  final bool busy;
  final VoidCallback onStartTest;
  final VoidCallback onEndTest;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final locale = Localizations.localeOf(context).toLanguageTag();
    String date(DateTime d) => DateFormat.yMMMd(locale).format(d.toLocal());
    final aiOn = ref.watch(aiStatusProvider).value?.enabled ?? false;
    final s = status;

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: [
        SectionCard(
          icon: Icons.workspace_premium_outlined,
          title: l10n.plusStatusTitle,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                s.active && s.activeUntil != null
                    ? l10n.plusActiveUntil(date(s.activeUntil!))
                    : l10n.plusInactive,
                style: theme.textTheme.titleMedium,
              ),
              if (s.active && s.source == PlusSource.test)
                Text(l10n.plusTestLabel, style: TextStyle(color: theme.colorScheme.tertiary)),
              if (s.active && s.source == PlusSource.operator) Text(l10n.plusOperatorLabel),
              const SizedBox(height: AppSpacing.sm),
              if (s.active && s.source == PlusSource.test)
                OutlinedButton(onPressed: busy ? null : onEndTest, child: Text(l10n.plusEndTest))
              else if (!s.active && s.testMode) ...[
                FilledButton.icon(
                  icon: const Icon(Icons.science_outlined),
                  label: Text(l10n.plusStartTest(plusTestDays)),
                  onPressed: busy ? null : onStartTest,
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(l10n.plusTestExplained, style: theme.textTheme.bodySmall),
              ] else if (!s.active && !s.purchasesAvailable)
                Text(l10n.plusNotForSaleYet, style: theme.textTheme.bodySmall),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        SectionCard(
          icon: Icons.auto_awesome,
          title: l10n.plusIncludesTitle,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final feature in [
                l10n.plusFeatureQuickAnswers,
                l10n.plusFeatureExplanations,
                l10n.plusFeatureQuestions,
                l10n.plusFeaturePaperTopics,
                l10n.plusFeatureTopicDraft,
                l10n.plusFeatureLessons,
              ])
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  leading: Icon(Icons.check_circle_outline, color: theme.colorScheme.primary),
                  title: Text(feature),
                ),
              Text(l10n.plusAllowance(s.aiMonthlyAllowance)),
              const SizedBox(height: AppSpacing.xs),
              Text(l10n.plusAiLabelled, style: theme.textTheme.bodySmall),
              if (!aiOn) ...[
                const SizedBox(height: AppSpacing.xs),
                Text(l10n.plusAiOffOnServer, style: TextStyle(color: theme.colorScheme.error)),
              ],
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        SectionCard(
          icon: Icons.data_usage,
          title: l10n.plusUsageTitle,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l10n.plusUsage(s.aiUsedThisMonth, s.aiMonthlyAllowance)),
              const SizedBox(height: AppSpacing.xs),
              LinearProgressIndicator(
                value: (s.aiUsedThisMonth / s.aiMonthlyAllowance).clamp(0, 1).toDouble(),
                semanticsLabel: l10n.plusUsage(s.aiUsedThisMonth, s.aiMonthlyAllowance),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(l10n.plusResets(date(s.periodResetsAt)), style: theme.textTheme.bodySmall),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        SectionCard(
          icon: Icons.school_outlined,
          title: l10n.plusFreeTitle,
          child: Text(l10n.plusFreeMessage),
        ),
      ],
    );
  }
}
