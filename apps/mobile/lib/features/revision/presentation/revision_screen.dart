import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../app/routes.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../core/localization/generated/app_localizations.dart';
import '../../../core/utils/app_log.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/section_card.dart';
import '../application/revision_providers.dart';
import '../domain/revision_card.dart';
import '../domain/revision_schedule.dart';
import 'revision_widgets.dart';

/// Revision hub: what is due, the next 7 days, the ladder, and every card.
class RevisionScreen extends ConsumerWidget {
  const RevisionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final cards = ref.watch(revisionCardsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.revisionTitle),
        actions: [
          IconButton(
            tooltip: l10n.revisionScheduleTitle,
            icon: const Icon(Icons.tune),
            onPressed: () => showRevisionScheduleSheet(context),
          ),
        ],
      ),
      body: switch (cards) {
        AsyncData(:final value) when value.isEmpty => EmptyState(
          icon: Icons.style_outlined,
          title: l10n.revisionEmptyTitle,
          message: l10n.revisionEmptyMessage,
        ),
        AsyncData(:final value) => _RevisionBody(cards: value),
        AsyncError() => EmptyState(
          icon: Icons.error_outline,
          title: l10n.revisionLoadError,
          action: OutlinedButton(
            onPressed: () => ref.invalidate(revisionCardsProvider),
            child: Text(l10n.retry),
          ),
        ),
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }
}

class _RevisionBody extends ConsumerWidget {
  const _RevisionBody({required this.cards});

  final List<RevisionCard> cards;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final today = ref.watch(todayProvider);
    final overview = RevisionOverview.of(cards, today);
    final settings = ref.watch(revisionSettingsProvider).value ?? const RevisionSettings();
    final locale = Localizations.localeOf(context).toLanguageTag();

    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: AppSpacing.maxContentWidth),
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.md),
          children: [
            SectionCard(
              icon: Icons.today_outlined,
              title: l10n.revisionDueTitle,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (overview.dueToday > 0) ...[
                    Text(
                      l10n.revisionDueCount(overview.dueToday),
                      style: theme.textTheme.titleLarge,
                    ),
                    if (overview.overdue > 0)
                      MutedText(l10n.revisionOverdueCount(overview.overdue)),
                    const SizedBox(height: AppSpacing.sm),
                    FilledButton.icon(
                      icon: const Icon(Icons.play_arrow),
                      label: Text(l10n.revisionStart),
                      onPressed: () => context.push(AppRoutes.revisionReview),
                    ),
                  ] else ...[
                    Text(l10n.revisionNothingDue),
                    if (overview.nextDue != null)
                      MutedText(
                        l10n.revisionNextReview(formatDue(context, today, overview.nextDue!)),
                      ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            SectionCard(
              icon: Icons.date_range_outlined,
              title: l10n.revisionUpcomingTitle,
              child: Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.xs,
                children: [
                  for (final (i, count) in overview.upcoming.indexed)
                    Chip(
                      label: Text(
                        '${DateFormat.E(locale).format(today.addDays(i + 1).toLocalDateTime())}'
                        ' · $count',
                      ),
                      visualDensity: VisualDensity.compact,
                    ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            SectionCard(
              icon: Icons.stairs_outlined,
              title: l10n.revisionScheduleTitle,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l10n.revisionLadder(settings.dayOffsets.join(' · '))),
                  MutedText(l10n.revisionLadderExplanation),
                  Align(
                    alignment: AlignmentDirectional.centerEnd,
                    child: TextButton(
                      onPressed: () => showRevisionScheduleSheet(context),
                      child: Text(l10n.revisionEditSchedule),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(l10n.revisionAllCards(overview.total), style: theme.textTheme.titleMedium),
            for (final card in cards) _CardTile(card: card),
          ],
        ),
      ),
    );
  }
}

class _CardTile extends ConsumerWidget {
  const _CardTile({required this.card});

  final RevisionCard card;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final today = ref.watch(todayProvider);
    final firstLine = card.front.split('\n').first;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(
        card.kind == CardKind.concept ? Icons.edit_note : Icons.picture_as_pdf_outlined,
        semanticLabel: card.kind == CardKind.concept ? l10n.cardOriginNotes : l10n.cardOriginPaper,
      ),
      title: Text(firstLine, maxLines: 2, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        [
          formatDue(context, today, card.dueOn),
          if (card.reason == CardReason.incorrectAnswer) l10n.cardReasonIncorrect,
        ].join(' · '),
      ),
      trailing: IconButton(
        tooltip: l10n.revisionRemove,
        icon: const Icon(Icons.remove_circle_outline),
        onPressed: () async {
          final messenger = ScaffoldMessenger.of(context);
          try {
            await ref.read(revisionRepositoryProvider).removeCard(card.id);
            messenger.showSnackBar(SnackBar(content: Text(l10n.revisionRemoved)));
          } on Object catch (error, stack) {
            logError('Removing a revision card failed', error, stack);
            messenger.showSnackBar(SnackBar(content: Text(l10n.revisionSaveError)));
          }
        },
      ),
    );
  }
}

/// Edits the review-day ladder (e.g. "1, 4, 7").
Future<void> showRevisionScheduleSheet(BuildContext context) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  showDragHandle: true,
  builder: (context) => const _ScheduleSheet(),
);

class _ScheduleSheet extends ConsumerStatefulWidget {
  const _ScheduleSheet();

  @override
  ConsumerState<_ScheduleSheet> createState() => _ScheduleSheetState();
}

class _ScheduleSheetState extends ConsumerState<_ScheduleSheet> {
  final _controller = TextEditingController();
  bool _invalid = false;
  bool _loaded = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save(List<int> offsets) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    try {
      await ref
          .read(revisionRepositoryProvider)
          .saveSettings(RevisionSettings(dayOffsets: offsets));
      navigator.pop();
      messenger.showSnackBar(SnackBar(content: Text(l10n.revisionScheduleSaved)));
    } on Object catch (error, stack) {
      logError('Saving the revision schedule failed', error, stack);
      messenger.showSnackBar(SnackBar(content: Text(l10n.revisionSaveError)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final settings = ref.watch(revisionSettingsProvider).value;
    if (!_loaded && settings != null) {
      _controller.text = settings.dayOffsets.join(', ');
      _loaded = true;
    }
    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.lg,
        0,
        AppSpacing.lg,
        AppSpacing.lg + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.revisionScheduleTitle, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: AppSpacing.sm),
          Text(l10n.revisionScheduleHelp),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: _controller,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9, ]'))],
            decoration: InputDecoration(
              labelText: l10n.revisionScheduleField,
              helperText: l10n.revisionScheduleFieldHint,
              errorText: _invalid
                  ? l10n.revisionScheduleInvalid(RevisionSettings.maxSteps, RevisionSettings.maxDay)
                  : null,
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              TextButton(
                onPressed: () => _save(RevisionSettings.defaultDayOffsets),
                child: Text(l10n.revisionScheduleReset),
              ),
              const Spacer(),
              FilledButton(
                onPressed: () {
                  final values = _controller.text
                      .split(RegExp(r'[,\s]+'))
                      .where((s) => s.isNotEmpty)
                      .map(int.tryParse);
                  final offsets = values.contains(null)
                      ? null
                      : RevisionSettings.normalize(values.cast<int>());
                  if (offsets == null) {
                    setState(() => _invalid = true);
                  } else {
                    _save(offsets);
                  }
                },
                child: Text(l10n.save),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
