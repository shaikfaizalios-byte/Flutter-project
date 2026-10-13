import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../core/localization/generated/app_localizations.dart';
import '../../../core/utils/app_log.dart';
import '../../../core/widgets/empty_state.dart';
import '../application/revision_providers.dart';
import '../domain/revision_card.dart';
import '../domain/revision_schedule.dart';
import 'revision_widgets.dart';

/// Reviews today's due cards one at a time: recall, reveal, rate.
///
/// The due list is fixed when the screen opens, so rated cards (now due later) do not
/// shift the queue.
class ReviewScreen extends ConsumerStatefulWidget {
  const ReviewScreen({super.key});

  @override
  ConsumerState<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends ConsumerState<ReviewScreen> {
  List<RevisionCard>? _queue;
  Object? _loadError;
  int _index = 0;
  bool _revealed = false;
  bool _saving = false;
  final _ratings = <RecallRating, int>{};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final cards = await ref.read(revisionCardsProvider.future);
      final today = ref.read(todayProvider);
      if (!mounted) return;
      setState(() {
        _queue = [
          for (final c in cards)
            if (c.schedule.isDue(today)) c,
        ];
        _loadError = null;
      });
    } on Object catch (error, stack) {
      logError('Loading due cards failed', error, stack);
      if (mounted) setState(() => _loadError = error);
    }
  }

  Future<void> _rate(RevisionCard card, RecallRating rating) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _saving = true);
    try {
      await ref.read(revisionRepositoryProvider).review(card.id, rating);
      if (!mounted) return;
      setState(() {
        _ratings.update(rating, (n) => n + 1, ifAbsent: () => 1);
        _index++;
        _revealed = false;
      });
    } on Object catch (error, stack) {
      logError('Saving a card review failed', error, stack);
      messenger.showSnackBar(SnackBar(content: Text(l10n.revisionSaveError)));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final queue = _queue;
    final Widget body;
    if (_loadError != null) {
      body = EmptyState(
        icon: Icons.error_outline,
        title: l10n.revisionLoadError,
        action: OutlinedButton(onPressed: _load, child: Text(l10n.retry)),
      );
    } else if (queue == null) {
      body = const Center(child: CircularProgressIndicator());
    } else if (queue.isEmpty) {
      body = EmptyState(icon: Icons.task_alt, title: l10n.revisionNothingDue);
    } else if (_index >= queue.length) {
      body = _Summary(reviewed: queue.length, ratings: _ratings);
    } else {
      body = _CardView(
        card: queue[_index],
        position: _index + 1,
        total: queue.length,
        revealed: _revealed,
        saving: _saving,
        onReveal: () => setState(() => _revealed = true),
        onRate: (rating) => _rate(queue[_index], rating),
      );
    }
    return Scaffold(
      appBar: AppBar(title: Text(l10n.revisionReviewTitle)),
      body: SafeArea(child: body),
    );
  }
}

class _CardView extends ConsumerWidget {
  const _CardView({
    required this.card,
    required this.position,
    required this.total,
    required this.revealed,
    required this.saving,
    required this.onReveal,
    required this.onRate,
  });

  final RevisionCard card;
  final int position;
  final int total;
  final bool revealed;
  final bool saving;
  final VoidCallback onReveal;
  final ValueChanged<RecallRating> onRate;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final settings = ref.watch(revisionSettingsProvider).value ?? const RevisionSettings();
    final gaps = RevisionScheduler.previewGaps(card.schedule, settings);
    final heading = [card.subject, card.topic].whereType<String>().join(' › ');

    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: AppSpacing.maxContentWidth),
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.md),
          children: [
            Text(l10n.revisionCardPosition(position, total), style: theme.textTheme.labelLarge),
            const SizedBox(height: AppSpacing.xs),
            LinearProgressIndicator(value: (position - 1) / total),
            const SizedBox(height: AppSpacing.md),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.xs,
              children: [
                CardOriginChip(card: card),
                if (card.reason == CardReason.incorrectAnswer)
                  Chip(
                    avatar: const Icon(Icons.replay, size: 18),
                    label: Text(l10n.cardReasonIncorrect),
                    visualDensity: VisualDensity.compact,
                  ),
              ],
            ),
            if (heading.isNotEmpty) MutedText(heading),
            const SizedBox(height: AppSpacing.md),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: SelectableText(card.front, style: theme.textTheme.titleMedium),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            if (!revealed)
              FilledButton(onPressed: onReveal, child: Text(l10n.revisionShowAnswer))
            else ...[
              Text(
                card.kind == CardKind.question ? l10n.revisionAnswer : l10n.fieldNotes,
                style: theme.textTheme.labelLarge,
              ),
              const SizedBox(height: AppSpacing.xs),
              Card(
                color: theme.colorScheme.secondaryContainer,
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: card.back.trim().isEmpty
                      ? Text(l10n.revisionNoNotes)
                      : SelectableText(card.back, style: theme.textTheme.bodyLarge),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(l10n.revisionHowWell, style: theme.textTheme.titleSmall),
              const SizedBox(height: AppSpacing.sm),
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: AppSpacing.sm,
                crossAxisSpacing: AppSpacing.sm,
                childAspectRatio: 2.6,
                children: [
                  for (final rating in RecallRating.values)
                    _RatingButton(
                      label: ratingLabel(l10n, rating),
                      next: formatGap(l10n, gaps[rating]!),
                      emphasised: rating == RecallRating.good,
                      onPressed: saving ? null : () => onRate(rating),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _RatingButton extends StatelessWidget {
  const _RatingButton({
    required this.label,
    required this.next,
    required this.emphasised,
    required this.onPressed,
  });

  final String label;
  final String next;
  final bool emphasised;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final child = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label),
        Text(next, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
    return emphasised
        ? FilledButton(onPressed: onPressed, child: child)
        : OutlinedButton(onPressed: onPressed, child: child);
  }
}

class _Summary extends StatelessWidget {
  const _Summary({required this.reviewed, required this.ratings});

  final int reviewed;
  final Map<RecallRating, int> ratings;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return EmptyState(
      icon: Icons.celebration_outlined,
      title: l10n.revisionDone(reviewed),
      message: [
        for (final rating in RecallRating.values)
          if ((ratings[rating] ?? 0) > 0) '${ratingLabel(l10n, rating)}: ${ratings[rating]}',
      ].join(' · '),
      action: FilledButton(
        onPressed: () => Navigator.of(context).maybePop(),
        child: Text(l10n.done),
      ),
    );
  }
}
