import 'package:flutter/material.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../core/localization/generated/app_localizations.dart';
import '../domain/format_spec.dart';
import '../domain/question.dart';

String formatName(AppLocalizations l10n, String format) => switch (format) {
  'assertion_reason' => l10n.formatAssertionReason,
  'statement' => l10n.formatStatement,
  'true_false' => l10n.formatTrueFalse,
  'multiple_correct' => l10n.formatMultipleCorrect,
  'numeric' => l10n.formatNumeric,
  'fill_blank' => l10n.formatFillBlank,
  'match' => l10n.formatMatch,
  'ordering' => l10n.formatOrdering,
  _ => l10n.formatSingleCorrect,
};

/// Sets a question's format, its answer where the format keeps its own, and its marks.
class FormatEditorCard extends StatefulWidget {
  const FormatEditorCard({required this.question, required this.onSave, super.key});

  final BankQuestion question;
  final Future<void> Function(QuestionEdit edit) onSave;

  @override
  State<FormatEditorCard> createState() => _FormatEditorCardState();
}

class _FormatEditorCardState extends State<FormatEditorCard> {
  late String _format = widget.question.format;
  late final SpecInput _start = specInputOf(_format, widget.question.answerSpec);
  late final _positions = {..._start.positions};
  late final _value = TextEditingController(text: _start.value);
  late final _tolerance = TextEditingController(text: _start.tolerance);
  late final _low = TextEditingController(text: _start.low);
  late final _high = TextEditingController(text: _start.high);
  late final _lines = TextEditingController(text: _start.lines);
  late final _marks = TextEditingController(text: widget.question.marks?.toString() ?? '');
  late final _wordLimit = TextEditingController(text: widget.question.wordLimit?.toString() ?? '');
  late final _choiceGroup = TextEditingController(text: widget.question.choiceGroup ?? '');
  bool _incomplete = false;

  @override
  void dispose() {
    for (final c in [_value, _tolerance, _low, _high, _lines, _marks, _wordLimit, _choiceGroup]) {
      c.dispose();
    }
    super.dispose();
  }

  SpecInput get _input => SpecInput(
    positions: _positions,
    value: _value.text,
    tolerance: _tolerance.text,
    low: _low.text,
    high: _high.text,
    lines: _lines.text,
  );

  Future<void> _save() async {
    final needsSpec = specFormats.contains(_format);
    final spec = needsSpec ? buildAnswerSpec(_format, _input) : null;
    setState(() => _incomplete = needsSpec && spec == null);
    if (_incomplete) return;
    await widget.onSave(
      QuestionEdit(
        format: _format,
        answerSpec: spec,
        marks: double.tryParse(_marks.text.trim()),
        wordLimit: int.tryParse(_wordLimit.text.trim()),
        choiceGroup: _choiceGroup.text.trim().isEmpty ? null : _choiceGroup.text.trim(),
      ),
    );
  }

  Widget _field(TextEditingController controller, String label, {int lines = 1, String? hint}) =>
      TextField(
        controller: controller,
        minLines: lines,
        maxLines: lines == 1 ? 1 : 8,
        decoration: InputDecoration(
          labelText: label,
          helperText: hint,
          helperMaxLines: 2,
          border: const OutlineInputBorder(),
        ),
      );

  List<Widget> _specFields(AppLocalizations l10n) => switch (_format) {
    'multiple_correct' => [
      for (final option in widget.question.options)
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          controlAffinity: ListTileControlAffinity.leading,
          title: Text('${option.label}. ${option.text}'),
          value: _positions.contains(option.position),
          onChanged: (on) => setState(
            () =>
                on ?? false ? _positions.add(option.position) : _positions.remove(option.position),
          ),
        ),
    ],
    'numeric' => [
      Text(l10n.formatNumericHint),
      Row(
        spacing: AppSpacing.sm,
        children: [
          Expanded(child: _field(_value, l10n.formatValue)),
          Expanded(child: _field(_tolerance, l10n.formatTolerance)),
        ],
      ),
      Row(
        spacing: AppSpacing.sm,
        children: [
          Expanded(child: _field(_low, l10n.formatRangeFrom)),
          Expanded(child: _field(_high, l10n.formatRangeTo)),
        ],
      ),
    ],
    'fill_blank' => [_field(_lines, l10n.formatAccepted, lines: 3, hint: l10n.formatOnePerLine)],
    'match' => [_field(_lines, l10n.formatPairs, lines: 4, hint: l10n.formatPairsHint)],
    'ordering' => [_field(_lines, l10n.formatOrderItems, lines: 4, hint: l10n.formatOrderHint)],
    _ => const [],
  };

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: AppSpacing.sm,
          children: [
            Text(l10n.formatTitle, style: Theme.of(context).textTheme.titleSmall),
            DropdownButton<String>(
              isExpanded: true,
              value: _format,
              onChanged: (value) => setState(() => _format = value!),
              items: [
                for (final format in {...singleAnswerFormats, ...specFormats, _format})
                  DropdownMenuItem(value: format, child: Text(formatName(l10n, format))),
              ],
            ),
            ..._specFields(l10n),
            if (_incomplete)
              Text(
                l10n.formatIncomplete,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            Row(
              spacing: AppSpacing.sm,
              children: [
                Expanded(child: _field(_marks, l10n.formatMarks)),
                Expanded(child: _field(_wordLimit, l10n.formatWordLimit)),
                Expanded(child: _field(_choiceGroup, l10n.formatChoiceGroup)),
              ],
            ),
            FilledButton.tonal(onPressed: _save, child: Text(l10n.formatSave)),
          ],
        ),
      ),
    );
  }
}
