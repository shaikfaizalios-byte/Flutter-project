import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/exams/exam_catalog.dart';
import '../../../core/localization/content_language.dart';
import '../../../core/localization/generated/app_localizations.dart';
import '../../../core/utils/app_log.dart';
import '../../../core/utils/calendar_date.dart';
import '../../../core/utils/clock.dart';
import '../../documents/presentation/documents_screen.dart' show uploadErrorMessage;
import '../application/exam_catalog_controller.dart';
import '../domain/new_exam.dart';

/// Opens the builder and creates the exam. Null when the learner backs out or it fails.
Future<ExamOption?> createCustomExam(BuildContext context, WidgetRef ref) async {
  final l10n = AppLocalizations.of(context);
  final messenger = ScaffoldMessenger.of(context);
  final draft = await Navigator.of(context).push<NewExam>(
    MaterialPageRoute(fullscreenDialog: true, builder: (_) => const ExamBuilderScreen()),
  );
  if (draft == null) return null;
  try {
    return await ref.read(examCatalogProvider.notifier).createFrom(draft);
  } on AppFailure catch (failure) {
    messenger.showSnackBar(SnackBar(content: Text(uploadErrorMessage(l10n, failure))));
  } on Object catch (error, stack) {
    logError('Creating an exam failed', error, stack);
  }
  return null;
}

class _SectionFields {
  final name = TextEditingController();
  final questions = TextEditingController();
  final minutes = TextEditingController();
  final cutoff = TextEditingController();

  void dispose() {
    for (final c in [name, questions, minutes, cutoff]) {
      c.dispose();
    }
  }
}

class _StageFields {
  final name = TextEditingController();
  final minutes = TextEditingController();
  final marksCorrect = TextEditingController();
  final marksWrong = TextEditingController();
  final sections = [_SectionFields()];

  void dispose() {
    for (final c in [name, minutes, marksCorrect, marksWrong]) {
      c.dispose();
    }
    for (final s in sections) {
      s.dispose();
    }
  }
}

/// Describes the learner's own exam. Only the name is needed; everything else comes from the
/// exam's notice, is the learner's own entry and is never shown as official.
class ExamBuilderScreen extends ConsumerStatefulWidget {
  const ExamBuilderScreen({super.key});

  @override
  ConsumerState<ExamBuilderScreen> createState() => _ExamBuilderScreenState();
}

class _ExamBuilderScreenState extends ConsumerState<ExamBuilderScreen> {
  static const _kinds = ['mcq', 'descriptive', 'mixed'];
  static final _optionChoices = List<int>.generate(5, (i) => i + 2);

  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _body = TextEditingController();
  final _stages = <_StageFields>[];
  final _languages = <String>{};
  final _dates = <CalendarDate>[];
  String _kind = defaultExamProfile.kind;
  int? _options = defaultExamProfile.optionsPerQuestion;

  @override
  void dispose() {
    _name.dispose();
    _body.dispose();
    for (final s in _stages) {
      s.dispose();
    }
    super.dispose();
  }

