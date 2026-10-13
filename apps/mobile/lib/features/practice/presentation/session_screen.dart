import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/localization/generated/app_localizations.dart';
import '../../../core/utils/clock.dart';
import '../../../core/widgets/empty_state.dart';
import '../../question_bank/presentation/question_widgets.dart';
import '../application/practice_providers.dart';
import '../domain/practice_models.dart';
import 'result_view.dart';

/// A practice session or mock test. Shows the result once the session is submitted.
class SessionScreen extends ConsumerWidget {
  const SessionScreen({super.key, required this.sessionId});

  final String sessionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(sessionControllerProvider(sessionId));
    return switch (state) {
      AsyncData(:final value) when value.session.submitted => Scaffold(
        appBar: AppBar(title: Text(l10n.resultTitle)),
        body: ResultView(session: value.session),
      ),
      AsyncData(:final value) => _SessionBody(sessionId: sessionId, state: value),
      AsyncError(:final error) => Scaffold(
        appBar: AppBar(),
        body: EmptyState(
          icon: Icons.cloud_off,
          title: l10n.sessionLoadError,
          message: error is NetworkFailure || error is TimeoutFailure
              ? l10n.sessionOfflineOpen
              : null,
          action: OutlinedButton(
            onPressed: () => ref.invalidate(sessionControllerProvider(sessionId)),
            child: Text(l10n.retry),
          ),
        ),
      ),
      _ => Scaffold(
        appBar: AppBar(),
        body: const Center(child: CircularProgressIndicator()),
      ),
    };
  }
}

class _SessionBody extends ConsumerWidget {
  const _SessionBody({required this.sessionId, required this.state});

  final String sessionId;
  final SessionState state;

  SessionController _controller(WidgetRef ref) =>
      ref.read(sessionControllerProvider(sessionId).notifier);

