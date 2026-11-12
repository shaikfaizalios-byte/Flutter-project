import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/app_features.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../core/errors/app_failure.dart';
import '../../exams/application/exam_catalog_controller.dart';
import '../../../core/localization/generated/app_localizations.dart';
import '../../../core/widgets/rich_question_text.dart';
import '../../../core/utils/app_log.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/section_card.dart';
import '../../../core/widgets/web_search_button.dart';
import '../../ai/presentation/ai_widgets.dart';
import '../../documents/presentation/documents_screen.dart' show uploadErrorMessage;
import '../application/question_bank_providers.dart';
import '../data/questions_repository.dart';
import '../domain/question.dart';
import 'figure_view.dart';
import 'mark_figure_screen.dart';
import 'question_history_widgets.dart';
import 'shared_report.dart';
import 'question_widgets.dart';
import 'answer_key_card.dart';
import 'format_editor_card.dart';

class QuestionReviewScreen extends ConsumerWidget {
  const QuestionReviewScreen({super.key, required this.questionId});

  final String questionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    return switch (ref.watch(questionProvider(questionId))) {
      AsyncData(:final value) when value.readOnly => _SharedQuestionView(question: value),
      AsyncData(:final value) => _Editor(key: ValueKey(value.id), question: value),
      AsyncError() => Scaffold(
        appBar: AppBar(title: Text(l10n.questionTitle)),
        body: EmptyState(
          icon: Icons.cloud_off,
          title: l10n.bankLoadError,
          action: OutlinedButton(
            onPressed: () => ref.invalidate(questionProvider(questionId)),
            child: Text(l10n.retry),
          ),
        ),
      ),
      _ => Scaffold(
        appBar: AppBar(title: Text(l10n.questionTitle)),
        body: const Center(child: CircularProgressIndicator()),
      ),
    };
  }
}

/// A shared-bank question (another account's paper): shown as published, nothing to edit;
/// it can be reported to the PrepLoop team.
class _SharedQuestionView extends ConsumerWidget {
  const _SharedQuestionView({required this.question});

