import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/localization/generated/app_localizations.dart';
import '../../../core/utils/app_log.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/section_card.dart';
import '../../ai/application/ai_providers.dart';
import '../../documents/presentation/documents_screen.dart' show uploadErrorMessage;
import '../application/question_bank_providers.dart';
import '../data/questions_repository.dart';
import '../domain/question.dart';
import 'question_widgets.dart';

/// Parse summary and question list for one imported document.
class DocumentReviewScreen extends ConsumerStatefulWidget {
  const DocumentReviewScreen({super.key, required this.documentId});

  final String documentId;

  @override
  ConsumerState<DocumentReviewScreen> createState() => _DocumentReviewScreenState();
}

class _DocumentReviewScreenState extends ConsumerState<DocumentReviewScreen> {
  ReviewFilter _filter = ReviewFilter.all;
  bool _reparsing = false;

  QuestionQuery get _query => QuestionQuery(
    documentId: widget.documentId,
    status: switch (_filter) {
      ReviewFilter.verified => VerificationStatus.verified,
      ReviewFilter.rejected => VerificationStatus.rejected,
      ReviewFilter.needsAttention => VerificationStatus.unverified,
      ReviewFilter.all => null,
    },
    hasIssues: _filter == ReviewFilter.needsAttention ? true : null,
  );

