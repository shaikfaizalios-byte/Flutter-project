import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../core/errors/app_failure.dart';
import '../../exams/application/exam_catalog_controller.dart';
import '../../../core/localization/generated/app_localizations.dart';
import '../../../core/utils/app_log.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/section_card.dart';
import '../../ai/presentation/ai_widgets.dart';
import '../../documents/presentation/documents_screen.dart' show uploadErrorMessage;
import '../application/question_bank_providers.dart';
import '../data/questions_repository.dart';
import '../domain/question.dart';
import 'figure_view.dart';
import 'question_widgets.dart';

class QuestionReviewScreen extends ConsumerWidget {
  const QuestionReviewScreen({super.key, required this.questionId});

  final String questionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    return switch (ref.watch(questionProvider(questionId))) {
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

class _Editor extends ConsumerStatefulWidget {
  const _Editor({super.key, required this.question});

  final BankQuestion question;

  @override
  ConsumerState<_Editor> createState() => _EditorState();
}

class _EditorState extends ConsumerState<_Editor> {
  late BankQuestion _question = widget.question;
  late final TextEditingController _stem;
  late final TextEditingController _explanation;
  late List<(String, TextEditingController)> _options;
  int? _answer;
  String _answerType = 'choice';
  late final TextEditingController _typed;
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
    _topicId = q.topic?.id;
    _patternId = q.pattern?.id;
    _imageDependent = q.imageDependent;
  }

  @override
  void dispose() {
    _stem.dispose();
    _explanation.dispose();
    _typed.dispose();
    for (final (_, c) in _options) {
      c.dispose();
    }
    super.dispose();
  }

  QuestionEdit _edit({VerificationStatus? status}) => _answerType == 'typed'
      ? QuestionEdit(
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
        )
      : _choiceEdit(status: status);

  QuestionEdit _choiceEdit({VerificationStatus? status}) => QuestionEdit(
    answerType: _question.isTyped ? 'choice' : null,
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
            OriginChip(origin: q.origin),
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
        const SizedBox(height: AppSpacing.md),
        Text(l10n.fieldAnswerType, style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: AppSpacing.sm),
        SegmentedButton<String>(
          showSelectedIcon: false,
          segments: [
            ButtonSegment(value: 'choice', label: Text(l10n.answerTypeChoice)),
            ButtonSegment(value: 'typed', label: Text(l10n.answerTypeTyped)),
          ],
          selected: {_answerType},
          onSelectionChanged: (s) => setState(() => _answerType = s.first),
        ),
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
        actions: [TextButton(onPressed: _busy ? null : () => _submit(), child: Text(l10n.save))],
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