  Future<void> _addDate() async {
    final now = ref.read(clockProvider)();
    final picked = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: now,
      lastDate: now.add(const Duration(days: 3 * 366)),
    );
    if (picked == null) return;
    final date = CalendarDate.fromDateTime(picked);
    if (!_dates.contains(date)) setState(() => _dates.add(date));
  }

  void _save() {
    if (!(_form.currentState?.validate() ?? false)) return;
    final body = _body.text.trim();
    Navigator.of(context).pop(
      NewExam(
        name: _name.text.trim(),
        kind: _kind,
        optionsPerQuestion: _kind == 'descriptive' ? null : _options,
        conductingBody: body.isEmpty ? null : body,
        languages: _languages.toList(),
        examDates: _dates,
        stages: [
          for (final stage in _stages)
            NewStage(
              name: stage.name.text.trim(),
              durationMinutes: int.parse(stage.minutes.text.trim()),
              marksCorrect: double.parse(stage.marksCorrect.text.trim()),
              marksWrong: double.parse(stage.marksWrong.text.trim()),
              sections: [
                for (final section in stage.sections)
                  NewSection(
                    name: section.name.text.trim(),
                    questionCount: int.parse(section.questions.text.trim()),
                    durationMinutes: int.tryParse(section.minutes.text.trim()),
                    cutoff: double.tryParse(section.cutoff.text.trim()),
                  ),
              ],
            ),
        ],
      ),
    );
  }

  String? _needed(String? value) =>
      (value ?? '').trim().isEmpty ? AppLocalizations.of(context).examBuilderNeeded : null;

  String? _whole(String? value) {
    final number = int.tryParse((value ?? '').trim());
    return number != null && number > 0 ? null : AppLocalizations.of(context).examBuilderNumber;
  }

  String? _decimal(String? value) {
    final number = double.tryParse((value ?? '').trim());
    return number != null && number >= 0 ? null : AppLocalizations.of(context).examBuilderNumber;
  }

  Widget _field(
    TextEditingController controller,
    String label, {
    String? Function(String?)? validator,
    bool number = false,
  }) => TextFormField(
    controller: controller,
    validator: validator,
    keyboardType: number ? const TextInputType.numberWithOptions(decimal: true) : null,
    decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()),
  );

  Widget _sectionCard(_StageFields stage, _SectionFields section, AppLocalizations l10n) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
    child: Column(
      spacing: AppSpacing.sm,
      children: [
        Row(
          children: [
            Expanded(child: _field(section.name, l10n.examBuilderSectionName, validator: _needed)),
            if (stage.sections.length > 1)
              IconButton(
                tooltip: l10n.delete,
                icon: const Icon(Icons.close),
                onPressed: () => setState(() {
                  stage.sections.remove(section);
                  section.dispose();
                }),
              ),
          ],
        ),
        Row(
          spacing: AppSpacing.sm,
          children: [
            Expanded(
              child: _field(
                section.questions,
                l10n.examBuilderQuestions,
                validator: _whole,
                number: true,
              ),
            ),
            Expanded(child: _field(section.minutes, l10n.examBuilderMinutesOptional, number: true)),
            Expanded(child: _field(section.cutoff, l10n.examBuilderCutoff, number: true)),
          ],
        ),
      ],
    ),
  );

  Widget _stageCard(_StageFields stage, AppLocalizations l10n) => Card(
    child: Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: AppSpacing.sm,
        children: [
          Row(
            children: [
              Expanded(child: _field(stage.name, l10n.examBuilderStageName, validator: _needed)),
              IconButton(
                tooltip: l10n.delete,
                icon: const Icon(Icons.delete_outline),
                onPressed: () => setState(() {
                  _stages.remove(stage);
                  stage.dispose();
                }),
              ),
            ],
          ),
          _field(stage.minutes, l10n.examBuilderMinutes, validator: _whole, number: true),
          Row(
            spacing: AppSpacing.sm,
            children: [
              Expanded(
                child: _field(
                  stage.marksCorrect,
                  l10n.examBuilderMarksCorrect,
                  validator: _decimal,
                  number: true,
                ),
              ),
              Expanded(
                child: _field(
                  stage.marksWrong,
                  l10n.examBuilderMarksWrong,
                  validator: _decimal,
                  number: true,
                ),
              ),
            ],
          ),
          Text(l10n.examBuilderSections, style: Theme.of(context).textTheme.titleSmall),
          for (final section in stage.sections) _sectionCard(stage, section, l10n),
          TextButton.icon(
            icon: const Icon(Icons.add),
            label: Text(l10n.examBuilderAddSection),
            onPressed: () => setState(() => stage.sections.add(_SectionFields())),
          ),
        ],
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final title = Theme.of(context).textTheme.titleSmall;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.examBuilderTitle),
        actions: [TextButton(onPressed: _save, child: Text(l10n.examBuilderSave))],
      ),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: AppSpacing.maxContentWidth),
          child: Form(
            key: _form,
            child: ListView(
              padding: const EdgeInsets.all(AppSpacing.md),
              children: [
                Text(l10n.examBuilderIntro),
                const SizedBox(height: AppSpacing.md),
                _field(_name, l10n.examsNameLabel, validator: _needed),
                const SizedBox(height: AppSpacing.sm),
                _field(_body, l10n.examBuilderBody),
                const SizedBox(height: AppSpacing.md),
                Text(l10n.examBuilderKind, style: title),
                const SizedBox(height: AppSpacing.xs),
                SegmentedButton<String>(
                  segments: [
                    for (final kind in _kinds)
                      ButtonSegment(
                        value: kind,
                        label: Text(switch (kind) {
                          'mcq' => l10n.examKindMcq,
                          'descriptive' => l10n.examKindDescriptive,
                          _ => l10n.examKindMixed,
                        }),
                      ),
                  ],
                  selected: {_kind},
                  onSelectionChanged: (s) => setState(() => _kind = s.first),
                ),
                if (_kind != 'descriptive') ...[
                  const SizedBox(height: AppSpacing.md),
                  Row(
                    children: [
                      Expanded(child: Text(l10n.examBuilderOptions, style: title)),
                      DropdownButton<int?>(
                        value: _options,
                        onChanged: (value) => setState(() => _options = value),
                        items: [
                          for (final n in _optionChoices)
                            DropdownMenuItem(value: n, child: Text('$n')),
                          DropdownMenuItem(child: Text(l10n.examBuilderOptionsVary)),
                        ],
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: AppSpacing.md),
                Text(l10n.examBuilderLanguages, style: title),
                Wrap(
                  spacing: AppSpacing.sm,
                  children: [
                    for (final language in ContentLanguage.known)
                      FilterChip(
                        label: Text(contentLanguageName(l10n, language)),
                        selected: _languages.contains(language.code),
                        onSelected: (on) => setState(
                          () =>
                              on ? _languages.add(language.code) : _languages.remove(language.code),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                Text(l10n.examBuilderDates, style: title),
                Wrap(
                  spacing: AppSpacing.sm,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    for (final date in _dates)
                      InputChip(
                        label: Text(date.toIsoString()),
                        onDeleted: () => setState(() => _dates.remove(date)),
                      ),
                    TextButton.icon(
                      icon: const Icon(Icons.event),
                      label: Text(l10n.examBuilderAddDate),
                      onPressed: _addDate,
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                Text(l10n.examBuilderStages, style: title),
                Text(l10n.examBuilderStagesHint),
                const SizedBox(height: AppSpacing.sm),
                for (final stage in _stages) _stageCard(stage, l10n),
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: TextButton.icon(
                    icon: const Icon(Icons.add),
                    label: Text(l10n.examBuilderAddStage),
                    onPressed: () => setState(() => _stages.add(_StageFields())),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                FilledButton(onPressed: _save, child: Text(l10n.examBuilderSave)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
