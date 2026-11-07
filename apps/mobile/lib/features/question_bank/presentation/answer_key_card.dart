import 'package:flutter/material.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../core/localization/generated/app_localizations.dart';
import '../../../core/widgets/rich_question_text.dart';
import '../domain/format_spec.dart';
import '../domain/question.dart';

/// Records the official key of a question: its stage, and whether one answer stands, several are
/// accepted or the question was dropped. A final key re-marks every attempt at the question.
class AnswerKeyCard extends StatefulWidget {
  const AnswerKeyCard({required this.question, required this.onSave, super.key});

  final BankQuestion question;
  final Future<void> Function(AnswerKeyEdit edit) onSave;

  @override
  State<AnswerKeyCard> createState() => _AnswerKeyCardState();
}

class _AnswerKeyCardState extends State<AnswerKeyCard> {
  late String? _stage = widget.question.keyStage;
  late String _outcome = widget.question.keyOutcome;
  late int? _position = widget.question.correctPosition;
  late final _accepted = {...widget.question.acceptedPositions};
  bool _incomplete = false;

  bool get _oneOption => singleAnswerFormats.contains(widget.question.format);

  Future<void> _save() async {
    final several = _outcome == 'several';
    setState(() => _incomplete = several && _accepted.length < 2);
    if (_incomplete) return;
    await widget.onSave(
      AnswerKeyEdit(
        stage: _stage,
        outcome: _outcome,
        acceptedPositions: several ? (_accepted.toList()..sort()) : null,
        correctPosition: _outcome == 'one' && _oneOption ? _position : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: AppSpacing.sm,
          children: [
            Text(l10n.answerKeyTitle, style: theme.textTheme.titleSmall),
            if (widget.question.keyChanged)
              Text(l10n.sessionKeyChanged, style: theme.textTheme.bodySmall),
            DropdownButton<String?>(
              isExpanded: true,
              value: _stage,
              onChanged: (value) => setState(() => _stage = value),
              items: [
                DropdownMenuItem(child: Text(l10n.answerKeyNoStage)),
                DropdownMenuItem(value: 'provisional', child: Text(l10n.answerKeyProvisional)),
                DropdownMenuItem(value: 'final', child: Text(l10n.answerKeyFinal)),
              ],
            ),
            DropdownButton<String>(
              isExpanded: true,
              value: _outcome,
              onChanged: (value) => setState(() => _outcome = value ?? 'one'),
              items: [
                DropdownMenuItem(value: 'one', child: Text(l10n.answerKeyOne)),
                if (_oneOption)
                  DropdownMenuItem(value: 'several', child: Text(l10n.answerKeySeveral)),
                DropdownMenuItem(value: 'dropped', child: Text(l10n.answerKeyDropped)),
              ],
            ),
            if (_outcome == 'one' && _oneOption)
              DropdownButton<int>(
                isExpanded: true,
                value: _position,
                hint: Text(l10n.answerKeyChooseOption),
                onChanged: (value) => setState(() => _position = value),
                items: [
                  for (final option in widget.question.options)
                    DropdownMenuItem(
                      value: option.position,
                      child: RichQuestionText('${option.label}. ${option.text}', selectable: false),
                    ),
                ],
              ),
            if (_outcome == 'several')
              for (final option in widget.question.options)
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  title: RichQuestionText('${option.label}. ${option.text}', selectable: false),
                  value: _accepted.contains(option.position),
                  onChanged: (on) => setState(
                    () => on ?? false
                        ? _accepted.add(option.position)
                        : _accepted.remove(option.position),
                  ),
                ),
            if (_incomplete)
              Text(
                l10n.answerKeyPickTwo,
                style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error),
              ),
            if (_stage == 'final') Text(l10n.answerKeyFinalNote, style: theme.textTheme.bodySmall),
            FilledButton(onPressed: _save, child: Text(l10n.answerKeySave)),
          ],
        ),
      ),
    );
  }
}
