import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../core/localization/generated/app_localizations.dart';
import '../../revision/domain/revision_card.dart';
import '../../revision/presentation/revision_widgets.dart';
import '../application/question_bank_providers.dart';
import '../domain/question.dart';

/// Paper review, for Q&A notes: turn the verified written questions into flashcards
/// (question in front, written answer behind). Hidden for papers without written questions.
class WrittenFlashcardsCard extends ConsumerWidget {
  const WrittenFlashcardsCard({super.key, required this.documentId});

  final String documentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final all = ref.watch(questionListProvider(QuestionQuery(documentId: documentId))).value;
    final written = [
      for (final q in all?.$1 ?? const <BankQuestion>[])
        if (q.isWritten) q,
    ];
    if (written.isEmpty) return const SizedBox.shrink();
    final verified = [
      for (final q in written)
        if (q.status == VerificationStatus.verified) q,
    ];
    return Card(
      margin: const EdgeInsets.fromLTRB(AppSpacing.md, 0, AppSpacing.md, AppSpacing.sm),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.style_outlined, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Semantics(
                    header: true,
                    child: Text(
                      l10n.writtenFlashcardsTitle,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            if (verified.isEmpty)
              Text(l10n.writtenFlashcardsNeedVerify)
            else ...[
              Text(l10n.writtenFlashcardsMessage(verified.length)),
              const SizedBox(height: AppSpacing.sm),
              FilledButton.tonalIcon(
                icon: const Icon(Icons.style),
                label: Text(l10n.writtenFlashcardsButton),
                onPressed: () =>
                    addQuestionsToRevision(context, ref, verified, reason: CardReason.added),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
