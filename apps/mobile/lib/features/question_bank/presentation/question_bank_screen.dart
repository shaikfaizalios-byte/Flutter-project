import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../core/widgets/search_field.dart';
import '../../../core/localization/generated/app_localizations.dart';
import '../../../core/widgets/empty_state.dart';
import '../application/question_bank_providers.dart';
import 'question_widgets.dart';

/// Browse and review the question bank (opened from the Practice tab).
class QuestionBankScreen extends ConsumerWidget {
  const QuestionBankScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final query = ref.watch(bankQueryProvider);
    final controller = ref.read(bankQueryProvider.notifier);
    final questions = ref.watch(questionListProvider(query));

    return Scaffold(
      appBar: AppBar(title: Text(l10n.bankTitle)),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: AppSpacing.maxContentWidth),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.sm, AppSpacing.md, 0),
                child: AppSearchField(hintText: l10n.bankSearchHint, onChanged: controller.setText),
              ),
              ReviewFilterBar(
                selected: reviewFilterOf(query).index,
                onSelected: (i) => controller.setReviewFilter(ReviewFilter.values[i]),
              ),
              Expanded(
                child: switch (questions) {
                  AsyncData(value: (final items, _))
                      when items.isEmpty &&
                          query.text.isEmpty &&
                          query.status == null &&
                          query.hasIssues == null =>
                    EmptyState(
                      icon: Icons.quiz_outlined,
                      title: l10n.bankEmptyTitle,
                      message: l10n.bankEmptyMessage,
                    ),
                  AsyncData(value: (final items, _)) when items.isEmpty => EmptyState(
                    icon: Icons.search_off,
                    title: l10n.reviewNoQuestions,
                  ),
                  AsyncData(value: (final items, _)) => ListView.separated(
                    itemCount: items.length,
                    separatorBuilder: (context, index) => const Divider(height: 1),
                    itemBuilder: (context, index) => QuestionTile(question: items[index]),
                  ),
                  AsyncError() => EmptyState(
                    icon: Icons.cloud_off,
                    title: l10n.documentsOfflineTitle,
                    message: l10n.bankLoadError,
                    action: OutlinedButton(
                      onPressed: () => ref.invalidate(questionListProvider(query)),
                      child: Text(l10n.retry),
                    ),
                  ),
                  _ => const Center(child: CircularProgressIndicator()),
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
