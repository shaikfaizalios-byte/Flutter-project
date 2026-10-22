import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../app/routes.dart';
import '../../../app/theme/app_spacing.dart';
import '../../exams/application/exam_catalog_controller.dart';
import '../../../core/localization/generated/app_localizations.dart';
import '../../../core/utils/app_log.dart';
import '../../../core/widgets/empty_state.dart';
import '../../ai/presentation/ai_widgets.dart';
import '../../revision/presentation/revision_widgets.dart';
import '../application/concepts_providers.dart';
import '../domain/concept.dart';
import '../../../core/widgets/adaptive_action.dart';
import '../../question_bank/presentation/paper_questions_card.dart';

class ConceptDetailScreen extends ConsumerWidget {
  const ConceptDetailScreen({super.key, required this.conceptId});

  final String conceptId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final concept = ref.watch(conceptByIdProvider(conceptId));

    return switch (concept) {
      AsyncData(value: final c?) => _ConceptDetails(concept: c),
      AsyncData() => Scaffold(
        appBar: AppBar(title: Text(l10n.conceptDetailsTitle)),
        body: EmptyState(icon: Icons.search_off, title: l10n.conceptNotFound),
      ),
      AsyncError() => Scaffold(
        appBar: AppBar(title: Text(l10n.conceptDetailsTitle)),
        body: EmptyState(
          icon: Icons.error_outline,
          title: l10n.conceptLoadError,
          action: OutlinedButton(
            onPressed: () => ref.invalidate(conceptByIdProvider(conceptId)),
            child: Text(l10n.retry),
          ),
        ),
      ),
      _ => Scaffold(
        appBar: AppBar(title: Text(l10n.conceptDetailsTitle)),
        body: const Center(child: CircularProgressIndicator()),
      ),
    };
  }
}

enum _Action { archive, unarchive, delete }

class _ConceptDetails extends ConsumerWidget {
  const _ConceptDetails({required this.concept});

  final Concept concept;

  Future<void> _onAction(BuildContext context, WidgetRef ref, _Action action) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final repository = ref.read(conceptsRepositoryProvider);
    try {
      switch (action) {
        case _Action.archive:
          await repository.setArchived(concept.id, archived: true);
          messenger.showSnackBar(SnackBar(content: Text(l10n.conceptArchived)));
        case _Action.unarchive:
          await repository.setArchived(concept.id, archived: false);
          messenger.showSnackBar(SnackBar(content: Text(l10n.conceptRestored)));
        case _Action.delete:
          final confirmed = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: Text(l10n.conceptDeleteTitle),
              content: Text(l10n.conceptDeleteMessage(concept.title)),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: Text(l10n.cancel),
                ),
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.error,
                    foregroundColor: Theme.of(context).colorScheme.onError,
                  ),
                  onPressed: () => Navigator.of(context).pop(true),
                  child: Text(l10n.conceptDelete),
                ),
              ],
            ),
          );
          if (confirmed != true || !context.mounted) return;
          // Leave the screen first so it never shows a "not found" flash.
          context.pop();
          await repository.delete(concept.id);
          messenger.showSnackBar(SnackBar(content: Text(l10n.conceptDeleted)));
      }
    } on Object catch (error, stack) {
      logError('Concept action $action failed', error, stack);
      messenger.showSnackBar(SnackBar(content: Text(l10n.saveFailed)));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final locale = Localizations.localeOf(context).toLanguageTag();
    String date(DateTime d) => DateFormat.yMMMd(locale).add_jm().format(d.toLocal());

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.conceptDetailsTitle),
        actions: [
          AdaptiveAction(
            label: l10n.conceptEdit,
            icon: Icons.edit_outlined,
            onPressed: () => context.push(AppRoutes.editConcept(concept.id)),
          ),
          PopupMenuButton<_Action>(
            tooltip: l10n.conceptMoreActions,
            onSelected: (action) => _onAction(context, ref, action),
            itemBuilder: (context) => [
              if (concept.isArchived)
                PopupMenuItem(value: _Action.unarchive, child: Text(l10n.conceptUnarchive))
              else
                PopupMenuItem(value: _Action.archive, child: Text(l10n.conceptArchive)),
              PopupMenuItem(value: _Action.delete, child: Text(l10n.conceptDelete)),
            ],
          ),
        ],
      ),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: AppSpacing.maxContentWidth),
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.md),
            children: [
              if (concept.isArchived) ...[
                Card(
                  color: theme.colorScheme.secondaryContainer,
                  child: ListTile(
                    leading: const Icon(Icons.archive_outlined),
                    title: Text(l10n.conceptArchivedBanner),
                    trailing: TextButton(
                      onPressed: () => _onAction(context, ref, _Action.unarchive),
                      child: Text(l10n.conceptUnarchive),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
              ],
              SelectableText(concept.title, style: theme.textTheme.headlineSmall),
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.xs,
                children: [
                  Chip(label: Text(ref.watch(examNameProvider(concept.examCode)))),
                  Chip(
                    label: Text(
                      concept.language == ContentLanguage.hindi
                          ? l10n.languageHindi
                          : l10n.languageEnglish,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                [
                  concept.subject,
                  concept.topic,
                  if (concept.subtopic != null) concept.subtopic!,
                ].join(' › '),
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: AppSpacing.sm),
              ConceptRevisionTile(conceptId: concept.id, archived: concept.isArchived),
              if (!concept.isArchived) ...[
                const SizedBox(height: AppSpacing.xs),
                ConceptAiButton(concept: concept),
              ],
              if (concept.tags.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.sm),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.xs,
                  children: [
                    for (final tag in concept.tags)
                      Chip(label: Text('#$tag'), visualDensity: VisualDensity.compact),
                  ],
                ),
              ],
              if (concept.sourceReference != null) ...[
                const SizedBox(height: AppSpacing.md),
                Text(l10n.fieldSourceReference, style: theme.textTheme.labelLarge),
                SelectableText(concept.sourceReference!),
              ],
              if (concept.notes.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.md),
                Text(l10n.fieldNotes, style: theme.textTheme.labelLarge),
                const SizedBox(height: AppSpacing.xs),
                SelectableText(concept.notes, style: theme.textTheme.bodyLarge),
              ],
              const SizedBox(height: AppSpacing.lg),
              // Questions about this concept in the imported papers.
              PaperQuestionsCard(text: concept.title),
              const SizedBox(height: AppSpacing.lg),
              Text(
                '${l10n.conceptCreatedOn(date(concept.createdAt))}\n'
                '${l10n.conceptUpdatedOn(date(concept.updatedAt))}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