  final BankQuestion question;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final q = question;
    final stemFigures = q.figures.where((f) => f.kind != FigureKind.option);
    QuestionOption? correct;
    for (final o in q.options) {
      if (o.position == q.correctPosition) correct = o;
    }
    return Scaffold(
      appBar: AppBar(
        title: Text(
          q.sourceNumber == null ? l10n.questionTitle : l10n.questionNumberLabel(q.sourceNumber!),
        ),
        actions: [
          WebSearchAction(query: q.stem),
          IconButton(
            tooltip: l10n.sharedReportTitle,
            icon: const Icon(Icons.flag_outlined),
            onPressed: () => reportSharedContent(context, ref, q.id),
          ),
        ],
      ),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: AppSpacing.maxContentWidth),
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.md),
            children: [
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.xs,
                children: [
                  OriginChip(origin: q.origin, librarySource: q.librarySource),
                  if (q.topic != null)
                    Chip(
                      visualDensity: VisualDensity.compact,
                      label: Text('${q.topic!.name} · ${q.topic!.subject}'),
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Card(
                color: theme.colorScheme.secondaryContainer,
                child: ListTile(
                  leading: const Icon(Icons.public),
                  title: Text(l10n.sharedBankReadOnly),
                  subtitle: q.sharedSource == null ? null : Text(q.sharedSource!),
                ),
              ),
              if (q.passage != null) ...[
                const SizedBox(height: AppSpacing.md),
                Text(q.passage!.text),
              ],
              const SizedBox(height: AppSpacing.md),
              Text(q.stem, style: theme.textTheme.bodyLarge),
              for (final f in stemFigures) ...[
                const SizedBox(height: AppSpacing.sm),
                QuestionFigureView(questionId: q.id, figure: f),
              ],
              const SizedBox(height: AppSpacing.md),
              for (final o in q.options)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    o.position == q.correctPosition
                        ? Icons.check_circle
                        : Icons.radio_button_unchecked,
                    color: o.position == q.correctPosition ? theme.colorScheme.primary : null,
                  ),
                  title: RichQuestionText('(${o.label}) ${o.text}', selectable: false),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (final f in q.figures.where(
                        (f) => f.kind == FigureKind.option && f.optionPosition == o.position,
                      ))
                        QuestionFigureView(questionId: q.id, figure: f),
                    ],
                  ),
                ),
              if (q.isWritten && q.modelAnswer != null) ...[
                Text(l10n.fieldModelAnswer, style: theme.textTheme.titleSmall),
                const SizedBox(height: AppSpacing.xs),
                SelectableText(q.modelAnswer!),
              ] else if (q.isTyped && q.typedAnswer != null)
                Text('${l10n.fieldTypedAnswer}: ${q.typedAnswer}')
              else if (correct != null)
                Text(l10n.sessionCorrectAnswer(correct.label)),
              AnswerOriginNote(question: q),
              if (q.explanation != null && q.explanation!.trim().isNotEmpty) ...[
                const SizedBox(height: AppSpacing.md),
                Text(l10n.questionExplanationTitle, style: theme.textTheme.titleSmall),
                const SizedBox(height: AppSpacing.xs),
                RichQuestionText(q.explanation!),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _Editor extends ConsumerStatefulWidget {
  const _Editor({super.key, required this.question});

  final BankQuestion question;

  @override
  ConsumerState<_Editor> createState() => _EditorState();
}

class _EditorState extends ConsumerState<_Editor> {
  late BankQuestion _question = widget.question;
  late final TextEditingController _stem;

  /// The question text is being edited (else a printed question shows as its image).
  bool _editText = false;
  late final TextEditingController _explanation;
  late List<(String, TextEditingController)> _options;
  int? _answer;
  String _answerType = 'choice';
  late final TextEditingController _typed;
  late final TextEditingController _written;
  String? _topicId;
  String? _patternId;
  late bool _imageDependent;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _stem = TextEditingController();
    _explanation = TextEditingController();
    _typed = TextEditingController();
    _written = TextEditingController();
    _options = [];
    _load(widget.question);
  }

  void _load(BankQuestion q) {
    _question = q;
    _stem.text = q.stem;
    _explanation.text = q.explanation ?? '';
    for (final (_, c) in _options) {
      c.dispose();
    }
    _options = [for (final o in q.options) (o.label, TextEditingController(text: o.text))];
    _answer = q.correctPosition;
    _answerType = q.answerType;
    _typed.text = q.typedAnswer ?? '';
    _written.text = q.modelAnswer ?? '';
    _topicId = q.topic?.id;
    _patternId = q.pattern?.id;
    _imageDependent = q.imageDependent;
  }

  @override
  void dispose() {
    _stem.dispose();
    _explanation.dispose();
    _typed.dispose();
    _written.dispose();
    for (final (_, c) in _options) {
      c.dispose();
    }
    super.dispose();
  }

  QuestionEdit _edit({VerificationStatus? status}) => switch (_answerType) {
    'written' => _writtenEdit(status: status),
    'typed' => QuestionEdit(
      stem: _stem.text,
      answerType: 'typed',
      typedAnswer: _typed.text.trim().isEmpty ? null : _typed.text.trim(),
      explanation: _explanation.text,
      topicId: _topicId,
      patternId: _patternId,
      imageDependent: _imageDependent,
      status: status,
      clear: {
        if (_typed.text.trim().isEmpty && _question.typedAnswer != null) 'typed_answer',
        if (_topicId == null) 'topic_id',
        if (_patternId == null && _question.pattern != null) 'pattern_id',
      },
    ),
    _ => _choiceEdit(status: status),
  };

  QuestionEdit _writtenEdit({VerificationStatus? status}) => QuestionEdit(
    stem: _stem.text,
    answerType: 'written',
    modelAnswer: _written.text.trim().isEmpty ? null : _written.text.trim(),
    explanation: _explanation.text,
    topicId: _topicId,
    patternId: _patternId,
    imageDependent: _imageDependent,
    status: status,
    clear: {
      if (_written.text.trim().isEmpty && _question.modelAnswer != null) 'model_answer',
      if (_topicId == null) 'topic_id',
      if (_patternId == null && _question.pattern != null) 'pattern_id',
    },
  );

  QuestionEdit _choiceEdit({VerificationStatus? status}) => QuestionEdit(
    answerType: _question.isTyped || _question.isWritten ? 'choice' : null,
    stem: _stem.text,
    options: [for (final (label, c) in _options) (label, c.text)],
    correctPosition: _answer,
    explanation: _explanation.text,
    topicId: _topicId,
    patternId: _patternId,
    imageDependent: _imageDependent,
    status: status,
    clear: {
      if (_answer == null) 'correct_option_position',
      if (_topicId == null) 'topic_id',
      if (_patternId == null && _question.pattern != null) 'pattern_id',
    },
  );

  /// Saves a question's format on its own: it needn't wait for the rest of the form.
  Future<void> _saveKey(AnswerKeyEdit edit) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final saved = await ref.read(questionsRepositoryProvider).setAnswerKey(_question.id, edit);
      if (!mounted) return;
      setState(() => _load(saved.question));
      ref.invalidate(questionRevisionsProvider(saved.question.id));
      messenger.showSnackBar(
        SnackBar(
          content: Text(saved.remarked > 0 ? l10n.answerKeyRemarked(saved.remarked) : l10n.saved),
        ),
      );
    } on AppFailure catch (failure) {
      messenger.showSnackBar(SnackBar(content: Text(uploadErrorMessage(l10n, failure))));
    } on Object catch (error, stack) {
      logError('Saving the answer key failed', error, stack);
    }
  }

  Future<void> _saveFormat(QuestionEdit edit) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final updated = await ref.read(questionsRepositoryProvider).update(_question.id, edit);
      if (!mounted) return;
      setState(() => _load(updated));
      ref.invalidate(questionRevisionsProvider(updated.id));
      messenger.showSnackBar(SnackBar(content: Text(l10n.saved)));
    } on AppFailure catch (failure) {
      messenger.showSnackBar(SnackBar(content: Text(uploadErrorMessage(l10n, failure))));
    } on Object catch (error, stack) {
      logError('Saving the format failed', error, stack);
    }
  }

  Future<void> _submit({VerificationStatus? status}) async {
    if (_busy) return;
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      final updated = await ref
          .read(questionsRepositoryProvider)
          .update(_question.id, _edit(status: status));
      if (!mounted) return;
      setState(() => _load(updated));
      ref.invalidate(questionListProvider);
      ref.invalidate(questionRevisionsProvider(updated.id));
      if (updated.documentId != null) ref.invalidate(parseSummaryProvider(updated.documentId!));
      messenger.showSnackBar(
        SnackBar(
          content: Text(switch (status) {
            VerificationStatus.verified => l10n.questionApproved,
            VerificationStatus.rejected => l10n.questionRejected,
            _ => l10n.saved,
          }),
        ),
      );
    } on ServerFailure catch (failure) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            failure.code == 'cannot_verify' ? l10n.cannotVerify : uploadErrorMessage(l10n, failure),
          ),
        ),
      );
    } on AppFailure catch (failure) {
      messenger.showSnackBar(SnackBar(content: Text(uploadErrorMessage(l10n, failure))));
    } on Object catch (error, stack) {
      logError('Saving question failed', error, stack);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// The reviewer marks a figure on the question's page (e.g. a scanned diagram).
  Future<void> _markFigure() async {
    final q = _question;
    final region = await Navigator.of(context).push<FigureRegion>(
      MaterialPageRoute(
        builder: (_) => MarkFigureScreen(documentId: q.documentId!, pages: q.sourcePages),
      ),
    );
    if (region == null || !mounted) return;
    await _changeFigures(
      () => ref.read(questionsRepositoryProvider).addFigure(q.id, region.page, region.box),
    );
  }

  Future<void> _deleteFigure(String figureId) => _changeFigures(
    () => ref.read(questionsRepositoryProvider).deleteFigure(_question.id, figureId),
  );

  Future<void> _changeFigures(Future<BankQuestion> Function() change) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      final updated = await change();
      if (mounted) setState(() => _question = updated);
      ref.invalidate(questionProvider(updated.id));
    } on AppFailure catch (failure) {
      messenger.showSnackBar(SnackBar(content: Text(uploadErrorMessage(l10n, failure))));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final q = _question;
    final wide = MediaQuery.sizeOf(context).width >= 900;
    final page = q.sourcePages.isEmpty ? null : q.sourcePages.first;

    final editor = ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: [
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.xs,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            OriginChip(origin: q.origin, librarySource: q.librarySource),
            if (q.readByAi)
              Chip(
                visualDensity: VisualDensity.compact,
                avatar: const Icon(Icons.document_scanner_outlined, size: 16),
                label: Text(l10n.questionReadByAi),
              ),
            Chip(
              visualDensity: VisualDensity.compact,
              avatar: StatusIcon(question: q),
              label: Text(statusLabel(l10n, q.status)),
            ),
            Chip(
              visualDensity: VisualDensity.compact,
              label: Text(ref.watch(examNameProvider(q.examCode))),
            ),
          ],
        ),
        if (q.documentFilename != null && page != null)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.xs),
            child: Text(
              l10n.questionSource(q.documentFilename!, page),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        if (q.openIssues.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.md),
          SectionCard(
            icon: Icons.flag_outlined,
            title: l10n.openIssues,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final issue in q.openIssues)
                  Text(
                    issue.detail.isEmpty
                        ? '• ${issueLabel(l10n, issue.code)}'
                        : '• ${issueLabel(l10n, issue.code)} (${issue.detail})',
                  ),
              ],
            ),
          ),
        ],
        AiAssistCard(
          question: q,
          onChanged: (updated) => setState(() {
            _question = updated;
            _topicId = updated.topic?.id;
          }),
        ),
        if (q.passage != null) ...[
          const SizedBox(height: AppSpacing.md),
          ExpansionTile(
            tilePadding: EdgeInsets.zero,
            title: Text(
              l10n.sharedPassage(
                q.passage!.firstQuestion ?? q.sourceNumber ?? 0,
                q.passage!.lastQuestion ?? q.sourceNumber ?? 0,
              ),
            ),
            children: [SelectableText(q.passage!.text)],
          ),
        ],
        const SizedBox(height: AppSpacing.md),
        // A question whose text didn't read in full shows as printed; its text is edited only
        // when the reviewer asks.
        if (q.figures.any((f) => f.kind == FigureKind.original) && !_editText) ...[
          for (final figure in q.figures.where((f) => f.kind == FigureKind.original))
            QuestionFigureView(questionId: q.id, figure: figure),
          Text(l10n.printedNote, style: Theme.of(context).textTheme.bodySmall),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton.icon(
              icon: const Icon(Icons.edit_outlined),
              label: Text(l10n.reviewEditText),
              onPressed: () => setState(() => _editText = true),
            ),
          ),
        ] else
          TextField(
            controller: _stem,
            decoration: InputDecoration(labelText: l10n.fieldStem, alignLabelWithHint: true),
            minLines: 2,
            maxLines: 8,
          ),
        if (questionFigures(q.figures).isNotEmpty) ...[
          const SizedBox(height: AppSpacing.md),
          Text(l10n.figuresFromPaper, style: Theme.of(context).textTheme.titleSmall),
          QuestionFigures(questionId: q.id, figures: q.figures),
        ],
        for (final figure in q.figures.where((f) => f.byReviewer))
          ListTile(
            contentPadding: EdgeInsets.zero,
            dense: true,
            leading: const Icon(Icons.crop),
            title: Text(l10n.figureMarkedByYou(figure.pageNumber)),
            trailing: IconButton(
              tooltip: l10n.figureRemove,
              icon: const Icon(Icons.delete_outline),
              onPressed: _busy ? null : () => _deleteFigure(figure.id),
            ),
          ),
        if (q.documentId != null && q.sourcePages.isNotEmpty)
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton.icon(
              icon: const Icon(Icons.crop),
              label: Text(l10n.markFigureAction),
              onPressed: _busy ? null : _markFigure,
            ),
          ),
        const SizedBox(height: AppSpacing.md),
        Text(l10n.fieldAnswerType, style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: AppSpacing.sm),
        SegmentedButton<String>(
          showSelectedIcon: false,
          segments: [
            ButtonSegment(value: 'choice', label: Text(l10n.answerTypeChoice)),
            ButtonSegment(value: 'typed', label: Text(l10n.answerTypeTyped)),
            ButtonSegment(value: 'written', label: Text(l10n.answerTypeWritten)),
          ],
          selected: {_answerType},
          onSelectionChanged: (s) => setState(() => _answerType = s.first),
        ),
        if (_answerType == 'written') ...[
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: _written,
            minLines: 4,
            maxLines: 16,
            maxLength: 20000,
            decoration: InputDecoration(
              labelText: l10n.fieldModelAnswer,
              helperText: l10n.fieldModelAnswerHelp,
              helperMaxLines: 3,
              alignLabelWithHint: true,
            ),
          ),
        ],
        if (_answerType == 'typed') ...[
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: _typed,
            maxLength: 100,
            decoration: InputDecoration(
              labelText: l10n.fieldTypedAnswer,
              helperText: l10n.fieldTypedAnswerHelp,
              helperMaxLines: 3,
            ),
          ),
        ],
        if (_answerType == 'choice') ...[
          const SizedBox(height: AppSpacing.md),
          Text(l10n.fieldOptions, style: Theme.of(context).textTheme.titleSmall),
          for (final (i, (label, controller)) in _options.indexed)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.sm),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: AppSpacing.xs,
                children: [
                  TextField(
                    controller: controller,
                    decoration: InputDecoration(labelText: l10n.fieldOption(label)),
                  ),
                  if (optionFigure(q.figures, i + 1) case final figure?)
                    QuestionFigureView(questionId: q.id, figure: figure),
                ],
              ),
            ),
          if (ref.watch(appFeaturesProvider).examProfiles)
            FormatEditorCard(
              key: ValueKey('format-${_question.format}'),
              question: _question,
              onSave: _saveFormat,
            ),
          if (ref.watch(appFeaturesProvider).examProfiles)
            AnswerKeyCard(
              key: ValueKey(
                'key-${_question.keyStage}-${_question.keyOutcome}-${_question.correctPosition}',
              ),
              question: _question,
              onSave: _saveKey,
            ),
          if (_options.length < 6)
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButton.icon(
                icon: const Icon(Icons.add),
                label: Text(l10n.addOption),
                onPressed: () => setState(
                  () =>
                      _options = [..._options, ('${_options.length + 1}', TextEditingController())],
                ),
              ),
            ),
          const SizedBox(height: AppSpacing.md),
          Text(l10n.fieldCorrectAnswer, style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            children: [
              ChoiceChip(
                label: Text(l10n.answerNotSet),
                selected: _answer == null,
                onSelected: (_) => setState(() => _answer = null),
              ),
              for (final (i, (label, _)) in _options.indexed)
                ChoiceChip(
                  label: Text('($label)'),
                  selected: _answer == i + 1,
                  onSelected: (_) => setState(() => _answer = i + 1),
                ),
            ],
          ),
        ],
        AnswerOriginNote(question: q),
        Padding(
          padding: const EdgeInsets.only(top: AppSpacing.xs),
          child: Text(l10n.approveIsNotOfficial, style: Theme.of(context).textTheme.bodySmall),
        ),
        const SizedBox(height: AppSpacing.md),
        _TopicPicker(
          examCode: q.examCode,
          selectedId: _topicId,
          suggested: q.topicStatus == 'suggested',
          suggestedByAi: q.topicSuggestedBy == 'ai',
          reason: q.topicSuggestionReason,
          onChanged: (id) => setState(() {
            if (id != _topicId) _patternId = null; // patterns belong to one topic
            _topicId = id;
          }),
        ),
        _PatternPicker(
          topicId: _topicId,
          selectedId: _patternId,
          suggested: q.patternStatus == 'suggested' && q.pattern?.id == _patternId,
          reason: q.patternSuggestionReason,
          onChanged: (id) => setState(() => _patternId = id),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(l10n.fieldImageDependent),
          value: _imageDependent,
          onChanged: (v) => setState(() => _imageDependent = v),
        ),
        TextField(
          controller: _explanation,
          decoration: InputDecoration(labelText: l10n.fieldExplanation, alignLabelWithHint: true),
          minLines: 2,
          maxLines: 8,
        ),
        const SizedBox(height: AppSpacing.md),
        QuestionHistoryTile(questionId: q.id),
        const SizedBox(height: 96),
      ],
    );

    final source = (q.documentId != null && page != null)
        ? _SourcePage(documentId: q.documentId!, page: page)
        : null;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          q.sourceNumber == null ? l10n.questionTitle : l10n.questionNumberLabel(q.sourceNumber!),
        ),
        actions: [
          WebSearchAction(query: q.stem),
          TextButton(onPressed: _busy ? null : () => _submit(), child: Text(l10n.save)),
        ],
      ),
      body: wide && source != null
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: editor),
                const VerticalDivider(width: 1),
                Expanded(child: source),
              ],
            )
          : Column(
              children: [
                if (source != null)
                  ExpansionTile(
                    title: Text(l10n.sourcePageText),
                    children: [SizedBox(height: 240, child: source)],
                  ),
                Expanded(child: editor),
              ],
            ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            children: [
              OutlinedButton.icon(
                icon: const Icon(Icons.block),
                label: Text(l10n.reject),
                onPressed: _busy ? null : () => _submit(status: VerificationStatus.rejected),
              ),
              const Spacer(),
              FilledButton.icon(
                icon: const Icon(Icons.verified),
                label: Text(l10n.approve),
                onPressed: _busy ? null : () => _submit(status: VerificationStatus.verified),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TopicPicker extends ConsumerWidget {
  const _TopicPicker({
    required this.examCode,
    required this.selectedId,
    required this.suggested,
    required this.onChanged,
    this.suggestedByAi = false,
    this.reason,
  });

  final String examCode;
  final String? selectedId;
  final bool suggested;
  final bool suggestedByAi;

  /// Why it was suggested (matched keywords or the AI model).
  final String? reason;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final topics = ref.watch(topicsProvider(examCode)).value ?? const [];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DropdownButtonFormField<String?>(
          initialValue: topics.any((t) => t.id == selectedId) ? selectedId : null,
          isExpanded: true,
          decoration: InputDecoration(labelText: l10n.fieldTopic),
          items: [
            DropdownMenuItem(value: null, child: Text(l10n.topicNone)),
            for (final t in topics)
              DropdownMenuItem(value: t.id, child: Text('${t.subject} › ${t.name}')),
          ],
          onChanged: onChanged,
        ),
        if (suggested && selectedId != null)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.xs),
            child: Text(
              [
                suggestedByAi ? l10n.topicSuggestedByAi : l10n.topicSuggested,
                if (reason != null && reason!.isNotEmpty) l10n.topicSuggestionReason(reason!),
              ].join('\n'),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
      ],
    );
  }
}

