import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../core/localization/generated/app_localizations.dart';
import '../domain/question.dart';

/// Human-readable label for a server issue code (details stay as sent by the server).
String issueLabel(AppLocalizations l10n, String code) => switch (code) {
  'missing_answer' => l10n.issueMissingAnswer,
  'incomplete_options' => l10n.issueIncompleteOptions,
  'empty_option' => l10n.issueEmptyOption,
  'duplicate_number' => l10n.issueDuplicateNumber,
  'ambiguous_boundary' => l10n.issueAmbiguousBoundary,
  'image_dependent' => l10n.issueImageDependent,
  'repeated_option_labels' => l10n.issueRepeatedOptionLabels,
  'answer_not_in_options' => l10n.issueAnswerNotInOptions,
  'conflicting_answers' => l10n.issueConflictingAnswers,
  'source_page_needs_review' => l10n.issueSourcePageNeedsReview,
  'unreadable_text' => l10n.issueUnreadableText,
  'unrecognised_answer' => l10n.issueUnrecognisedAnswer,
  'option_label_unclear' => l10n.issueOptionLabelUnclear,
  'figures_not_extracted' => l10n.issueFiguresNotExtracted,
  'no_questions_found' => l10n.issueNoQuestionsFound,
  'numbering_gaps' => l10n.issueNumberingGaps,
  'answer_key_unmatched' => l10n.issueAnswerKeyUnmatched,
  'answer_key_ambiguous_numbering' => l10n.issueAnswerKeyAmbiguous,
  'count_mismatch' => l10n.issueCountMismatch,
  'section_count_mismatch' => l10n.issueSectionCountMismatch,
  'learner_report' => l10n.issueLearnerReport,
  'ai_language_review' => l10n.issueAiLanguageReview,
  _ => l10n.issueOther,
};

String statusLabel(AppLocalizations l10n, VerificationStatus status) => switch (status) {
  VerificationStatus.verified => l10n.questionStatusVerified,
  VerificationStatus.rejected => l10n.questionStatusRejected,
  VerificationStatus.unverified => l10n.questionStatusUnverified,
};

/// Always-visible provenance label: source questions vs AI-generated ones.
class OriginChip extends StatelessWidget {
  const OriginChip({super.key, required this.origin});

  final QuestionOrigin origin;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = Theme.of(context).colorScheme;
    final ai = origin == QuestionOrigin.ai;
    return Chip(
      visualDensity: VisualDensity.compact,
      avatar: Icon(ai ? Icons.auto_awesome : Icons.picture_as_pdf_outlined, size: 16),
      label: Text(ai ? l10n.questionLabelAi : l10n.questionLabelSource),
      backgroundColor: ai ? colors.tertiaryContainer : null,
    );
  }
}

class StatusIcon extends StatelessWidget {
  const StatusIcon({super.key, required this.question});

  final BankQuestion question;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = Theme.of(context).colorScheme;
    final (icon, color) = switch (question.status) {
      VerificationStatus.verified => (Icons.verified, colors.primary),
      VerificationStatus.rejected => (Icons.block, colors.error),
      VerificationStatus.unverified when question.openIssues.isNotEmpty => (
        Icons.flag,
        colors.tertiary,
      ),
      VerificationStatus.unverified => (Icons.radio_button_unchecked, colors.outline),
    };
    return Icon(icon, color: color, semanticLabel: statusLabel(l10n, question.status));
  }
}

class QuestionTile extends StatelessWidget {
  const QuestionTile({super.key, required this.question});

  final BankQuestion question;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final open = question.openIssues;
    final subtitle = [
      ?question.section,
      if (open.isNotEmpty) open.map((i) => issueLabel(l10n, i.code)).toSet().join(' · '),
    ].join('\n');
    return ListTile(
      leading: StatusIcon(question: question),
      title: Text(
        question.sourceNumber == null
            ? question.stem
            : '${l10n.questionNumberLabel(question.sourceNumber!)}  ${question.stem}',
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: subtitle.isEmpty ? null : Text(subtitle, maxLines: 3),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => context.push(AppRoutes.question(question.id)),
    );
  }
}

/// Segmented review filter used on the review and bank screens.
class ReviewFilterBar extends StatelessWidget {
  const ReviewFilterBar({super.key, required this.selected, required this.onSelected});

  final int selected; // index into [all, needs attention, verified, rejected]
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final labels = [
      l10n.filterAllQuestions,
      l10n.filterNeedsAttention,
      l10n.filterVerified,
      l10n.filterRejected,
    ];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.xs),
      child: Row(
        spacing: AppSpacing.sm,
        children: [
          for (final (i, label) in labels.indexed)
            ChoiceChip(
              label: Text(label),
              selected: selected == i,
              onSelected: (_) => onSelected(i),
            ),
        ],
      ),
    );
  }
}
