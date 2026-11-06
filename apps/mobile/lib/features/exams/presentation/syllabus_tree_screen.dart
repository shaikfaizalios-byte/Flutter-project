import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/localization/generated/app_localizations.dart';
import '../../../core/utils/app_log.dart';
import '../../../core/widgets/section_card.dart';
import '../../documents/presentation/documents_screen.dart' show uploadErrorMessage;
import '../../study_plan/application/study_profile_controller.dart';
import '../application/exam_catalog_controller.dart';
import '../data/exams_repository.dart';
import '../domain/syllabus_tree.dart';

final syllabusVersionsProvider = FutureProvider.autoDispose.family<List<SyllabusVersion>, String>(
  (ref, code) => ref.watch(examsRepositoryProvider).syllabusVersions(code),
);

final canonicalStatsProvider = FutureProvider.autoDispose<List<CanonicalStats>>((ref) {
  final exams = ref.watch(studyProfileProvider.select((p) => p.examCodes));
  return exams.length < 2
      ? Future.value(const <CanonicalStats>[])
      : ref.watch(examsRepositoryProvider).canonicalStats(exams);
});

/// An exam's syllabus: its versions, each as a tree of any depth. Learners can add their own.
class SyllabusTreeScreen extends ConsumerStatefulWidget {
  const SyllabusTreeScreen({required this.examCode, super.key});

  final String examCode;

  @override
  ConsumerState<SyllabusTreeScreen> createState() => _SyllabusTreeScreenState();
}

class _SyllabusTreeScreenState extends ConsumerState<SyllabusTreeScreen> {
  String? _chosen;

  Future<void> _run(Future<void> Function() action) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await action();
      ref.invalidate(syllabusVersionsProvider(widget.examCode));
    } on AppFailure catch (failure) {
      messenger.showSnackBar(SnackBar(content: Text(uploadErrorMessage(l10n, failure))));
    } on Object catch (error, stack) {
      logError('Changing the syllabus failed', error, stack);
    }
  }

  Future<void> _build() async {
    final draft = await showDialog<_Draft>(context: context, builder: (_) => const _BuildDialog());
    if (draft == null) return;
    await _run(
      () => ref
          .read(examsRepositoryProvider)
          .createSyllabusVersion(
            widget.examCode,
            name: draft.name,
            effectiveYear: draft.year,
            tree: draft.tree,
          ),
    );
  }

  String _title(AppLocalizations l10n, SyllabusVersion version) => version.effectiveYear == null
      ? version.name
      : '${version.name} · ${l10n.syllabusFromYear(version.effectiveYear.toString())}';

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final name = ref.watch(examNameProvider(widget.examCode));
    final versions = ref.watch(syllabusVersionsProvider(widget.examCode));
    return Scaffold(
      appBar: AppBar(title: Text(l10n.syllabusTreeTitle(name))),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _build,
        icon: const Icon(Icons.account_tree_outlined),
        label: Text(l10n.syllabusBuild),
      ),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: AppSpacing.maxContentWidth),
          child: switch (versions) {
            AsyncData(:final value) => _body(l10n, value),
            AsyncError() => Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Text(l10n.syllabusNoConnection),
            ),
            _ => const Center(child: CircularProgressIndicator()),
          },
        ),
      ),
    );
  }

  Widget _body(AppLocalizations l10n, List<SyllabusVersion> versions) {
    final shown =
        versions.where((v) => v.id == _chosen).firstOrNull ??
        versions.where((v) => v.inForce).firstOrNull ??
        versions.firstOrNull;
    final stats = ref.watch(canonicalStatsProvider).value ?? const <CanonicalStats>[];
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.xl * 3,
      ),
      children: [
        if (shown == null) Text(l10n.syllabusEmpty),
        if (versions.length > 1)
          Wrap(
            spacing: AppSpacing.sm,
            children: [
              for (final version in versions)
                ChoiceChip(
                  label: Text(_title(l10n, version)),
                  selected: version.id == shown?.id,
                  onSelected: (_) => setState(() => _chosen = version.id),
                ),
            ],
          ),
        if (shown != null) ...[
          const SizedBox(height: AppSpacing.sm),
          Text(_title(l10n, shown), style: Theme.of(context).textTheme.titleMedium),
          Wrap(
            spacing: AppSpacing.sm,
            children: [
              if (shown.inForce) Chip(label: Text(l10n.syllabusInForce)),
              Chip(label: Text(shown.own ? l10n.syllabusYours : l10n.syllabusBuiltIn)),
            ],
          ),
          if (shown.sourceTitle case final source?) Text(source),
          for (final node in shown.tree) _NodeTile(node: node),
          if (shown.own)
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButton.icon(
                icon: const Icon(Icons.delete_outline),
                label: Text(l10n.syllabusDelete),
                onPressed: () =>
                    _run(() => ref.read(examsRepositoryProvider).deleteSyllabusVersion(shown.id)),
              ),
            ),
        ],
        if (stats.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.md),
          SectionCard(
            icon: Icons.compare_arrows,
            title: l10n.syllabusAcrossExams,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final topic in stats)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    title: Text(topic.name),
                    subtitle: Text(
                      [
                        l10n.syllabusAcrossAll(topic.correct, topic.answered),
                        for (final exam in topic.exams)
                          '${ref.watch(examNameProvider(exam.code))}: '
                              '${l10n.syllabusAcrossCount(exam.correct, exam.answered)}',
                      ].join('\n'),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _NodeTile extends StatelessWidget {
  const _NodeTile({required this.node});

  final SyllabusNode node;

  @override
  Widget build(BuildContext context) {
    final label = node.levelLabel == null ? null : Text(node.levelLabel!);
    if (node.children.isEmpty) {
      return ListTile(dense: true, title: Text(node.name), subtitle: label);
    }
    return ExpansionTile(
      title: Text(node.name),
      subtitle: label,
      childrenPadding: const EdgeInsetsDirectional.only(start: AppSpacing.md),
      children: [for (final child in node.children) _NodeTile(node: child)],
    );
  }
}

typedef _Draft = ({String name, int? year, List<SyllabusNode> tree});

class _BuildDialog extends StatefulWidget {
  const _BuildDialog();

  @override
  State<_BuildDialog> createState() => _BuildDialogState();
}

class _BuildDialogState extends State<_BuildDialog> {
  final _name = TextEditingController();
  final _year = TextEditingController();
  final _outline = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    _year.dispose();
    _outline.dispose();
    super.dispose();
  }

  void _save() {
    final tree = parseOutline(_outline.text);
    if (_name.text.trim().isEmpty || tree.isEmpty) return;
    Navigator.of(context)
        .pop((name: _name.text.trim(), year: int.tryParse(_year.text.trim()), tree: tree));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(l10n.syllabusBuild),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          spacing: AppSpacing.sm,
          children: [
            TextField(
              controller: _name,
              decoration: InputDecoration(labelText: l10n.syllabusBuildName),
            ),
            TextField(
              controller: _year,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(labelText: l10n.syllabusBuildYear),
            ),
            TextField(
              controller: _outline,
              minLines: 6,
              maxLines: 12,
              decoration: InputDecoration(
                labelText: l10n.syllabusBuildOutline,
                helperText: l10n.syllabusBuildHint,
                helperMaxLines: 3,
                border: const OutlineInputBorder(),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(l10n.cancel)),
        FilledButton(onPressed: _save, child: Text(l10n.save)),
      ],
    );
  }
}
