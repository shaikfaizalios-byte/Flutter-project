import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/localization/generated/app_localizations.dart';
import '../../../core/utils/app_log.dart';
import '../../ai/application/ai_providers.dart';
import '../../ai/presentation/ai_widgets.dart';
import '../application/question_bank_providers.dart';
import '../domain/question.dart';

/// How often the progress of a reading is refreshed.
const aiReadPollInterval = Duration(seconds: 4);

/// Paper review: read the questions with AI when PrepLoop's own reader found none (or the
/// learner thinks they are wrong). Shows the progress while the server reads, and what to
/// check afterwards. Shown only when the server has AI.
class AiReadCard extends ConsumerStatefulWidget {
  const AiReadCard({super.key, required this.documentId, required this.summary});

  final String documentId;
  final ParseSummary summary;

  @override
  ConsumerState<AiReadCard> createState() => _AiReadCardState();
}

class _AiReadCardState extends ConsumerState<AiReadCard> {
  Timer? _poll;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _syncPolling();
  }

  @override
  void didUpdateWidget(AiReadCard old) {
    super.didUpdateWidget(old);
    if (old.summary.aiReadStatus.inProgress && !widget.summary.aiReadStatus.inProgress) {
      // The questions changed. Not during this build: refresh right after the frame.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) ref.invalidate(questionListProvider);
      });
    }
    _syncPolling();
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  void _syncPolling() {
    if (widget.summary.aiReadStatus.inProgress) {
      _poll ??= Timer.periodic(
        aiReadPollInterval,
        (_) => ref.invalidate(parseSummaryProvider(widget.documentId)),
      );
    } else {
      _poll?.cancel();
      _poll = null;
    }
  }

  Future<void> _read() async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.aiReadConfirmTitle),
        content: Text(l10n.aiReadConfirmBody(widget.summary.pageCount)),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: Text(l10n.cancel)),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.aiReadStart),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _busy = true);
    try {
      await ref.read(aiRepositoryProvider).readPaper(widget.documentId);
      ref.invalidate(parseSummaryProvider(widget.documentId));
    } on Object catch (error, stack) {
      if (error is! AppFailure) logError('Queuing an AI reading failed', error, stack);
      messenger.showSnackBar(SnackBar(content: Text(aiErrorMessage(l10n, error))));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final enabled = ref.watch(aiStatusProvider).value?.enabled ?? false;
    final s = widget.summary;
    if (!enabled && s.readByAi == 0 && !s.aiReadStatus.inProgress) return const SizedBox.shrink();
    final nothingFound = s.questionsFound == 0;

    final readButton = FilledButton.tonalIcon(
      icon: const Icon(Icons.auto_awesome),
      label: Text(s.readByAi > 0 ? l10n.aiReadAgain : l10n.aiReadButton),
      onPressed: _busy || !enabled ? null : _read,
    );
    final List<Widget> children = switch (s.aiReadStatus) {
      AiReadStatus.queued || AiReadStatus.running => [
        Text(
          s.aiReadStatus == AiReadStatus.queued
              ? l10n.aiReadQueued
              : l10n.aiReadProgress(s.aiReadPagesDone, s.pageCount),
        ),
        const SizedBox(height: AppSpacing.xs),
        LinearProgressIndicator(
          value: s.pageCount == 0 || s.aiReadStatus == AiReadStatus.queued
              ? null
              : (s.aiReadPagesDone / s.pageCount).clamp(0, 1).toDouble(),
        ),
      ],
      AiReadStatus.failed => [
        Text(l10n.aiReadFailed, style: TextStyle(color: theme.colorScheme.error)),
        const SizedBox(height: AppSpacing.xs),
        readButton,
      ],
      _ when s.readByAi > 0 => [
        AiLabel(l10n.aiReadDoneLabel(s.readByAi)),
        Text(l10n.aiReadDoneMessage, style: theme.textTheme.bodySmall),
        const SizedBox(height: AppSpacing.xs),
        readButton,
      ],
      _ => [
        Text(nothingFound ? l10n.aiReadNothingFound : l10n.aiReadOffer),
        const SizedBox(height: AppSpacing.xs),
        readButton,
        // The confirmation dialog always says so too.
        if (nothingFound) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(l10n.aiReadPrivacy, style: theme.textTheme.bodySmall),
        ],
      ],
    };

    return Card(
      color: nothingFound && s.aiReadStatus == AiReadStatus.none
          ? theme.colorScheme.secondaryContainer
          : null,
      margin: const EdgeInsets.fromLTRB(AppSpacing.md, 0, AppSpacing.md, AppSpacing.sm),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.document_scanner_outlined, color: theme.colorScheme.primary),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Semantics(
                    header: true,
                    child: Text(l10n.aiReadTitle, style: theme.textTheme.titleSmall),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            ...children,
          ],
        ),
      ),
    );
  }
}
