import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../core/localization/generated/app_localizations.dart';
import '../../../core/widgets/web_search_button.dart';
import '../../ai/presentation/search_answer_panel.dart';
import '../../exams/application/active_exam.dart';
import '../../exams/application/exam_catalog_controller.dart';
import '../application/question_bank_providers.dart';
import '../data/questions_repository.dart';
import '../domain/question.dart';
import 'question_widgets.dart';

/// Searches shorter than this aren't sent (too many matches to be useful).
const paperSearchMinLength = 2;
const paperSearchPreview = 3;

/// Questions of the current exam's imported papers that match [text] (every word, anywhere in
/// the question, its options, passage, topic or question type). Waits while the learner is
/// still typing, so each keystroke doesn't ask the server.
final paperQuestionSearchProvider = FutureProvider.autoDispose
    .family<(List<BankQuestion>, int), String>((ref, text) async {
      final exam = ref.watch(activeExamProvider);
      await Future<void>.delayed(const Duration(milliseconds: 350));
      if (!ref.mounted) return (const <BankQuestion>[], 0);
      return ref.watch(questionsRepositoryProvider).list(QuestionQuery(examCode: exam, text: text));
    }, retry: (_, _) => null);

/// "Questions from your papers" for a search or a concept: how many match, the first few,
/// and a way to see them all in the question bank.
class PaperQuestionsCard extends ConsumerWidget {
  const PaperQuestionsCard({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final query = text.trim();
    if (query.length < paperSearchMinLength) return const SizedBox.shrink();
    final exam = ref.watch(activeExamProvider);
    final examName = exam == null ? null : ref.watch(examNameProvider(exam));
    final result = ref.watch(paperQuestionSearchProvider(query));

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.sm,
          AppSpacing.sm,
          AppSpacing.sm,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.quiz_outlined, color: theme.colorScheme.primary),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Semantics(
                    header: true,
                    child: Text(
                      examName == null
                          ? l10n.paperQuestionsTitle
                          : l10n.paperQuestionsTitleExam(examName),
                      style: theme.textTheme.titleSmall,
                    ),
                  ),
                ),
              ],
            ),
            // An AI answer from the learner's own material (RAG) comes first.
            SearchAnswerPanel(query: query),
            switch (result) {
              AsyncData(value: (_, 0)) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.sm),
                    child: Text(l10n.paperQuestionsNone(query), style: theme.textTheme.bodySmall),
                  ),
                  WebSearchButton(query: query, label: l10n.webSearchGoogle),
                ],
              ),
              AsyncData(value: (final items, final total)) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l10n.paperQuestionsCount(total), style: theme.textTheme.bodySmall),
                  for (final q in items.take(paperSearchPreview)) QuestionTile(question: q),
                  Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    children: [
                      // For more understanding than the papers give.
                      WebSearchButton(query: query, label: l10n.webSearchLearnMore),
                      TextButton.icon(
                        icon: const Icon(Icons.arrow_forward),
                        label: Text(l10n.paperQuestionsSeeAll(total)),
                        onPressed: () {
                          ref.read(bankQueryProvider.notifier).setText(query);
                          context.push(AppRoutes.questionBank);
                        },
                      ),
                    ],
                  ),
                ],
              ),
              AsyncError() => Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                child: Text(l10n.paperQuestionsOffline, style: theme.textTheme.bodySmall),
              ),
              _ => const Padding(
                padding: EdgeInsets.symmetric(vertical: AppSpacing.sm),
                child: LinearProgressIndicator(),
              ),
            },
          ],
        ),
      ),
    );
  }
}