  Future<void> _reparse() async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _reparsing = true);
    try {
      await ref.read(questionsRepositoryProvider).resegment(widget.documentId);
      ref
        ..invalidate(parseSummaryProvider(widget.documentId))
        ..invalidate(questionListProvider);
      messenger.showSnackBar(SnackBar(content: Text(l10n.reviewReparsed)));
    } on AppFailure catch (failure) {
      messenger.showSnackBar(SnackBar(content: Text(uploadErrorMessage(l10n, failure))));
    } on Object catch (error, stack) {
      logError('Re-parsing failed', error, stack);
    } finally {
      if (mounted) setState(() => _reparsing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final summary = ref.watch(parseSummaryProvider(widget.documentId));
    final questions = ref.watch(questionListProvider(_query));

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.reviewTitle),
        actions: [
          TextButton.icon(
            icon: _reparsing
                ? const SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh),
            label: Text(l10n.reviewReparse),
            onPressed: _reparsing ? null : _reparse,
          ),
        ],
      ),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: AppSpacing.maxContentWidth),
          child: RefreshIndicator(
            onRefresh: () async {
              ref
                ..invalidate(parseSummaryProvider(widget.documentId))
                ..invalidate(questionListProvider);
            },
            child: CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: switch (summary) {
                    AsyncData(:final value) => Column(
                      children: [
                        _SummaryCard(summary: value),
                        if (value.segmentationStatus == 'completed' && value.questionsFound > 0)
                          _TopicsCard(documentId: widget.documentId, summary: value),
                      ],
                    ),
                    AsyncError() => Padding(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      child: Text(l10n.bankLoadError),
                    ),
                    _ => const LinearProgressIndicator(),
                  },
                ),
                SliverToBoxAdapter(
                  child: ReviewFilterBar(
                    selected: _filter.index,
                    onSelected: (i) => setState(() => _filter = ReviewFilter.values[i]),
                  ),
                ),
                switch (questions) {
                  AsyncData(value: (final items, _)) when items.isEmpty => SliverFillRemaining(
                    hasScrollBody: false,
                    child: EmptyState(icon: Icons.inbox_outlined, title: l10n.reviewNoQuestions),
                  ),
                  AsyncData(value: (final items, _)) => SliverList.separated(
                    itemCount: items.length,
                    separatorBuilder: (context, index) => const Divider(height: 1),
                    itemBuilder: (context, index) => QuestionTile(question: items[index]),
                  ),
                  AsyncError() => SliverFillRemaining(
                    hasScrollBody: false,
                    child: EmptyState(
                      icon: Icons.cloud_off,
                      title: l10n.bankLoadError,
                      action: OutlinedButton(
                        onPressed: () => ref.invalidate(questionListProvider(_query)),
                        child: Text(l10n.retry),
                      ),
                    ),
                  ),
                  _ => const SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(child: CircularProgressIndicator()),
                  ),
                },
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.summary});

  final ParseSummary summary;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: SectionCard(
        icon: Icons.fact_check_outlined,
        title: switch (summary.segmentationStatus) {
          'pending' => l10n.reviewSegmentationPending,
          'failed' => l10n.reviewSegmentationFailed,
          _ => l10n.documentQuestionsFound(summary.questionsFound),
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (summary.segmentationStatus == 'completed')
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.xs,
                children: [
                  Chip(label: Text(l10n.reviewSummaryVerified(summary.verified))),
                  Chip(label: Text(l10n.reviewSummaryAttention(summary.withOpenIssues))),
                  Chip(label: Text(l10n.reviewSummaryMissingAnswers(summary.missingAnswers))),
                  if (summary.withFigures > 0)
                    Chip(label: Text(l10n.reviewSummaryFigures(summary.withFigures))),
                  if (summary.unreadableText > 0)
                    Chip(label: Text(l10n.reviewSummaryUnreadable(summary.unreadableText))),
                ],
              ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              summary.formatName == null
                  ? l10n.reviewFormatUnknown
                  : l10n.reviewFormat(summary.formatName!),
              style: theme.textTheme.bodySmall,
            ),
            for (final issue in summary.documentIssues) ...[
              const SizedBox(height: AppSpacing.xs),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.warning_amber, size: 18, color: theme.colorScheme.tertiary),
                  const SizedBox(width: AppSpacing.xs),
                  Expanded(
                    child: Text(
                      issue.detail.isEmpty
                          ? issueLabel(l10n, issue.code)
                          : '${issueLabel(l10n, issue.code)}: ${issue.detail}',
                    ),
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

/// Topic suggestions for the whole paper: accept them all in one step, or ask the AI about
/// the questions the keyword rules couldn't place. Every suggestion stays labelled until
/// accepted, and can be changed on the question afterwards.
class _TopicsCard extends ConsumerStatefulWidget {
  const _TopicsCard({required this.documentId, required this.summary});

  final String documentId;
  final ParseSummary summary;

  @override
  ConsumerState<_TopicsCard> createState() => _TopicsCardState();
}

class _TopicsCardState extends ConsumerState<_TopicsCard> {
  bool _busy = false;
  int? _aiRemaining;

  void _refresh() => ref
    ..invalidate(parseSummaryProvider(widget.documentId))
    ..invalidate(questionListProvider)
    ..invalidate(questionProvider);

  Future<void> _run(Future<void> Function(ScaffoldMessengerState messenger) action) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      await action(messenger);
    } on AppFailure catch (failure) {
      messenger.showSnackBar(SnackBar(content: Text(uploadErrorMessage(l10n, failure))));
    } on Object catch (error, stack) {
      logError('Topic action failed', error, stack);
    } finally {
      _refresh();
      if (mounted) {
        setState(() {
          _busy = false;
          _aiRemaining = null;
        });
      }
    }
  }

  Future<bool> _confirm(String title, String body, String action) async {
    final l10n = AppLocalizations.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: Text(l10n.cancel)),
          FilledButton(onPressed: () => Navigator.of(context).pop(true), child: Text(action)),
        ],
      ),
    );
    return ok ?? false;
  }

  Future<void> _acceptAll() async {
    final l10n = AppLocalizations.of(context);
    if (!await _confirm(
      l10n.topicsAcceptConfirmTitle,
      l10n.topicsAcceptConfirmBody,
      l10n.topicsAcceptAction,
    )) {
      return;
    }
    await _run((messenger) async {
      final accepted = await ref
          .read(questionsRepositoryProvider)
          .acceptSuggestedTopics(widget.documentId);
      messenger.showSnackBar(SnackBar(content: Text(l10n.topicsAccepted(accepted))));
    });
  }

  Future<void> _suggestWithAi() async {
    final l10n = AppLocalizations.of(context);
    if (!await _confirm(
      l10n.topicsAiSuggest(widget.summary.topicsAiPending),
      l10n.topicsAiNotice,
      l10n.topicsAiConfirm,
    )) {
      return;
    }
    await _run((messenger) async {
      final ai = ref.read(aiRepositoryProvider);
      var suggested = 0;
      var noMatch = 0;
      setState(() => _aiRemaining = widget.summary.topicsAiPending);
      // The server handles a few batches per call; keep going until none are left.
      while (mounted) {
        final step = await ai.suggestPaperTopics(widget.documentId);
        suggested += step.suggested;
        noMatch += step.noMatch;
        if (mounted) setState(() => _aiRemaining = step.remaining);
        if (step.remaining == 0 || step.considered == 0) break;
      }
      messenger.showSnackBar(SnackBar(content: Text(l10n.topicsAiDone(suggested, noMatch))));
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final summary = widget.summary;
    final aiEnabled = ref.watch(aiStatusProvider).value?.enabled ?? false;
    final remaining = _aiRemaining;

    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.md, 0, AppSpacing.md, AppSpacing.md),
      child: SectionCard(
        icon: Icons.label_outline,
        title: l10n.topicsCardTitle,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: AppSpacing.sm,
          children: [
            Text(l10n.topicsSummary(summary.topicsSuggested, summary.topicsUnassigned)),
            Text(l10n.topicsRulesNote, style: theme.textTheme.bodySmall),
            if (summary.topicsSuggested > 0)
              FilledButton.tonalIcon(
                icon: const Icon(Icons.done_all),
                label: Text(l10n.topicsAcceptAll(summary.topicsSuggested)),
                onPressed: _busy ? null : _acceptAll,
              ),
            if (aiEnabled && summary.topicsAiPending > 0)
              OutlinedButton.icon(
                icon: const Icon(Icons.auto_awesome),
                label: Text(l10n.topicsAiSuggest(summary.topicsAiPending)),
                onPressed: _busy ? null : _suggestWithAi,
              ),
            if (remaining != null)
              Row(
                spacing: AppSpacing.sm,
                children: [
                  const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  Expanded(child: Text(l10n.topicsAiRunning(remaining))),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
