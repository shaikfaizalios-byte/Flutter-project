import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../core/localization/generated/app_localizations.dart';
import '../data/ai_repository.dart';

/// Where a source opens: the paper, the question or the concept.
String? searchSourceRoute(SearchAnswerSource source) => switch (source.kind) {
  SearchSourceKind.page when source.documentId != null => AppRoutes.documentReview(
    source.documentId!,
  ),
  SearchSourceKind.question when source.questionId != null => AppRoutes.question(
    source.questionId!,
  ),
  SearchSourceKind.concept when source.conceptId != null => AppRoutes.concept(source.conceptId!),
  _ => null,
};

/// A topic list or a summary from the learner's material: numbered items, each with the sources
/// it comes from. Says when it covers less than was asked, and that AI wrote it.
class StudyAnswerView extends StatelessWidget {
  const StudyAnswerView({super.key, required this.answer});

  final SearchAnswer answer;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final summary = answer.kind == SearchAnswerKind.summary;
    final requested = answer.requested;
    final read = answer.pagesRead;
    final total = answer.pagesTotal;
    final notes = [
      if (requested != null && answer.items.length < requested)
        l10n.studyTopicsFewer(answer.items.length, requested),
      if (read != null && total != null && read < total) l10n.paperSummaryPartial(read, total),
      if (!answer.confident) l10n.studyNotConfident,
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          summary
              ? l10n.paperSummaryHeading(answer.documentName ?? '')
              : l10n.studyTopicsHeading(answer.items.length),
          style: theme.textTheme.titleSmall?.copyWith(color: theme.colorScheme.primary),
        ),
        for (final note in notes)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.xs),
            child: Text(note, style: theme.textTheme.bodySmall),
          ),
        const SizedBox(height: AppSpacing.sm),
        for (final (index, item) in answer.items.indexed)
          _Item(number: index + 1, item: item, sources: answer.sourcesOf(item)),
        if (!summary) Text(l10n.studyTopicsNote, style: theme.textTheme.bodySmall),
        const SizedBox(height: AppSpacing.xs),
        Text(l10n.studyCaution(answer.model ?? ''), style: theme.textTheme.bodySmall),
      ],
    );
  }
}

class _Item extends StatelessWidget {
  const _Item({required this.number, required this.item, required this.sources});

  final int number;
  final StudyItem item;
  final List<SearchAnswerSource> sources;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: AppSpacing.lg, child: Text('$number.')),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (item.title.isNotEmpty) Text(item.title, style: theme.textTheme.titleSmall),
                SelectableText(item.text),
                Wrap(
                  spacing: AppSpacing.xs,
                  children: [
                    for (final source in sources)
                      ActionChip(
                        visualDensity: VisualDensity.compact,
                        avatar: Icon(switch (source.kind) {
                          SearchSourceKind.page => Icons.picture_as_pdf_outlined,
                          SearchSourceKind.question => Icons.quiz_outlined,
                          SearchSourceKind.concept => Icons.menu_book_outlined,
                        }, size: 16),
                        label: Text(
                          source.pageNumber != null && item.title.isEmpty
                              ? l10n.studySourcePage(source.pageNumber!)
                              : source.label,
                        ),
                        onPressed: () {
                          final route = searchSourceRoute(source);
                          if (route != null) context.push(route);
                        },
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// "Summarize this pdf" with several papers: the learner picks one.
class ChoosePaperList extends StatelessWidget {
  const ChoosePaperList({super.key, required this.papers, required this.examCode});

  final List<PaperChoice> papers;
  final String examCode;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    if (papers.isEmpty) return Text(l10n.studyNoPapers, style: theme.textTheme.bodySmall);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.studyChoosePaper, style: theme.textTheme.bodySmall),
        for (final paper in papers)
          ListTile(
            contentPadding: EdgeInsets.zero,
            dense: true,
            leading: const Icon(Icons.picture_as_pdf_outlined),
            title: Text(paper.name),
            onTap: () => context.push(AppRoutes.paperSummary(paper.id, paper.name, examCode)),
          ),
      ],
    );
  }
}