/// Question type within the chosen topic. Hidden when the topic has no named patterns.
class _PatternPicker extends ConsumerWidget {
  const _PatternPicker({
    required this.topicId,
    required this.selectedId,
    required this.suggested,
    required this.onChanged,
    this.reason,
  });

  final String? topicId;
  final String? selectedId;
  final bool suggested;
  final String? reason;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final patterns = [
      for (final p in ref.watch(patternsProvider).value ?? const <PatternRef>[])
        if (p.topicId == topicId) p,
    ];
    if (topicId == null || patterns.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DropdownButtonFormField<String?>(
            key: ValueKey(topicId),
            initialValue: patterns.any((p) => p.id == selectedId) ? selectedId : null,
            isExpanded: true,
            decoration: InputDecoration(labelText: l10n.fieldPattern),
            items: [
              DropdownMenuItem(value: null, child: Text(l10n.patternNone)),
              for (final p in patterns) DropdownMenuItem(value: p.id, child: Text(p.name)),
            ],
            onChanged: onChanged,
          ),
          if (suggested && selectedId != null)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.xs),
              child: Text(
                [
                  l10n.patternSuggested,
                  if (reason != null && reason!.isNotEmpty) l10n.topicSuggestionReason(reason!),
                ].join('\n'),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
        ],
      ),
    );
  }
}

class _SourcePage extends ConsumerWidget {
  const _SourcePage({required this.documentId, required this.page});

  final String documentId;
  final int page;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    return switch (ref.watch(sourcePageTextProvider((documentId, page)))) {
      AsyncData(:final value) => SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: SelectableText(value, style: const TextStyle(fontFamily: 'monospace')),
      ),
      AsyncError() => Center(child: Text(l10n.sourcePageLoadError)),
      _ => const Center(child: CircularProgressIndicator()),
    };
  }
}
