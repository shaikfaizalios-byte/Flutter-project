import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_spacing.dart';
import '../../exams/application/exam_catalog_controller.dart';
import '../../../core/localization/generated/app_localizations.dart';
import '../../../core/utils/app_log.dart';
import '../../../core/widgets/empty_state.dart';
import '../../exams/application/active_exam.dart';
import '../application/concepts_providers.dart';
import '../domain/concept.dart';

/// Text to start a new concept with (e.g. notes written in a recall check), passed as the
/// route's `extra`.
class ConceptPrefill {
  const ConceptPrefill({this.notes = '', this.tags = const [], this.source});

  final String notes;

  /// E.g. [aiGeneratedTag] for a concept made from an AI lesson.
  final List<String> tags;
  final String? source;
}

/// Creates a concept, or edits one when [conceptId] is given.
class ConceptFormScreen extends ConsumerStatefulWidget {
  const ConceptFormScreen({
    super.key,
    this.conceptId,
    this.subject,
    this.topic,
    this.notes,
    this.tags = const [],
    this.source,
  });

  final String? conceptId;

  /// Prefilled subject and topic for a new concept (from a syllabus topic).
  final String? subject;
  final String? topic;

  /// Prefilled notes for a new concept.
  final String? notes;

  /// Prefilled tags and source for a new concept.
  final List<String> tags;
  final String? source;

  @override
  ConsumerState<ConceptFormScreen> createState() => _ConceptFormScreenState();
}

enum _LoadState { loading, ready, notFound, failed }

