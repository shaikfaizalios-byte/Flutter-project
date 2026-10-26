import 'package:flutter/material.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../core/localization/generated/app_localizations.dart';
import '../../concepts/domain/concept.dart';
import '../domain/recall.dart';

/// What a finished recall check asks for: the learner's notes, saved as a concept when
/// [saveAsConcept] (nothing is stored otherwise).
class RecallResult {
  const RecallResult({required this.amount, required this.notes, this.saveAsConcept = false});

  final RecallAmount amount;
  final String notes;
  final bool saveAsConcept;
}

/// Write what you remember without looking, compare with the material, rate it, and get
/// advice for that rating. Returns null when closed early.
Future<RecallResult?> showRecallCheck(BuildContext context) =>
    showDialog<RecallResult>(context: context, builder: (context) => const RecallCheckDialog());

enum _Step { write, rate, done }

class RecallCheckDialog extends StatefulWidget {
  const RecallCheckDialog({super.key});

  @override
  State<RecallCheckDialog> createState() => _RecallCheckDialogState();
}

class _RecallCheckDialogState extends State<RecallCheckDialog> {
  final _notes = TextEditingController();
  var _step = _Step.write;
  RecallAmount? _amount;

  @override
  void dispose() {
    _notes.dispose();
    super.dispose();
  }

  String _label(AppLocalizations l10n, RecallAmount amount) => switch (amount) {
    RecallAmount.almostAll => l10n.recallAlmostAll,
    RecallAmount.most => l10n.recallMost,
    RecallAmount.half => l10n.recallHalf,
    RecallAmount.little => l10n.recallLittle,
  };

  String _advice(AppLocalizations l10n, RecallAmount amount) => switch (amount) {
    RecallAmount.almostAll => l10n.recallAdviceAlmostAll,
    RecallAmount.most => l10n.recallAdviceMost,
    RecallAmount.half => l10n.recallAdviceHalf,
    RecallAmount.little => l10n.recallAdviceLittle,
  };

  void _finish({bool save = false}) =>
      Navigator.of(context)
          .pop(RecallResult(amount: _amount!, notes: _notes.text.trim(), saveAsConcept: save));

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final hasNotes = _notes.text.trim().isNotEmpty;
    return AlertDialog(
      icon: const Icon(Icons.psychology_outlined, size: 36),
      title: Text(l10n.recallTitle),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: switch (_step) {
            _Step.write => Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l10n.recallWritePrompt),
                const SizedBox(height: AppSpacing.md),
                TextField(
                  controller: _notes,
                  autofocus: true,
                  minLines: 5,
                  maxLines: 10,
                  maxLength: ConceptRules.notesMax,
                  keyboardType: TextInputType.multiline,
                  decoration: InputDecoration(
                    hintText: l10n.recallWriteHint,
                    border: const OutlineInputBorder(),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
                Text(l10n.recallWhy, style: theme.textTheme.bodySmall),
              ],
            ),
            _Step.rate => Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l10n.recallComparePrompt),
                const SizedBox(height: AppSpacing.md),
                for (final amount in RecallAmount.values)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                    child: SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: () => setState(() {
                          _amount = amount;
                          _step = _Step.done;
                        }),
                        child: Text(_label(l10n, amount)),
                      ),
                    ),
                  ),
              ],
            ),
            _Step.done => Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_label(l10n, _amount!), style: theme.textTheme.titleSmall),
                const SizedBox(height: AppSpacing.sm),
                Text(_advice(l10n, _amount!)),
                if (hasNotes) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Text(l10n.recallSaveHint, style: theme.textTheme.bodySmall),
                ],
              ],
            ),
          },
        ),
      ),
      actions: switch (_step) {
        _Step.write => [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(l10n.cancel)),
          FilledButton(
            onPressed: () => setState(() => _step = _Step.rate),
            child: Text(hasNotes ? l10n.recallCheckNow : l10n.recallInMyHead),
          ),
        ],
        _Step.rate => [
          TextButton(
            onPressed: () => setState(() => _step = _Step.write),
            child: Text(l10n.recallBack),
          ),
        ],
        _Step.done => [
          TextButton(onPressed: _finish, child: Text(l10n.recallDone)),
          if (hasNotes)
            FilledButton(onPressed: () => _finish(save: true), child: Text(l10n.recallSaveConcept)),
        ],
      },
    );
  }
}
