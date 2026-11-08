import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/localization/generated/app_localizations.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/rich_question_text.dart';
import '../../../core/widgets/search_field.dart';
import '../../../core/widgets/section_card.dart';
import '../../exams/application/active_exam.dart';
import '../../question_bank/application/question_bank_providers.dart';
import '../../question_bank/presentation/format_editor_card.dart';
import '../../question_bank/presentation/question_widgets.dart';
import '../application/library_providers.dart';
import '../domain/library_models.dart';

const _formats = ['single_correct', 'multiple_correct', 'numeric', 'integer', 'typed_in', 'match'];
const _levels = ['easy', 'medium', 'hard'];

/// Search PrepLoop's curated questions for the current exam, and save chapters for offline use.
class LibraryScreen extends ConsumerStatefulWidget {
  const LibraryScreen({super.key});

  @override
  ConsumerState<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends ConsumerState<LibraryScreen> {
  Timer? _settle;
  String _text = '';
  String? _unit;
  String? _topicId;
  String? _patternId;
  String? _format;
  String? _difficulty;
  int? _year;

  @override
  void dispose() {
    _settle?.cancel();
    super.dispose();
  }

  void _search(String value) {
    _settle?.cancel();
    _settle = Timer(const Duration(milliseconds: 350), () {
      if (mounted) setState(() => _text = value.trim());
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final exam = ref.watch(activeExamProvider);
    if (exam == null) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.libraryTitle)),
        body: EmptyState(icon: Icons.local_library_outlined, title: l10n.libraryEmpty),
      );
    }
    final packs = ref.watch(libraryPacksProvider(exam)).value ?? const <LibraryPack>[];
    final topics = ref.watch(topicsProvider(exam)).value ?? const [];
    final models = ref.watch(patternsProvider).value ?? const [];
    final shownModels = [
      for (final m in models)
        if (_topicId == null || m.topicId == _topicId) m,
    ];
    final thisYear = DateTime.now().year;
    final LibraryQuery query = (
      exam: exam,
      text: _text,
      unit: _unit,
      topicId: _topicId,
      patternId: _patternId,
      format: _format,
      year: _year,
      difficulty: _difficulty,
    );
    return Scaffold(
      appBar: AppBar(title: Text(l10n.libraryTitle)),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          _ChaptersCard(exam: exam),
          const SizedBox(height: AppSpacing.md),
          AppSearchField(hintText: l10n.librarySearchHint, onChanged: _search),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.xs,
            children: [
              _Filter<String>(
                label: l10n.libraryFilterChapter,
                value: _unit,
                options: {
                  for (final p in packs)
                    if (p.questions > 0) p.name: p.name,
                },
                onChanged: (v) => setState(() => _unit = v),
              ),
              _Filter<String>(
                label: l10n.libraryFilterTopic,
                value: _topicId,
                options: {for (final t in topics) t.id: t.name},
                onChanged: (v) => setState(() {
                  _topicId = v;
                  _patternId = null;
                }),
              ),
              _Filter<String>(
                label: l10n.libraryFilterModel,
                value: _patternId,
                options: {for (final m in shownModels) m.id: m.name},
                onChanged: (v) => setState(() => _patternId = v),
              ),
              _Filter<String>(
                label: l10n.libraryFilterFormat,
                value: _format,
                options: {for (final f in _formats) f: formatName(l10n, f)},
                onChanged: (v) => setState(() => _format = v),
              ),
              _Filter<int>(
                label: l10n.libraryFilterYear,
                value: _year,
                options: {for (var y = thisYear; y > thisYear - 15; y--) y: '$y'},
                onChanged: (v) => setState(() => _year = v),
              ),
              _Filter<String>(
                label: l10n.libraryFilterLevel,
                value: _difficulty,
                options: {for (final level in _levels) level: levelName(l10n, level)},
                onChanged: (v) => setState(() => _difficulty = v),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          ref
              .watch(librarySearchProvider(query))
              .when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, _) => EmptyState(
                  icon: Icons.cloud_off_outlined,
                  title: l10n.libraryFailed,
                  action: OutlinedButton(
                    onPressed: () => ref.invalidate(librarySearchProvider(query)),
                    child: Text(l10n.retry),
                  ),
                ),
                data: (page) => page.items.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.all(AppSpacing.lg),
                        child: Text(l10n.libraryEmpty, textAlign: TextAlign.center),
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [for (final hit in page.items) _HitCard(hit: hit)],
                      ),
              ),
        ],
      ),
    );
  }
}

