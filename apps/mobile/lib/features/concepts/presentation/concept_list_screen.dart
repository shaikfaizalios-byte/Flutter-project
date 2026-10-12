import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../core/exams/exam_catalog.dart';
import '../../../core/localization/generated/app_localizations.dart';
import '../../../core/widgets/empty_state.dart';
import '../application/concepts_providers.dart';
import '../domain/concept.dart';

/// Study tab: the user's concepts with search, plus an entry point to add one.
class ConceptListScreen extends ConsumerWidget {
  const ConceptListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final query = ref.watch(conceptSearchQueryProvider);
    final concepts = ref.watch(conceptListProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.studyTitle)),
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
                  AppSpacing.sm,
                ),
                child: SearchBar(
                  hintText: l10n.conceptsSearchHint,
                  leading: const Icon(Icons.search),
                  elevation: const WidgetStatePropertyAll(0),
                  onChanged: ref.read(conceptSearchQueryProvider.notifier).set,
                ),
              ),
              Expanded(
                child: switch (concepts) {
                  AsyncData(:final value) when value.isEmpty && query.trim().isEmpty => EmptyState(
                    icon: Icons.menu_book_outlined,
                    title: l10n.conceptsEmptyTitle,
                    message: l10n.conceptsEmptyMessage,
                  ),
                  AsyncData(:final value) when value.isEmpty => EmptyState(
                    icon: Icons.search_off,
                    title: l10n.conceptsNoResults(query.trim()),
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
      title: Text(concept.title, maxLines: 2, overflow: TextOverflow.ellipsis),
      subtitle: Text('${examShortName(concept.examCode)} · $path'),
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
        onSelected: (action) => switch (action) {
          _ConceptAction.archive => _archive(context, ref),
        },
        itemBuilder: (context) => [
          PopupMenuItem(value: _ConceptAction.archive, child: Text(l10n.conceptArchive)),
        ],
      ),
    );
  }

  Future<void> _archive(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final repository = ref.read(conceptsRepositoryProvider);
    await repository.setArchived(concept.id, archived: true);
    messenger.showSnackBar(
      SnackBar(
        content: Text(l10n.conceptArchived),
        action: SnackBarAction(
          label: l10n.undo,
          onPressed: () => unawaited(repository.setArchived(concept.id, archived: false)),
        ),
      ),
    );
  }
}

enum _ConceptAction { archive }
