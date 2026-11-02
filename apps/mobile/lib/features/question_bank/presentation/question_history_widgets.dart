import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../core/localization/generated/app_localizations.dart';
import '../application/question_bank_providers.dart';
import '../domain/question.dart';

/// Where the question's answer comes from. A reviewer's answer is never shown as the paper's,
/// and approving a question is never presented as an official answer key.
class AnswerOriginNote extends StatelessWidget {
  const AnswerOriginNote({super.key, required this.question});

  final BankQuestion question;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final text = answerOriginText(l10n, question);
    if (text == null) return const SizedBox.shrink();
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            question.answerOrigin == 'reviewer' ? Icons.edit_note : Icons.source_outlined,
            size: 18,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: Text(
              text,
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ),
        ],
      ),
    );
  }
}

/// The sentence for [AnswerOriginNote]; null when there is no answer yet.
String? answerOriginText(AppLocalizations l10n, BankQuestion q) {
  switch (q.answerOrigin) {
    case 'paper':
      return q.answerSource == 'answer_key'
          ? l10n.answerOriginPaperKey
          : l10n.answerOriginPaperInline;
    case 'ai':
      return l10n.answerOriginAi;
    case 'reviewer':
      final paper = q.paperAnswer;
      if (paper == null) return l10n.answerOriginReviewerUnknown;
      if (paper.source == null) return l10n.answerOriginReviewerPaperNone;
      final said = paperAnswerText(paper);
      return said == null
          ? l10n.answerOriginReviewerUnknown
          : l10n.answerOriginReviewerPaperSaid(said);
    default:
      return null;
  }
}

/// The paper's answer as one short line: "(b) 30", the typed answer, or the written one.
String? paperAnswerText(PaperAnswer paper) {
  if (paper.optionLabel != null) {
    final text = paper.optionText?.trim() ?? '';
    return text.isEmpty ? '(${paper.optionLabel})' : '(${paper.optionLabel}) $text';
  }
  final typed = paper.typedAnswer ?? paper.writtenAnswer;
  if (typed == null || typed.trim().isEmpty) return null;
  final line = typed.trim();
  return line.length > 120 ? '${line.substring(0, 120)}…' : line;
}

/// The question's history: as read from its paper, then every edit. Loaded when opened.
class QuestionHistoryTile extends ConsumerWidget {
  const QuestionHistoryTile({super.key, required this.questionId});

  final String questionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    return ExpansionTile(
      tilePadding: EdgeInsets.zero,
      leading: const Icon(Icons.history),
      title: Text(l10n.questionHistoryTitle),
      children: [_HistoryList(questionId: questionId)],
    );
  }
}

class _HistoryList extends ConsumerWidget {
  const _HistoryList({required this.questionId});

  final String questionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    return ref
        .watch(questionRevisionsProvider(questionId))
        .when(
          loading: () => const Padding(
            padding: EdgeInsets.all(AppSpacing.md),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (error, stack) => ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(l10n.questionHistoryFailed),
            trailing: TextButton(
              onPressed: () => ref.invalidate(questionRevisionsProvider(questionId)),
              child: Text(l10n.retry),
            ),
          ),
          data: (revisions) => revisions.isEmpty
              ? ListTile(contentPadding: EdgeInsets.zero, title: Text(l10n.questionHistoryNone))
              : Column(children: [for (final r in revisions) _RevisionTile(revision: r)]),
        );
  }
}

class _RevisionTile extends StatelessWidget {
  const _RevisionTile({required this.revision});

  final QuestionRevision revision;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final locale = Localizations.localeOf(context).toLanguageTag();
    final when = DateFormat.yMMMd(locale).add_jm().format(revision.createdAt.toLocal());
    final what = switch ((revision.action, revision.actor)) {
      ('extracted', 'ai') => l10n.historyReadByAi,
      ('extracted', _) => l10n.historyReadByRules,
      ('generated', _) => l10n.historyGenerated,
      ('baseline', _) => l10n.historyBaseline,
      _ => l10n.historyEdited(_changedText(l10n, revision.changed)),
    };
    final snap = revision.snapshot;
    final answer = switch (snap.answerType) {
      'typed' => snap.typedAnswer,
      'written' => snap.modelAnswer,
      _ =>
        snap.correctPosition != null && snap.correctPosition! <= snap.options.length
            ? '(${snap.options[snap.correctPosition! - 1].$1})'
            : null,
    };
    return ExpansionTile(
      tilePadding: EdgeInsets.zero,
      childrenPadding: const EdgeInsets.only(bottom: AppSpacing.sm),
      expandedCrossAxisAlignment: CrossAxisAlignment.start,
      title: Text(what),
      subtitle: Text(when),
      children: [
        SelectableText(snap.stem),
        for (final (label, text) in snap.options) Text('($label) $text'),
        const SizedBox(height: AppSpacing.xs),
        Text(
          answer == null ? l10n.historyNoAnswer : l10n.historyAnswer(answer),
          style: theme.textTheme.bodySmall,
        ),
      ],
    );
  }

  static String _changedText(AppLocalizations l10n, List<String> fields) {
    final names = <String>{
      for (final f in fields)
        switch (f) {
          'stem' => l10n.historyFieldWording,
          'options' => l10n.historyFieldOptions,
          'explanation' => l10n.historyFieldExplanation,
          _ => l10n.historyFieldAnswer, // answer type, answer and where it came from
        },
    };
    return names.join(', ');
  }
}
