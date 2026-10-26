import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../core/localization/generated/app_localizations.dart';
import '../../../core/utils/clock.dart';
import '../../revision/application/revision_providers.dart';
import '../../study_plan/application/study_profile_controller.dart';
import '../application/focus_controller.dart';
import '../domain/focus.dart';
import '../domain/quotes.dart';
import '../domain/recall.dart';
import 'recall_check.dart';
import '../../concepts/presentation/concept_form_screen.dart' show ConceptPrefill;

String _clockText(Duration left) {
  final minutes = left.inMinutes;
  final seconds = left.inSeconds % 60;
  return '$minutes:${seconds.toString().padLeft(2, '0')}';
}

/// Choose a length and one task, then focus. Learning-science tip included.
Future<void> showFocusStart(BuildContext context, WidgetRef ref) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  showDragHandle: true,
  builder: (context) => const _FocusStartSheet(),
);

class _FocusStartSheet extends ConsumerStatefulWidget {
  const _FocusStartSheet();

  @override
  ConsumerState<_FocusStartSheet> createState() => _FocusStartSheetState();
}

class _FocusStartSheetState extends ConsumerState<_FocusStartSheet> {
  int _minutes = FocusRules.defaultMinutes;

  Future<void> _start(String route) async {
    final router = GoRouter.of(context);
    Navigator.of(context).pop();
    await ref.read(focusProvider.notifier).start(_minutes);
    router.go(route);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(AppSpacing.md, 0, AppSpacing.md, AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.focusStartTitle, style: theme.textTheme.titleLarge),
            const SizedBox(height: AppSpacing.md),
            Text(l10n.focusMinutesLabel, style: theme.textTheme.titleSmall),
            const SizedBox(height: AppSpacing.xs),
            Wrap(
              spacing: AppSpacing.sm,
              children: [
                for (final m in FocusRules.presets)
                  ChoiceChip(
                    label: Text(l10n.focusMinutes(m)),
                    selected: _minutes == m,
                    onSelected: (_) => setState(() => _minutes = m),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Text(l10n.focusWhatLabel, style: theme.textTheme.titleSmall),
            for (final (icon, label, route) in [
              (Icons.style_outlined, l10n.focusDoRevision, AppRoutes.revision),
              (Icons.quiz_outlined, l10n.focusDoPractice, AppRoutes.practice),
              (Icons.menu_book_outlined, l10n.focusDoStudy, AppRoutes.study),
            ])
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(icon, color: theme.colorScheme.primary),
                title: Text(label),
                trailing: const Icon(Icons.play_arrow),
                onTap: () => _start(route),
              ),
            const SizedBox(height: AppSpacing.sm),
            Text(l10n.focusTip, style: theme.textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}

/// While a focus session runs: a slim bar above every screen with the time left and a way to
/// end it. When the time is up it records the minutes and congratulates the learner.
/// Lives above the router's Navigator, so dialogs go through [dialogContext].
class FocusBar extends ConsumerStatefulWidget {
  const FocusBar({super.key, required this.dialogContext});

  final BuildContext? Function() dialogContext;

  @override
  ConsumerState<FocusBar> createState() => _FocusBarState();
}

class _FocusBarState extends ConsumerState<FocusBar> {
  Timer? _tick;
  bool _finishing = false;

  @override
  void initState() {
    super.initState();
    ref.listenManual(focusProvider, (_, next) => _syncTimer(next), fireImmediately: true);
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  void _syncTimer(FocusSession? session) {
    if (session == null) {
      _tick?.cancel();
      _tick = null;
    } else {
      _tick ??= Timer.periodic(const Duration(seconds: 1), (_) => _onTick());
    }
  }

  void _onTick() {
    final session = ref.read(focusProvider);
    if (session == null || !mounted) return;
    if (session.isOver(ref.read(clockProvider)()) && !_finishing) {
      _finish();
    } else {
      setState(() {});
    }
  }

  Future<void> _finish() async {
    _finishing = true;
    final minutes = await ref.read(focusProvider.notifier).end();
    _finishing = false;
    await _congratulate(minutes);
  }

  /// The done dialog, then (if the learner wants) a recall check of what they studied.
  Future<void> _congratulate(int minutes) async {
    final context = widget.dialogContext();
    if (context == null || !context.mounted) return;
    final recall = await showDialog<bool>(
      context: context,
      builder: (context) => FocusDoneDialog(minutes: minutes),
    );
    if (recall != true || !context.mounted) return;
    final router = GoRouter.of(context);
    final result = await showRecallCheck(context);
    if (result == null) return;
    await ref.read(recallLogProvider.notifier).add(ref.read(todayProvider), 1);
    if (result.saveAsConcept) {
      await router.push(AppRoutes.newConcept, extra: ConceptPrefill(notes: result.notes));
    }
  }

  Future<void> _endEarly() async {
    final context = widget.dialogContext();
    final session = ref.read(focusProvider);
    if (context == null || session == null) return;
    final l10n = AppLocalizations.of(context);
    final focused = session.elapsedMinutes(ref.read(clockProvider)());
    final end = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.focusEndTitle),
        content: Text(l10n.focusEndBody(focused)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.focusKeepGoing),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.focusEnd),
          ),
        ],
      ),
    );
    if (end != true) return;
    final minutes = await ref.read(focusProvider.notifier).end();
    // Long enough to have learned something: offer the recall check too.
    if (minutes >= RecallRules.minMinutes) await _congratulate(minutes);
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(focusProvider);
    if (session == null) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final now = ref.watch(clockProvider)();
    final left = session.remaining(now);
    final total = session.minutes * 60;
    return Material(
      color: theme.colorScheme.primaryContainer,
      child: SafeArea(
        bottom: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              child: Row(
                children: [
                  Icon(Icons.center_focus_strong, color: theme.colorScheme.onPrimaryContainer),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      l10n.focusBarLeft(_clockText(left)),
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: theme.colorScheme.onPrimaryContainer,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ),
                  TextButton(onPressed: _endEarly, child: Text(l10n.focusEnd)),
                ],
              ),
            ),
            LinearProgressIndicator(
              value: total == 0 ? 0 : 1 - left.inSeconds / total,
              minHeight: 3,
              semanticsLabel: l10n.focusBarLeft(_clockText(left)),
            ),
          ],
        ),
      ),
    );
  }
}

