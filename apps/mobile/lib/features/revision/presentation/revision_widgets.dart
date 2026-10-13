import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../core/localization/generated/app_localizations.dart';
import '../../../core/utils/app_log.dart';
import '../../../core/utils/calendar_date.dart';
import '../../question_bank/domain/question.dart';
import '../../study_plan/presentation/study_profile_widgets.dart';
import '../application/revision_providers.dart';
import '../data/revision_repository.dart';
import '../domain/revision_card.dart';
import '../domain/revision_schedule.dart';

/// "Today", "Tomorrow", "In 3 days", "2 days overdue" or a date.
String formatDue(BuildContext context, CalendarDate today, CalendarDate due) {
  final l10n = AppLocalizations.of(context);
  final days = today.daysUntil(due);
  return switch (days) {
    < 0 => l10n.revisionOverdueBy(-days),
    0 => l10n.revisionDueToday,
    1 => l10n.revisionDueTomorrow,
    <= 7 => l10n.revisionDueInDays(days),
    _ => formatCalendarDate(context, due),
  };
}

/// Gap label for a rating button: "Tomorrow" or "In 4 days".
String formatGap(AppLocalizations l10n, int days) =>
    days == 1 ? l10n.revisionDueTomorrow : l10n.revisionDueInDays(days);

String ratingLabel(AppLocalizations l10n, RecallRating rating) => switch (rating) {
  RecallRating.again => l10n.ratingAgain,
  RecallRating.hard => l10n.ratingHard,
  RecallRating.good => l10n.ratingGood,
  RecallRating.easy => l10n.ratingEasy,
};

/// Where a card's content comes from: the learner's notes or an imported paper.
/// (Cards never hold AI-generated content.)
class CardOriginChip extends StatelessWidget {
  const CardOriginChip({super.key, required this.card});

  final RevisionCard card;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final label = switch (card) {
      RevisionCard(kind: CardKind.concept) => l10n.cardOriginNotes,
      RevisionCard(sourceFilename: final file?, sourcePage: final page?) =>
        l10n.cardOriginPaperPage(file, page),
      _ => l10n.cardOriginPaper,
    };
    return Chip(
      avatar: Icon(
        card.kind == CardKind.concept ? Icons.edit_note : Icons.picture_as_pdf_outlined,
        size: 18,
      ),
      label: Text(label),
      visualDensity: VisualDensity.compact,
    );
  }
}

/// Concept detail: add the concept to revision, or show when it is next due.
class ConceptRevisionTile extends ConsumerWidget {
  const ConceptRevisionTile({super.key, required this.conceptId, required this.archived});

  final String conceptId;
  final bool archived;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final card = ref.watch(conceptCardProvider(conceptId));
    final repository = ref.read(revisionRepositoryProvider);
    if (archived) return const SizedBox.shrink();

    return switch (card) {
      AsyncData(value: final c?) => Card(
        child: ListTile(
          leading: const Icon(Icons.style_outlined),
          title: Text(l10n.conceptInRevision),
          subtitle: Text(
            l10n.revisionNextReview(formatDue(context, ref.watch(todayProvider), c.dueOn)),
          ),
          trailing: TextButton(
            onPressed: () => _guard(context, () => repository.removeCard(c.id)),
            child: Text(l10n.revisionRemove),
          ),
        ),
      ),
      AsyncData() => Align(
        alignment: AlignmentDirectional.centerStart,
        child: OutlinedButton.icon(
          icon: const Icon(Icons.style_outlined),
          label: Text(l10n.conceptAddToRevision),
          onPressed: () => _guard(context, () => repository.addConcept(conceptId)),
        ),
      ),
      _ => const SizedBox.shrink(),
    };
  }
}

/// Adds questions (bookmarks or wrong answers) to revision and reports the outcome.
Future<void> addQuestionsToRevision(
  BuildContext context,
  WidgetRef ref,
  List<BankQuestion> questions, {
  required CardReason reason,
}) async {
  final l10n = AppLocalizations.of(context);
  final messenger = ScaffoldMessenger.of(context);
  try {
    final result = await ref
        .read(revisionRepositoryProvider)
        .addQuestions(questions, reason: reason);
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          [
            l10n.revisionQuestionsAdded(result.added),
            if (result.alreadyAdded > 0) l10n.revisionQuestionsAlreadyAdded(result.alreadyAdded),
            if (result.notEligible > 0) l10n.revisionQuestionsNotEligible(result.notEligible),
          ].join(' '),
        ),
      ),
    );
  } on Object catch (error, stack) {
    logError('Adding questions to revision failed', error, stack);
    messenger.showSnackBar(SnackBar(content: Text(l10n.revisionSaveError)));
  }
}

/// Whether a question can become a card (verified, from a paper, answerable, no figure).
bool canRevise(BankQuestion question) => RevisionRepository.isEligibleQuestion(question);

Future<void> _guard(BuildContext context, Future<void> Function() action) async {
  final messenger = ScaffoldMessenger.of(context);
  final message = AppLocalizations.of(context).revisionSaveError;
  try {
    await action();
  } on Object catch (error, stack) {
    logError('Updating revision failed', error, stack);
    messenger.showSnackBar(SnackBar(content: Text(message)));
  }
}

/// Small muted helper text.
class MutedText extends StatelessWidget {
  const MutedText(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.xs),
      child: Text(
        text,
        style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
      ),
    );
  }
}