class _ConceptFormScreenState extends ConsumerState<ConceptFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _subject = TextEditingController();
  final _topic = TextEditingController();
  final _subtopic = TextEditingController();
  final _tags = TextEditingController();
  final _source = TextEditingController();
  final _notes = TextEditingController();

  late String _examCode;
  ContentLanguage? _language;
  bool _saving = false;
  late _LoadState _loadState;

  bool get _isEditing => widget.conceptId != null;

  @override
  void initState() {
    super.initState();
    // New concepts go to the current exam (switched from Home only); edits keep theirs.
    _examCode = ref.read(activeExamProvider) ?? ref.read(examCatalogProvider).first.code;
    _subject.text = widget.subject ?? '';
    _topic.text = widget.topic ?? '';
    _notes.text = widget.notes ?? '';
    _aiGenerated = widget.tags.contains(aiGeneratedTag);
    _tags.text = _editableTags(widget.tags);
    _source.text = widget.source ?? '';
    _loadState = _isEditing ? _LoadState.loading : _LoadState.ready;
    if (_isEditing) _load(widget.conceptId!);
  }

  Future<void> _load(String id) async {
    try {
      final concept = await ref.read(conceptsRepositoryProvider).getById(id);
      if (!mounted) return;
      if (concept == null) {
        setState(() => _loadState = _LoadState.notFound);
        return;
      }
      _title.text = concept.title;
      _subject.text = concept.subject;
      _topic.text = concept.topic;
      _subtopic.text = concept.subtopic ?? '';
      _aiGenerated = concept.isAiGenerated;
      _tags.text = _editableTags(concept.tags);
      _source.text = concept.sourceReference ?? '';
      _notes.text = concept.notes;
      setState(() {
        _examCode = concept.examCode;
        _language = concept.language;
        _loadState = _LoadState.ready;
      });
    } on Object catch (error, stack) {
      logError('Loading concept for editing failed', error, stack);
      if (mounted) setState(() => _loadState = _LoadState.failed);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Default the content language to the interface language.
    _language ??= Localizations.localeOf(context).languageCode == 'hi'
        ? ContentLanguage.hindi
        : ContentLanguage.english;
  }

  @override
  void dispose() {
    for (final c in [_title, _subject, _topic, _subtopic, _tags, _source, _notes]) {
      c.dispose();
    }
    super.dispose();
  }

  /// Made from an AI lesson: its AI tag is kept out of the editable tags and always saved.
  bool _aiGenerated = false;

  static String _editableTags(List<String> tags) =>
      tags.where((t) => t != aiGeneratedTag).join(', ');

  List<String> get _tagList => [..._tags.text.split(','), if (_aiGenerated) aiGeneratedTag];

  String? _message(FieldError? error, int max) {
    final l10n = AppLocalizations.of(context);
    return switch (error) {
      null => null,
      FieldError.required => l10n.validationRequired,
      FieldError.tooLong => l10n.validationTooLong(max),
      FieldError.tooMany => l10n.validationTooManyTags(ConceptRules.tagsMax),
    };
  }

  Future<void> _save() async {
    if (_saving || !_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final draft = ConceptDraft(
      examCode: _examCode,
      title: _title.text,
      subject: _subject.text,
      topic: _topic.text,
      subtopic: _subtopic.text,
      language: _language!,
      tags: _tagList,
      sourceReference: _source.text,
      notes: _notes.text,
    );
    try {
      final repository = ref.read(conceptsRepositoryProvider);
      if (_isEditing) {
        await repository.update(widget.conceptId!, draft);
      } else {
        await repository.create(draft);
      }
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text(l10n.conceptSaved)));
      context.pop();
    } on Object catch (error, stack) {
      logError('Saving concept failed', error, stack);
      if (!mounted) return;
      setState(() => _saving = false);
      messenger.showSnackBar(SnackBar(content: Text(l10n.saveFailed)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    const gap = SizedBox(height: AppSpacing.md);
    final title = Text(_isEditing ? l10n.conceptEditTitle : l10n.conceptFormTitle);

    if (_loadState != _LoadState.ready) {
      return Scaffold(
        appBar: AppBar(title: title),
        body: switch (_loadState) {
          _LoadState.notFound => EmptyState(icon: Icons.search_off, title: l10n.conceptNotFound),
          _LoadState.failed => EmptyState(icon: Icons.error_outline, title: l10n.conceptLoadError),
          _ => const Center(child: CircularProgressIndicator()),
        },
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: title,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: AppSpacing.sm),
            child: FilledButton(onPressed: _saving ? null : _save, child: Text(l10n.save)),
          ),
        ],
      ),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: AppSpacing.maxContentWidth),
          child: Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(AppSpacing.md),
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.flag_outlined,
                      size: 18,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        l10n.conceptExamNote(ref.watch(examNameProvider(_examCode))),
                        style: Theme.of(context).textTheme.bodyMedium
                            ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
                      ),
                    ),
                  ],
                ),
                gap,
                TextFormField(
                  controller: _title,
                  decoration: InputDecoration(labelText: l10n.fieldTitle),
                  textInputAction: TextInputAction.next,
                  validator: (v) => _message(
                    ConceptRules.requiredText(v, ConceptRules.titleMax),
                    ConceptRules.titleMax,
                  ),
                ),
                gap,
                TextFormField(
                  controller: _subject,
                  decoration: InputDecoration(
                    labelText: l10n.fieldSubject,
                    hintText: l10n.fieldSubjectHint,
                  ),
                  textInputAction: TextInputAction.next,
                  validator: (v) => _message(
                    ConceptRules.requiredText(v, ConceptRules.labelMax),
                    ConceptRules.labelMax,
                  ),
                ),
                gap,
                TextFormField(
                  controller: _topic,
                  decoration: InputDecoration(
                    labelText: l10n.fieldTopic,
                    hintText: l10n.fieldTopicHint,
                  ),
                  textInputAction: TextInputAction.next,
                  validator: (v) => _message(
                    ConceptRules.requiredText(v, ConceptRules.labelMax),
                    ConceptRules.labelMax,
                  ),
                ),
                gap,
                TextFormField(
                  controller: _subtopic,
                  decoration: InputDecoration(labelText: l10n.fieldSubtopic),
                  textInputAction: TextInputAction.next,
                  validator: (v) => _message(
                    ConceptRules.optionalText(v, ConceptRules.labelMax),
                    ConceptRules.labelMax,
                  ),
                ),
                gap,
                Text(l10n.fieldContentLanguage, style: Theme.of(context).textTheme.labelLarge),
                const SizedBox(height: AppSpacing.sm),
                SegmentedButton<ContentLanguage>(
                  segments: [
                    ButtonSegment(
                      value: ContentLanguage.english,
                      label: Text(l10n.languageEnglish),
                    ),
                    ButtonSegment(value: ContentLanguage.hindi, label: Text(l10n.languageHindi)),
                  ],
                  selected: {_language!},
                  onSelectionChanged: (s) => setState(() => _language = s.first),
                ),
                gap,
                TextFormField(
                  controller: _tags,
                  decoration: InputDecoration(
                    labelText: l10n.fieldTags,
                    hintText: l10n.fieldTagsHint,
                    // The AI label can't be edited away.
                    helperText: _aiGenerated ? l10n.conceptAiLabelKept : null,
                    helperMaxLines: 3,
                  ),
                  textInputAction: TextInputAction.next,
                  validator: (_) =>
                      _message(ConceptRules.tags(normalizeTags(_tagList)), ConceptRules.tagMax),
                ),
                gap,
                TextFormField(
                  controller: _source,
                  decoration: InputDecoration(
                    labelText: l10n.fieldSourceReference,
                    hintText: l10n.fieldSourceReferenceHint,
                  ),
                  textInputAction: TextInputAction.next,
                  validator: (v) => _message(
                    ConceptRules.optionalText(v, ConceptRules.sourceReferenceMax),
                    ConceptRules.sourceReferenceMax,
                  ),
                ),
                gap,
                TextFormField(
                  controller: _notes,
                  decoration: InputDecoration(labelText: l10n.fieldNotes, alignLabelWithHint: true),
                  minLines: 4,
                  maxLines: 12,
                  maxLength: ConceptRules.notesMax,
                  keyboardType: TextInputType.multiline,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