/// Shown when a focus session finishes: the minutes, today's total against the goal, a quote.
class FocusDoneDialog extends ConsumerWidget {
  const FocusDoneDialog({super.key, required this.minutes});

  final int minutes;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final today = ref.watch(todayProvider);
    final done = ref.watch(focusLogProvider)[today] ?? 0;
    final goal = ref.watch(studyProfileProvider).dailyStudyMinutes;
    final quote = quoteFor(today);
    final hindi = Localizations.localeOf(context).languageCode == 'hi';
    return AlertDialog(
      icon: const Icon(Icons.emoji_events_outlined, size: 40),
      title: Text(l10n.focusDoneTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.focusDoneBody(minutes)),
          const SizedBox(height: AppSpacing.xs),
          Text(l10n.recallOffer),
          const SizedBox(height: AppSpacing.sm),
          Text(switch (goal) {
            null => l10n.focusDoneTodayNoGoal(done),
            final g when done >= g => l10n.focusDoneGoal(done, g),
            final g => l10n.focusDoneToday(done, g),
          }, style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: AppSpacing.md),
          Text(
            '"${hindi ? quote.hi : quote.en}"',
            style: const TextStyle(fontStyle: FontStyle.italic),
          ),
          Text('— ${quote.author}', style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(l10n.focusDoneOk),
        ),
        FilledButton.icon(
          icon: const Icon(Icons.psychology_outlined),
          onPressed: () => Navigator.of(context).pop(true),
          label: Text(l10n.recallStart),
        ),
      ],
    );
  }
}