String levelName(AppLocalizations l10n, String level) => switch (level) {
  'easy' => l10n.libraryLevelEasy,
  'hard' => l10n.libraryLevelHard,
  _ => l10n.libraryLevelMedium,
};

class _Filter<T> extends StatelessWidget {
  const _Filter({
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
  });

  final String label;
  final T? value;
  final Map<T, String> options;
  final ValueChanged<T?> onChanged;

  @override
  Widget build(BuildContext context) => ConstrainedBox(
    constraints: const BoxConstraints(maxWidth: 220),
    child: DropdownButton<T?>(
      isExpanded: false,
      value: options.containsKey(value) ? value : null,
      hint: Text(label),
      items: [
        DropdownMenuItem<T?>(child: Text(label)),
        for (final entry in options.entries)
          DropdownMenuItem<T?>(
            value: entry.key,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 170),
              child: Text(entry.value, overflow: TextOverflow.ellipsis),
            ),
          ),
      ],
      onChanged: onChanged,
    ),
  );
}

class _HitCard extends StatelessWidget {
  const _HitCard({required this.hit});

  final LibraryHit hit;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final where = [
      ?hit.topic,
      if (hit.year != null) '${hit.year}',
      levelName(l10n, hit.difficulty),
    ].join(' · ');
    return Card(
      child: InkWell(
        onTap: () => context.push(AppRoutes.question(hit.questionId)),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (hit.pictured) Text(l10n.libraryPictured) else RichQuestionText(hit.stem),
              const SizedBox(height: AppSpacing.xs),
              Text(where, style: Theme.of(context).textTheme.bodySmall),
              if (hit.percentRight != null)
                Text(
                  l10n.sessionPercentRight(hit.percentRight!),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              const SizedBox(height: AppSpacing.xs),
              LibrarySourceChip(source: hit.source),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChaptersCard extends ConsumerStatefulWidget {
  const _ChaptersCard({required this.exam});

  final String exam;

  @override
  ConsumerState<_ChaptersCard> createState() => _ChaptersCardState();
}

class _ChaptersCardState extends ConsumerState<_ChaptersCard> {
  final _busy = <String>{};

  /// Saved chapters already brought up to date on this visit.
  final _refreshed = <String>{};

  /// A saved chapter that changed is fetched again without asking: only what changed comes.
  void _refreshOutdated(List<LibraryPack> packs, Map<String, int> saved) {
    for (final pack in packs) {
      if (packState(pack, saved[pack.key]) != PackState.outdated) continue;
      if (_refreshed.contains(pack.key) || _busy.contains(pack.key)) continue;
      _refreshed.add(pack.key);
      Future.microtask(() => _save(pack, quiet: true));
    }
  }

  Future<void> _save(LibraryPack pack, {bool quiet = false}) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy.add(pack.key));
    try {
      await ref.read(libraryRepositoryProvider).savePack(widget.exam, pack);
      ref.invalidate(savedPacksProvider(widget.exam));
    } on AppFailure {
      if (!quiet) messenger.showSnackBar(SnackBar(content: Text(l10n.libraryFailed)));
    } finally {
      if (mounted) setState(() => _busy.remove(pack.key));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final saved = ref.watch(savedPacksProvider(widget.exam)).value ?? const <String, int>{};
    final packs = [
      for (final pack in ref.watch(libraryPacksProvider(widget.exam)).value ?? <LibraryPack>[])
        // An emptied chapter is shown only to a device still holding its questions.
        if (pack.questions > 0 || saved.containsKey(pack.key)) pack,
    ];
    _refreshOutdated(packs, saved);
    return SectionCard(
      icon: Icons.download_for_offline_outlined,
      title: l10n.libraryOfflineTitle,
      child: packs.isEmpty
          ? Text(l10n.libraryNoPacks)
          : Column(
              children: [
                for (final pack in packs)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(pack.name),
                    subtitle: Text(
                      [
                        if (pack.subject.isNotEmpty) pack.subject,
                        l10n.libraryPackCount(pack.questions),
                      ].join(' · '),
                    ),
                    trailing: _busy.contains(pack.key)
                        ? const SizedBox.square(
                            dimension: 24,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : switch (packState(pack, saved[pack.key])) {
                            PackState.saved => Text(l10n.librarySaved),
                            PackState.outdated => TextButton(
                              onPressed: () => _save(pack),
                              child: Text(l10n.libraryUpdate),
                            ),
                            PackState.notSaved => TextButton(
                              onPressed: () => _save(pack),
                              child: Text(l10n.librarySave),
                            ),
                          },
                  ),
              ],
            ),
    );
  }
}
