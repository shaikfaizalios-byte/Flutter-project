import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../app/theme/app_spacing.dart';
import '../../exams/application/exam_catalog_controller.dart';
import '../../../core/localization/generated/app_localizations.dart';
import '../../../core/utils/app_log.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/search_field.dart';
import '../application/concepts_providers.dart';
import '../domain/concept.dart';
import '../domain/concepts_repository.dart';
import '../../../core/widgets/adaptive_action.dart';
import '../../question_bank/presentation/paper_questions_card.dart';

/// Study tab: the learner's concepts with search and filters.
class ConceptListScreen extends ConsumerWidget {
  const ConceptListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final query = ref.watch(conceptQueryProvider);
    final concepts = ref.watch(conceptListProvider);
    final text = query.text.trim();

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.studyTitle),
        actions: [
          AdaptiveAction(
            label: l10n.revisionTitle,
            icon: Icons.style_outlined,
            onPressed: () => context.push(AppRoutes.revision),
          ),
          AdaptiveAction(
            label: l10n.documentsTitle,
            icon: Icons.picture_as_pdf_outlined,
            onPressed: () => context.push(AppRoutes.documents),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push(AppRoutes.newConcept),
        icon: const Icon(Icons.add),
        label: Text(l10n.conceptsAdd),
      ),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: AppSpacing.maxContentWidth),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md,
                  AppSpacing.sm,
                  AppSpacing.md,
                  AppSpacing.xs,
                ),
                child: AppSearchField(
                  hintText: l10n.conceptsSearchHint,
                  onChanged: ref.read(conceptQueryProvider.notifier).setText,
                ),
              ),
              const _FilterBar(),
              // Typing also searches the questions of the imported papers.
              if (text.length >= paperSearchMinLength)
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.md,
                    0,
                    AppSpacing.md,
                    AppSpacing.xs,
                  ),
                  // Capped so the concepts below stay visible; the card scrolls inside.
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxHeight: MediaQuery.sizeOf(context).height * 0.45,
                    ),
                    child: SingleChildScrollView(child: PaperQuestionsCard(text: text)),
                  ),
                ),
              Expanded(
                child: switch (concepts) {
                  AsyncData(:final value) when value.isEmpty => EmptyState(
                    icon: text.isNotEmpty || query.hasFilters
                        ? Icons.search_off
                        : Icons.menu_book_outlined,
                    title: switch (query) {
                      _ when text.isNotEmpty => l10n.conceptsNoResults(text),
                      ConceptQuery(archived: true, examCode: null, subject: null, topic: null) =>
                        l10n.conceptsArchivedEmpty,
                      _ when query.hasFilters => l10n.conceptsNoFilterResults,
                      _ => l10n.conceptsEmptyTitle,
                    },
                    message: text.isEmpty && !query.hasFilters ? l10n.conceptsEmptyMessage : null,
                  ),
                  AsyncData(:final value) => _ConceptList(concepts: value),
                  AsyncError() => EmptyState(
                    icon: Icons.error_outline,
                    title: l10n.conceptsLoadError,
                    action: OutlinedButton(
                      onPressed: () => ref.invalidate(conceptListProvider),
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

class _FilterBar extends ConsumerWidget {
  const _FilterBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final query = ref.watch(conceptQueryProvider);
    final controller = ref.read(conceptQueryProvider.notifier);
    // Filters still work while facets load; menus just have fewer choices.
    final facets = ref.watch(conceptFacetsProvider).value ?? const ConceptFacets();

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.xs),
      child: Row(
        spacing: AppSpacing.sm,
        children: [
          // First, so it is visible without scrolling the row.
          if (query.hasFilters)
            ActionChip(
              avatar: const Icon(Icons.clear, size: 18),
              label: Text(l10n.filterClear),
              onPressed: controller.clearFilters,
            ),
          _MenuFilterChip(
            label: l10n.filterExam,
            value: query.examCode,
            options: [for (final e in ref.watch(examCatalogProvider)) (e.code, e.shortName)],
            onSelected: controller.setExam,
          ),
          _MenuFilterChip(
            label: l10n.filterSubject,
            value: query.subject,
            options: [for (final s in facets.subjects) (s, s)],
            onSelected: controller.setSubject,
          ),
          _MenuFilterChip(
            label: l10n.filterTopic,
            value: query.topic,
            options: [for (final t in facets.topicsFor(query.subject)) (t, t)],
            onSelected: controller.setTopic,
          ),
          FilterChip(
            label: Text(l10n.filterArchived),
            selected: query.archived,
            onSelected: (on) => controller.setArchived(archived: on),
          ),
        ],
      ),
    );
  }
}

/// A chip that opens a menu of choices ("All" clears the filter).
class _MenuFilterChip extends StatelessWidget {
  const _MenuFilterChip({
    required this.label,
    required this.value,
    required this.options,
    required this.onSelected,
  });

  final String label;
  final String? value;

  /// (value, display text) pairs.
  final List<(String, String)> options;
  final ValueChanged<String?> onSelected;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = Theme.of(context).colorScheme;
    final display = options.where((o) => o.$1 == value).firstOrNull?.$2 ?? value;
    final active = value != null;

    return PopupMenuButton<_Choice>(
      tooltip: l10n.filterBy(label),
      onSelected: (choice) => onSelected(choice.value),
      itemBuilder: (context) => [
        PopupMenuItem(value: const _Choice(null), child: Text(l10n.filterAll)),
        for (final (optionValue, text) in options)
          CheckedPopupMenuItem(
            value: _Choice(optionValue),
            checked: optionValue == value,
            child: Text(text),
          ),
      ],
      child: Chip(
        label: Text(active ? '$label: $display' : label),
        backgroundColor: active ? colors.secondaryContainer : null,
        side: active ? BorderSide.none : null,
        deleteIcon: const Icon(Icons.arrow_drop_down),
        onDeleted: null,
        avatar: active ? const Icon(Icons.check, size: 18) : null,
      ),
    );
  }
}