/// Home: streak, today's focus against the goal, today's real counts, and one big button.
class MomentumCard extends ConsumerWidget {
  const MomentumCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final progress = ref.watch(todayProgressProvider);
    final goal = ref.watch(studyProfileProvider).dailyStudyMinutes;
    final session = ref.watch(focusProvider);
    final share = goal == null || goal == 0
        ? null
        : (progress.focusMinutes / goal).clamp(0, 1).toDouble();
    return Card(
      color: theme.colorScheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                SizedBox.square(
                  dimension: 72,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox.expand(
                        child: CircularProgressIndicator(
                          value: share ?? 0,
                          strokeWidth: 7,
                          backgroundColor: theme.colorScheme.surface,
                        ),
                      ),
                      Text(
                        '${progress.focusMinutes}',
                        style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.local_fire_department,
                            color: progress.streak > 0 ? Colors.deepOrange : theme.disabledColor,
                          ),
                          const SizedBox(width: AppSpacing.xs),
                          Flexible(
                            child: Text(
                              l10n.momentumStreak(progress.streak),
                              style: theme.textTheme.titleMedium,
                            ),
                          ),
                        ],
                      ),
                      Text(
                        goal == null
                            ? l10n.momentumNoGoal(progress.focusMinutes)
                            : l10n.momentumGoal(progress.focusMinutes, goal),
                      ),
                      Text(
                        [
                          if (progress.answered != null) l10n.momentumAnswered(progress.answered!),
                          l10n.momentumReviewed(progress.reviewed),
                          if (progress.recallChecks > 0)
                            l10n.momentumRecallChecks(progress.recallChecks),
                        ].join(' · '),
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            SizedBox(
              width: double.infinity,
              child: session == null
                  ? FilledButton.icon(
                      icon: const Icon(Icons.center_focus_strong),
                      label: Text(l10n.momentumStart),
                      onPressed: () => showFocusStart(context, ref),
                    )
                  : FilledButton.tonalIcon(
                      icon: const Icon(Icons.timer_outlined),
                      label: Text(
                        l10n.momentumRunning(
                          _clockText(session.remaining(ref.watch(clockProvider)())),
                        ),
                      ),
                      onPressed: null,
                    ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Row(
              children: [
                Expanded(child: Text(l10n.momentumStreakRule, style: theme.textTheme.bodySmall)),
                if (goal == null)
                  TextButton(
                    // Readable on the card's colour (the default link colour is too close).
                    style: TextButton.styleFrom(
                      foregroundColor: theme.colorScheme.onPrimaryContainer,
                      textStyle: const TextStyle(decoration: TextDecoration.underline),
                    ),
                    onPressed: () => context.go(AppRoutes.profile),
                    child: Text(l10n.momentumSetGoal),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// A short, well-attributed quotation; a new one each day, or another on request.
class QuoteCard extends ConsumerStatefulWidget {
  const QuoteCard({super.key});

  @override
  ConsumerState<QuoteCard> createState() => _QuoteCardState();
}

class _QuoteCardState extends ConsumerState<QuoteCard> {
  int _offset = 0;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final quote = quoteFor(ref.watch(todayProvider), offset: _offset);
    final hindi = Localizations.localeOf(context).languageCode == 'hi';
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.md,
          AppSpacing.sm,
          AppSpacing.xs,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.format_quote, color: theme.colorScheme.primary, size: 28),
            Text(
              hindi ? quote.hi : quote.en,
              style: theme.textTheme.titleMedium?.copyWith(fontStyle: FontStyle.italic),
            ),
            const SizedBox(height: AppSpacing.xs),
            Row(
              children: [
                Expanded(child: Text('— ${quote.author}', style: theme.textTheme.bodyMedium)),
                TextButton(
                  onPressed: () => setState(() => _offset++),
                  child: Text(l10n.quoteAnother),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
