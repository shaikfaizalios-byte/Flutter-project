import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/exams/exam_catalog.dart';
import '../../../core/localization/generated/app_localizations.dart';
import '../../../core/utils/app_log.dart';
import '../../documents/presentation/documents_screen.dart' show uploadErrorMessage;
import '../application/exam_catalog_controller.dart';
import '../../insights/data/insights_repository.dart';

/// Multi-select exams: featured and chosen ones as chips, every other exam (and creating
/// one's own) behind "More exams".
class ExamSelector extends ConsumerWidget {
  const ExamSelector({super.key, required this.selected, required this.onChanged});

  final List<String> selected;
  final ValueChanged<List<String>> onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final catalog = ref.watch(examCatalogProvider);
    final starter = ref.watch(sharedBankProvider).value ?? const {};
    final shown = [
      for (final e in catalog)
        if (e.featured || selected.contains(e.code)) e,
      // Chosen codes the catalog doesn't know yet (offline) still show.
      for (final code in selected)
        if (!catalog.any((e) => e.code == code)) ExamOption(code: code, shortName: code),
    ];
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: [
        for (final exam in shown)
          FilterChip(
            label: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(exam.shortName),
                // Exams with starter papers: something to practise right away.
                if ((starter[exam.code]?.papers ?? 0) > 0)
                  Text(
                    ' · ${l10n.starterPapersShort(starter[exam.code]!.papers)}',
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
              ],
            ),
            selected: selected.contains(exam.code),
            onSelected: (on) => onChanged(_ordered(catalog, selected, exam.code, on)),
          ),
        ActionChip(
          avatar: const Icon(Icons.add, size: 18),
          label: Text(l10n.examsMore),
          onPressed: () async {
            unawaited(ref.read(examCatalogProvider.notifier).refresh());
            final result = await showModalBottomSheet<List<String>>(
              context: context,
              isScrollControlled: true,
              showDragHandle: true,
              builder: (context) => ExamPickerSheet(initial: selected),
            );
            if (result != null) onChanged(result);
          },
        ),
      ],
    );
  }
}

/// Keeps catalog order so the stored list is stable.
List<String> _ordered(List<ExamOption> catalog, List<String> selected, String code, bool on) {
  final chosen = {...selected};
  on ? chosen.add(code) : chosen.remove(code);
  return [
    for (final e in catalog)
      if (chosen.contains(e.code)) e.code,
    for (final c in selected)
      if (chosen.contains(c) && !catalog.any((e) => e.code == c)) c,
  ];
}

/// Searchable list of every exam, grouped by category, with "Create my own exam".
class ExamPickerSheet extends ConsumerStatefulWidget {
  const ExamPickerSheet({super.key, required this.initial});

  final List<String> initial;

  @override
  ConsumerState<ExamPickerSheet> createState() => _ExamPickerSheetState();
}

class _ExamPickerSheetState extends ConsumerState<ExamPickerSheet> {
  late List<String> _selected = [...widget.initial];
  String _query = '';
  bool _creating = false;

  Future<void> _createOwn() async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final name = await showDialog<String>(
      context: context,
      builder: (context) => const ExamNameDialog(),
    );
    if (name == null || name.trim().isEmpty) return;
    setState(() => _creating = true);
    try {
      final exam = await ref.read(examCatalogProvider.notifier).create(name.trim());
      setState(() => _selected = [..._selected, exam.code]);
    } on AppFailure catch (failure) {
      messenger.showSnackBar(SnackBar(content: Text(uploadErrorMessage(l10n, failure))));
    } on Object catch (error, stack) {
      logError('Creating an exam failed', error, stack);
    } finally {
      if (mounted) setState(() => _creating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final catalog = ref.watch(examCatalogProvider);
    final q = _query.trim().toLowerCase();
    final matches = [
      for (final e in catalog)
        if (q.isEmpty ||
            e.shortName.toLowerCase().contains(q) ||
            e.name.toLowerCase().contains(q) ||
            (e.category ?? '').toLowerCase().contains(q))
          e,
    ];
    final groups = <String, List<ExamOption>>{};
    for (final e in matches) {
      groups.putIfAbsent(e.custom ? l10n.examsOwnGroup : (e.category ?? ''), () => []).add(e);
    }

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.85),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                child: TextField(
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.search),
                    hintText: l10n.examsSearch,
                  ),
                  onChanged: (v) => setState(() => _query = v),
                ),
              ),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    for (final entry in groups.entries) ...[
                      if (entry.key.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(
                            AppSpacing.md,
                            AppSpacing.md,
                            AppSpacing.md,
                            0,
                          ),
                          child: Text(entry.key, style: Theme.of(context).textTheme.labelLarge),
                        ),
                      for (final exam in entry.value)
                        CheckboxListTile(
                          value: _selected.contains(exam.code),
                          title: Text(exam.shortName),
                          subtitle: exam.name == exam.shortName ? null : Text(exam.name),
                          onChanged: (on) => setState(
                            () => _selected = _ordered(catalog, _selected, exam.code, on ?? false),
                          ),
                        ),
                    ],
                    if (matches.isEmpty)
                      Padding(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        child: Text(l10n.examsNoMatch),
                      ),
                    ListTile(
                      leading: _creating
                          ? const SizedBox.square(
                              dimension: 24,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.add_circle_outline),
                      title: Text(l10n.examsCreateOwn),
                      subtitle: Text(l10n.examsCreateOwnHint),
                      onTap: _creating ? null : _createOwn,
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () => Navigator.of(context).pop(_selected),
                    child: Text(l10n.examsDone(_selected.length)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Name for a new (or renamed) own exam.
class ExamNameDialog extends StatefulWidget {
  const ExamNameDialog({super.key, this.initial = ''});

  final String initial;

  @override
  State<ExamNameDialog> createState() => _ExamNameDialogState();
}

class _ExamNameDialogState extends State<ExamNameDialog> {
  late final _controller = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(widget.initial.isEmpty ? l10n.examsCreateOwn : l10n.examsRename),
      content: TextField(
        controller: _controller,
        autofocus: true,
        maxLength: 100,
        decoration: InputDecoration(labelText: l10n.examsNameLabel, hintText: l10n.examsNameHint),
        onSubmitted: (v) => Navigator.of(context).pop(v),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(l10n.cancel)),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_controller.text),
          child: Text(l10n.save),
        ),
      ],
    );
  }
}
