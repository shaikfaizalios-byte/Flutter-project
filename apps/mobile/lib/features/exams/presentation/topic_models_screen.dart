import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/localization/generated/app_localizations.dart';
import '../../../core/utils/app_log.dart';
import '../../documents/presentation/documents_screen.dart' show uploadErrorMessage;
import '../data/exams_repository.dart';
import '../domain/exam_topics.dart';

final topicModelsProvider = FutureProvider.autoDispose.family<List<TopicModel>, String>(
  (ref, topicId) => ref.watch(examsRepositoryProvider).topicModels(topicId),
);

/// A topic's models. Shared ones are read-only; a learner renames, merges and removes their own.
class TopicModelsScreen extends ConsumerStatefulWidget {
  const TopicModelsScreen({required this.topicId, required this.topicName, super.key});

  final String topicId;
  final String topicName;

  @override
  ConsumerState<TopicModelsScreen> createState() => _TopicModelsScreenState();
}

class _TopicModelsScreenState extends ConsumerState<TopicModelsScreen> {
  Future<void> _run(Future<void> Function(ExamsRepository repository) action) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await action(ref.read(examsRepositoryProvider));
      ref.invalidate(topicModelsProvider(widget.topicId));
    } on AppFailure catch (failure) {
      messenger.showSnackBar(SnackBar(content: Text(uploadErrorMessage(l10n, failure))));
    } on Object catch (error, stack) {
      logError('Changing a model failed', error, stack);
    }
  }

  Future<String?> _askName(String title, {String initial = ''}) => showDialog<String>(
    context: context,
    builder: (_) => ModelNameDialog(title: title, initial: initial),
  );

  Future<void> _add() async {
    final name = await _askName(AppLocalizations.of(context).modelsAdd);
    if (name == null) return;
    await _run((r) => r.createModel(widget.topicId, name));
  }

  Future<void> _rename(TopicModel model) async {
    final l10n = AppLocalizations.of(context);
    final name = await _askName(l10n.modelsRename, initial: model.name);
    if (name == null || name == model.name) return;
    await _run((r) => r.renameModel(model.id, name));
  }

  Future<void> _merge(TopicModel model, List<TopicModel> all) async {
    final l10n = AppLocalizations.of(context);
    final into = await showDialog<TopicModel>(
      context: context,
      builder: (dialog) => SimpleDialog(
        title: Text(l10n.modelsMergeInto(model.name)),
        children: [
          for (final other in all)
            if (other.id != model.id)
              SimpleDialogOption(
                onPressed: () => Navigator.of(dialog).pop(other),
                child: Text(other.name),
              ),
        ],
      ),
    );
    if (into == null) return;
    await _run((r) => r.mergeModel(model.id, into.id));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final models = ref.watch(topicModelsProvider(widget.topicId));
    return Scaffold(
      appBar: AppBar(title: Text(l10n.modelsTitle(widget.topicName))),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _add,
        icon: const Icon(Icons.add),
        label: Text(l10n.modelsAdd),
      ),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: AppSpacing.maxContentWidth),
          child: switch (models) {
            AsyncData(:final value) => ListView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.md,
                AppSpacing.md,
                AppSpacing.xl * 3,
              ),
              children: [
                if (value.isEmpty) Text(l10n.modelsEmpty),
                for (final model in value)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(model.name),
                    subtitle: Text(model.own ? l10n.syllabusYours : l10n.syllabusBuiltIn),
                    trailing: !model.own
                        ? null
                        : PopupMenuButton<String>(
                            tooltip: l10n.modelsActions,
                            onSelected: (action) => switch (action) {
                              'rename' => _rename(model),
                              'merge' => _merge(model, value),
                              _ => _run((r) => r.deleteModel(model.id)),
                            },
                            itemBuilder: (_) => [
                              PopupMenuItem(value: 'rename', child: Text(l10n.modelsRename)),
                              if (value.length > 1)
                                PopupMenuItem(value: 'merge', child: Text(l10n.modelsMerge)),
                              PopupMenuItem(value: 'delete', child: Text(l10n.delete)),
                            ],
                          ),
                  ),
                const SizedBox(height: AppSpacing.md),
                Text(l10n.modelsDefaultsNote),
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: TextButton(
                    onPressed: () => _run((r) => r.addDefaultModels(widget.topicId)),
                    child: Text(l10n.modelsAddDefaults),
                  ),
                ),
              ],
            ),
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
}

/// Asks for a model's name.
class ModelNameDialog extends StatefulWidget {
  const ModelNameDialog({required this.title, this.initial = '', super.key});

  final String title;
  final String initial;

  @override
  State<ModelNameDialog> createState() => _ModelNameDialogState();
}

class _ModelNameDialogState extends State<ModelNameDialog> {
  late final _name = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _save() {
    final text = _name.text.trim();
    if (text.isNotEmpty) Navigator.of(context).pop(text);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _name,
        autofocus: true,
        maxLength: 120,
        decoration: InputDecoration(labelText: l10n.modelsName),
        onSubmitted: (_) => _save(),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(l10n.cancel)),
        FilledButton(onPressed: _save, child: Text(l10n.save)),
      ],
    );
  }
}