  Future<void> _submit(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final unanswered = state.session.items.length - state.session.answeredCount;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.sessionSubmitTitle),
        content: Text(l10n.sessionUnanswered(unanswered)),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: Text(l10n.cancel)),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.sessionSubmit),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _controller(ref).submit();
    } on Object {
      messenger.showSnackBar(SnackBar(content: Text(l10n.sessionSubmitFailed)));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final session = state.session;
    final item = state.item;
    final isMock = session.mode == SessionMode.mock;
    final last = state.current == session.items.length - 1;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.sessionQuestionOf(state.current + 1, session.items.length)),
        actions: [
          if (isMock) _Countdown(sessionId: sessionId, state: state),
          if (item.questionId != null)
            IconButton(
              tooltip: item.bookmarked ? l10n.sessionRemoveBookmark : l10n.sessionBookmark,
              icon: Icon(item.bookmarked ? Icons.bookmark : Icons.bookmark_border),
              onPressed: () => _controller(ref).toggleBookmark(),
            ),
          if (isMock)
            IconButton(
              tooltip: l10n.sessionPalette,
              icon: const Icon(Icons.grid_view),
              onPressed: () => _showPalette(context, ref),
            ),
          TextButton(
            onPressed: state.submitting ? null : () => _submit(context, ref),
            child: Text(isMock ? l10n.sessionSubmit : l10n.sessionFinish),
          ),
        ],
      ),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: AppSpacing.maxContentWidth),
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.md),
            children: [
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.xs,
                children: [
                  if (item.origin != null) OriginChip(origin: item.origin!),
                  if (!item.verified)
                    Chip(
                      visualDensity: VisualDensity.compact,
                      avatar: const Icon(Icons.warning_amber, size: 16),
                      label: Text(l10n.sessionNotReviewed),
                    ),
                  if (item.section != null)
                    Chip(visualDensity: VisualDensity.compact, label: Text(item.section!)),
                ],
              ),
              if (item.sourceFilename != null && item.sourcePage != null)
                Text(
                  l10n.questionSource(item.sourceFilename!, item.sourcePage!),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              if (item.passage != null) ...[
                const SizedBox(height: AppSpacing.sm),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: SelectableText(item.passage!.text),
                  ),
                ),
              ],
              const SizedBox(height: AppSpacing.md),
              if (item.stem == null)
                Text(l10n.sessionQuestionRemoved)
              else
                SelectableText(item.stem!, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: AppSpacing.md),
              for (final option in item.options)
                _OptionTile(
                  label: option.label,
                  text: option.text,
                  selected: item.selectedPosition == option.position,
                  correct: item.feedback?.correctPosition == option.position,
                  showFeedback: item.feedback != null,
                  onTap: () => _controller(ref).select(option.position),
                ),
              if (state.queuedPositions.contains(item.position)) ...[
                const SizedBox(height: AppSpacing.sm),
                Row(
                  children: [
                    const Icon(Icons.cloud_upload_outlined, size: 18),
                    const SizedBox(width: AppSpacing.xs),
                    Expanded(
                      child: Text(isMock ? l10n.sessionSavedOffline : l10n.sessionFeedbackOffline),
                    ),
                  ],
                ),
              ],
              if (item.feedback != null) _FeedbackPanel(item: item),
            ],
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            children: [
              OutlinedButton(
                onPressed: state.current == 0
                    ? null
                    : () => _controller(ref).goTo(state.current - 1),
                child: Text(l10n.sessionPrevious),
              ),
              const Spacer(),
              if (last)
                FilledButton(
                  onPressed: state.submitting ? null : () => _submit(context, ref),
                  child: Text(isMock ? l10n.sessionSubmit : l10n.sessionFinish),
                )
              else
                FilledButton(
                  onPressed: () => _controller(ref).goTo(state.current + 1),
                  child: Text(l10n.sessionNext),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _showPalette(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.md, 0, AppSpacing.md, AppSpacing.md),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l10n.sessionPalette, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: AppSpacing.xs,
                runSpacing: AppSpacing.xs,
                children: [
                  for (final (index, item) in state.session.items.indexed)
                    ChoiceChip(
                      label: Text('${index + 1}'),
                      selected: item.selectedPosition != null,
                      onSelected: (_) {
                        Navigator.of(sheetContext).pop();
                        _controller(ref).goTo(index);
                      },
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OptionTile extends StatelessWidget {
  const _OptionTile({
    required this.label,
    required this.text,
    required this.selected,
    required this.correct,
    required this.showFeedback,
    required this.onTap,
  });

  final String label;
  final String text;
  final bool selected;
  final bool correct;
  final bool showFeedback;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final (background, icon) = switch ((showFeedback, selected, correct)) {
      (true, _, true) => (colors.primaryContainer, Icons.check_circle),
      (true, true, false) => (colors.errorContainer, Icons.cancel),
      (false, true, _) => (colors.secondaryContainer, Icons.radio_button_checked),
      _ => (null, Icons.radio_button_unchecked),
    };
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Semantics(
        selected: selected,
        button: true,
        child: Card(
          color: background,
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Row(
                children: [
                  Icon(icon),
                  const SizedBox(width: AppSpacing.sm),
                  Text('($label)  ', style: const TextStyle(fontWeight: FontWeight.bold)),
                  Expanded(child: Text(text)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FeedbackPanel extends StatelessWidget {
  const _FeedbackPanel({required this.item});

  final SessionItemView item;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final feedback = item.feedback!;
    final correctLabel =
        item.options.where((o) => o.position == feedback.correctPosition).firstOrNull?.label ??
        '${feedback.correctPosition}';
    return Card(
      margin: const EdgeInsets.only(top: AppSpacing.sm),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (feedback.isCorrect != null)
              Text(
                feedback.isCorrect! ? l10n.sessionCorrect : l10n.sessionIncorrect,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: feedback.isCorrect!
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).colorScheme.error,
                ),
              ),
            Text(l10n.sessionCorrectAnswer(correctLabel)),
            if (feedback.explanation != null && feedback.explanation!.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.sm),
              SelectableText(feedback.explanation!),
            ],
          ],
        ),
      ),
    );
  }
}

/// Mock-test countdown from the server deadline. Submits (idempotently) at zero.
class _Countdown extends ConsumerStatefulWidget {
  const _Countdown({required this.sessionId, required this.state});

  final String sessionId;
  final SessionState state;

  @override
  ConsumerState<_Countdown> createState() => _CountdownState();
}

class _CountdownState extends ConsumerState<_Countdown> {
  Timer? _ticker;
  bool _submitting = false;
  DateTime? _retryAfter;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  void _tick() {
    if (!mounted) return;
    setState(() {});
    final left = widget.state.remainingSeconds(ref.read(clockProvider)());
    final now = DateTime.now();
    if (left == 0 && !_submitting && (_retryAfter == null || now.isAfter(_retryAfter!))) {
      _submitting = true;
      _submitOnTimeUp();
    }
  }

  Future<void> _submitOnTimeUp() async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(sessionControllerProvider(widget.sessionId).notifier).submit();
      messenger.showSnackBar(SnackBar(content: Text(l10n.sessionTimeUp)));
    } on Object {
      // Offline: answers stay queued and the server treats its deadline as final. Retry
      // shortly; opening the session again also shows the submitted result.
      _retryAfter = DateTime.now().add(const Duration(seconds: 15));
      _submitting = false;
    }
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final left = widget.state.remainingSeconds(ref.watch(clockProvider)()) ?? 0;
    final text = formatClock(left);
    final urgent = left <= 300;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
      child: Center(
        child: Semantics(
          label: l10n.sessionTimeLeft(text),
          child: Text(
            text,
            style: TextStyle(
              fontFeatures: const [FontFeature.tabularFigures()],
              fontWeight: FontWeight.bold,
              color: urgent ? Theme.of(context).colorScheme.error : null,
            ),
          ),
        ),
      ),
    );
  }
}

/// 3725 -> "1:02:05", 125 -> "02:05".
String formatClock(int seconds) {
  final h = seconds ~/ 3600;
  final m = (seconds % 3600) ~/ 60;
  final s = seconds % 60;
  String two(int v) => v.toString().padLeft(2, '0');
  return h > 0 ? '$h:${two(m)}:${two(s)}' : '${two(m)}:${two(s)}';
}
