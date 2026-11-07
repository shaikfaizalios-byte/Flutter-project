import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/localization/generated/app_localizations.dart';
import '../../../core/utils/app_log.dart';
import '../../../core/widgets/section_card.dart';
import '../application/documents_providers.dart';
import '../domain/paper_details.dart';
import 'documents_screen.dart' show uploadErrorMessage;

final _suggestionsProvider = FutureProvider.autoDispose.family<List<OtherSet>, String>(
  (ref, id) => ref.watch(documentsRepositoryProvider).duplicateSuggestions(id),
);

/// What a reviewer records about a paper: its stage, session and set, whether it is another set
/// of a paper, and a separate answer key.
class PaperDetailsScreen extends ConsumerStatefulWidget {
  const PaperDetailsScreen({required this.documentId, required this.filename, super.key});

  final String documentId;
  final String filename;

  @override
  ConsumerState<PaperDetailsScreen> createState() => _PaperDetailsScreenState();
}

class _PaperDetailsScreenState extends ConsumerState<PaperDetailsScreen> {
  final _stage = TextEditingController();
  final _session = TextEditingController();
  final _set = TextEditingController();
  final _key = TextEditingController();
  AnswerKeyResult? _result;
  bool _busy = false;

  @override
  void dispose() {
    for (final c in [_stage, _session, _set, _key]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      await action();
    } on AppFailure catch (failure) {
      messenger.showSnackBar(SnackBar(content: Text(uploadErrorMessage(l10n, failure))));
    } on Object catch (error, stack) {
      logError('Saving paper details failed', error, stack);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _saveDetails() => _run(() async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    await ref
        .read(documentsRepositoryProvider)
        .setDetails(
          widget.documentId,
          PaperDetails(stage: _stage.text, sessionLabel: _session.text, setCode: _set.text),
        );
    messenger.showSnackBar(SnackBar(content: Text(l10n.saved)));
  });

  Future<void> _markAsSet(OtherSet other) => _run(() async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    await ref.read(documentsRepositoryProvider).markAsSetOf(widget.documentId, other.documentId);
    messenger.showSnackBar(SnackBar(content: Text(l10n.paperMarkedAsSet)));
  });

  Future<void> _sendTypedKey() => _run(() async {
    if (_key.text.trim().isEmpty) return;
    final result = await ref
        .read(documentsRepositoryProvider)
        .sendKeyText(widget.documentId, _key.text);
    if (mounted) setState(() => _result = result);
  });

  Future<void> _sendKeyFile() => _run(() async {
    final file = await ref.read(pdfPickerProvider)();
    if (file == null) return;
    final result = await ref.read(documentsRepositoryProvider).sendKeyFile(widget.documentId, file);
    if (mounted) setState(() => _result = result);
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final others = ref.watch(_suggestionsProvider(widget.documentId)).value ?? const <OtherSet>[];
    final result = _result;
    return Scaffold(
      appBar: AppBar(title: Text(widget.filename)),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: AppSpacing.maxContentWidth),
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.md),
            children: [
              SectionCard(
                icon: Icons.description_outlined,
                title: l10n.paperDetailsTitle,
                child: Column(
                  spacing: AppSpacing.sm,
                  children: [
                    TextField(
                      controller: _stage,
                      decoration: InputDecoration(labelText: l10n.paperStage),
                    ),
                    TextField(
                      controller: _session,
                      decoration: InputDecoration(labelText: l10n.paperSession),
                    ),
                    TextField(
                      controller: _set,
                      decoration: InputDecoration(labelText: l10n.paperSetCode),
                    ),
                    Align(
                      alignment: AlignmentDirectional.centerEnd,
                      child: FilledButton.tonal(
                        onPressed: _busy ? null : _saveDetails,
                        child: Text(l10n.save),
                      ),
                    ),
                  ],
                ),
              ),
              if (others.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.md),
                SectionCard(
                  icon: Icons.copy_all_outlined,
                  title: l10n.paperOtherSetsTitle,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(l10n.paperOtherSetsNote),
                      for (final other in others)
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(other.filename),
                          subtitle: Text(
                            l10n.paperOtherSetsShare((other.sharedShare * 100).round()),
                          ),
                          trailing: TextButton(
                            onPressed: _busy ? null : () => _markAsSet(other),
                            child: Text(l10n.paperMarkAsSet),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: AppSpacing.md),
              SectionCard(
                icon: Icons.key_outlined,
                title: l10n.paperKeyTitle,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: AppSpacing.sm,
                  children: [
                    Text(l10n.paperKeyNote),
                    TextField(
                      controller: _key,
                      minLines: 3,
                      maxLines: 8,
                      decoration: InputDecoration(
                        labelText: l10n.paperKeyPaste,
                        border: const OutlineInputBorder(),
                      ),
                    ),
                    Wrap(
                      spacing: AppSpacing.sm,
                      children: [
                        FilledButton.tonal(
                          onPressed: _busy ? null : _sendTypedKey,
                          child: Text(l10n.paperKeyApply),
                        ),
                        OutlinedButton(
                          onPressed: _busy ? null : _sendKeyFile,
                          child: Text(l10n.paperKeyPdf),
                        ),
                      ],
                    ),
                    if (result != null) ...[
                      Text(l10n.paperKeyApplied(result.applied)),
                      if (result.agreed > 0) Text(l10n.paperKeyAgreed(result.agreed)),
                      if (result.conflicts > 0) Text(l10n.paperKeyConflicts(result.conflicts)),
                      if (result.unmatched.isNotEmpty)
                        Text(l10n.paperKeyUnmatched(result.unmatched.join(', '))),
                      if (result.ambiguous) Text(l10n.paperKeyAmbiguous),
                      for (final problem in result.problems) Text(problem),
                      Text(l10n.paperKeyWithoutAnswer(result.withoutAnswer)),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
