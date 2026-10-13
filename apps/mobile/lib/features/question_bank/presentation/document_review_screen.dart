import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/localization/generated/app_localizations.dart';
import '../../../core/utils/app_log.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/section_card.dart';
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
          IconButton(
            tooltip: l10n.reviewReparse,
            icon: _reparsing
                ? const SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh),
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
                    AsyncData(:final value) => _SummaryCard(summary: value),
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