class _Choice {
  const _Choice(this.value);

  final String? value;
}

class _ConceptList extends StatelessWidget {
  const _ConceptList({required this.concepts});

  final List<Concept> concepts;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      // Leave room so the FAB never covers the last item.
      padding: const EdgeInsets.only(bottom: 88),
      itemCount: concepts.length,
      separatorBuilder: (context, index) => const Divider(height: 1),
      itemBuilder: (context, index) => _ConceptTile(concept: concepts[index]),
    );
  }
}

enum _ConceptAction { archive, unarchive }

class _ConceptTile extends ConsumerWidget {
  const _ConceptTile({required this.concept});

  final Concept concept;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final path = [
      concept.subject,
      concept.topic,
      if (concept.subtopic != null) concept.subtopic!,
    ].join(' › ');

    return ListTile(
      onTap: () => context.push(AppRoutes.concept(concept.id)),
      title: Text(concept.title, maxLines: 2, overflow: TextOverflow.ellipsis),
      subtitle: Text('${ref.watch(examNameProvider(concept.examCode))} · $path'),
      leading: CircleAvatar(
        child: Text(
          concept.language == ContentLanguage.hindi ? 'हि' : 'En',
          semanticsLabel: concept.language == ContentLanguage.hindi
              ? l10n.languageHindi
              : l10n.languageEnglish,
        ),
      ),
      trailing: PopupMenuButton<_ConceptAction>(
        tooltip: l10n.conceptOptions(concept.title),
        onSelected: (action) =>
            _setArchived(context, ref, archived: action == _ConceptAction.archive),
        itemBuilder: (context) => [
          if (concept.isArchived)
            PopupMenuItem(value: _ConceptAction.unarchive, child: Text(l10n.conceptUnarchive))
          else
            PopupMenuItem(value: _ConceptAction.archive, child: Text(l10n.conceptArchive)),
        ],
      ),
    );
  }

  Future<void> _setArchived(BuildContext context, WidgetRef ref, {required bool archived}) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final repository = ref.read(conceptsRepositoryProvider);
    try {
      await repository.setArchived(concept.id, archived: archived);
    } on Object catch (error, stack) {
      logError('Changing archive state failed', error, stack);
      messenger.showSnackBar(SnackBar(content: Text(l10n.saveFailed)));
      return;
    }
    messenger.showSnackBar(
      SnackBar(
        content: Text(archived ? l10n.conceptArchived : l10n.conceptRestored),
        action: SnackBarAction(
          label: l10n.undo,
          onPressed: () => unawaited(repository.setArchived(concept.id, archived: !archived)),
        ),
      ),
    );
  }
}
