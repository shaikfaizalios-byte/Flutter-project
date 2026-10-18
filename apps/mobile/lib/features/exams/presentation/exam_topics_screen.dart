import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/localization/generated/app_localizations.dart';
import '../../../core/utils/app_log.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/section_card.dart';
import '../../ai/application/ai_providers.dart';
import '../../documents/presentation/documents_screen.dart' show uploadErrorMessage;
import '../../question_bank/application/question_bank_providers.dart';
import '../application/exam_catalog_controller.dart';
import '../data/exams_repository.dart';
import '../domain/exam_topics.dart';

/// Subjects and topics of one exam: shared ones (read-only) and the learner's own, which
/// they add, rename and delete. With AI on, a topic list can be drafted from their papers.
class ExamTopicsScreen extends ConsumerStatefulWidget {
  const ExamTopicsScreen({super.key, required this.examCode});

  final String examCode;

  @override
  ConsumerState<ExamTopicsScreen> createState() => _ExamTopicsScreenState();
}

class _ExamTopicsScreenState extends ConsumerState<ExamTopicsScreen> {
  bool _busy = false;

  void _changed() => ref
    ..invalidate(examTopicsProvider(widget.examCode))
    ..invalidate(topicsProvider)
    ..invalidate(patternsProvider);

  Future<void> _run(Future<void> Function() action, {String? done}) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      await action();
      _changed();
      if (done != null) messenger.showSnackBar(SnackBar(content: Text(done)));
    } on ServerFailure catch (failure) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(switch (failure.code) {
            'topic_exists' => l10n.topicsExists,
            'not_eligible' => l10n.topicsDraftNeedsPapers,
            _ => uploadErrorMessage(l10n, failure),
          }),
        ),
      );
    } on AppFailure catch (failure) {
      messenger.showSnackBar(SnackBar(content: Text(uploadErrorMessage(l10n, failure))));
    } on Object catch (error, stack) {
      logError('Topic action failed', error, stack);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _add({String subject = ''}) async {
    final topic = await showDialog<NewTopic>(
      context: context,
      builder: (context) => _TopicDialog(subject: subject),
    );
    if (topic == null) return;
    await _run(() => ref.read(examsRepositoryProvider).createTopic(widget.examCode, topic));
  }

  Future<void> _edit(ExamTopic topic) async {
    final edited = await showDialog<NewTopic>(
      context: context,
      builder: (context) => _TopicDialog(subject: topic.subject, name: topic.name),
    );
    if (edited == null) return;
    await _run(
      () => ref
          .read(examsRepositoryProvider)
          .updateTopic(topic.id, subject: edited.subject, name: edited.name),
    );
  }

  Future<void> _delete(ExamTopic topic) async {
    final l10n = AppLocalizations.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.topicsDeleteTitle(topic.name)),
        content: Text(l10n.topicsDeleteBody),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: Text(l10n.cancel)),
          FilledButton(onPressed: () => Navigator.of(context).pop(true), child: Text(l10n.delete)),
        ],
      ),
    );
    if (ok == true) await _run(() => ref.read(examsRepositoryProvider).deleteTopic(topic.id));
  }

  Future<void> _draft() async {
    final l10n = AppLocalizations.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.topicsDraftTitle),
        content: Text(l10n.topicsDraftNotice),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: Text(l10n.cancel)),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.topicsAiConfirm),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    TopicDraft? draft;
    await _run(() async {
      draft = await ref.read(examsRepositoryProvider).draftTopics(widget.examCode);
    });
    final result = draft;
    if (result == null || !mounted) return;
    if (result.topics.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.topicsDraftEmpty)));
      return;
    }
    final kept = await showModalBottomSheet<List<NewTopic>>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => _DraftSheet(draft: result),
    );
    if (kept == null || kept.isEmpty) return;
    await _run(
      () => ref.read(examsRepositoryProvider).createTopics(widget.examCode, kept),
      done: l10n.topicsDraftSaved(kept.length),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final name = ref.watch(examNameProvider(widget.examCode));
    final aiEnabled = ref.watch(aiStatusProvider).value?.enabled ?? false;
    final topics = ref.watch(examTopicsProvider(widget.examCode));

    return Scaffold(
      appBar: AppBar(title: Text(l10n.topicsScreenTitle(name))),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add),
        label: Text(l10n.topicsAdd),
        onPressed: _busy ? null : _add,
      ),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: AppSpacing.maxContentWidth),
          child: switch (topics) {
            AsyncData(:final value) => ListView(
              padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.md, AppSpacing.md, 96),
              children: [
                Text(l10n.topicsScreenIntro, style: Theme.of(context).textTheme.bodySmall),
                if (aiEnabled) ...[
                  const SizedBox(height: AppSpacing.sm),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.auto_awesome),
                    label: Text(l10n.topicsDraftAction),
                    onPressed: _busy ? null : _draft,
                  ),
                ],
                if (_busy) const LinearProgressIndicator(),
                const SizedBox(height: AppSpacing.md),
                if (value.isEmpty)
                  EmptyState(
                    icon: Icons.label_outline,
                    title: l10n.topicsEmptyTitle,
                    message: l10n.topicsEmptyMessage,
                  ),
                for (final entry in _bySubject(value).entries) ...[
                  SectionCard(
                    icon: Icons.menu_book_outlined,
                    title: entry.key,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (final topic in entry.value)
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(topic.name),
                            subtitle: Text(
                              topic.own ? l10n.topicsOwnLabel : l10n.topicsSharedLabel,
                            ),
                            trailing: topic.own
                                ? PopupMenuButton<String>(
                                    tooltip: l10n.examsActions,
                                    onSelected: (v) => v == 'edit' ? _edit(topic) : _delete(topic),
                                    itemBuilder: (context) => [
                                      PopupMenuItem(value: 'edit', child: Text(l10n.topicsEdit)),
                                      PopupMenuItem(value: 'delete', child: Text(l10n.delete)),
                                    ],
                                  )
                                : null,
                          ),
                        TextButton.icon(
                          icon: const Icon(Icons.add),
                          label: Text(l10n.topicsAddTo(entry.key)),
                          onPressed: _busy ? null : () => _add(subject: entry.key),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                ],
              ],
            ),
            AsyncError() => EmptyState(
              icon: Icons.cloud_off,
              title: l10n.bankLoadError,
              action: OutlinedButton(
                onPressed: () => ref.invalidate(examTopicsProvider(widget.examCode)),
                child: Text(l10n.retry),
              ),
            ),
            _ => const Center(child: CircularProgressIndicator()),
          },
        ),
      ),
    );
  }
}

Map<String, List<ExamTopic>> _bySubject(List<ExamTopic> topics) {
  final result = <String, List<ExamTopic>>{};
  for (final t in topics) {
    result.putIfAbsent(t.subject, () => []).add(t);
  }
  return result;
}

class _TopicDialog extends StatefulWidget {
  const _TopicDialog({this.subject = '', this.name = ''});

  final String subject;
  final String name;

  @override
  State<_TopicDialog> createState() => _TopicDialogState();
}

class _TopicDialogState extends State<_TopicDialog> {
  late final _subject = TextEditingController(text: widget.subject);
  late final _name = TextEditingController(text: widget.name);
  final _keywords = TextEditingController();

  @override
  void dispose() {
    _subject.dispose();
    _name.dispose();
    _keywords.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final editing = widget.name.isNotEmpty;
    return AlertDialog(
      title: Text(editing ? l10n.topicsEdit : l10n.topicsAdd),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _subject,
            maxLength: 100,
            decoration: InputDecoration(
              labelText: l10n.fieldSubject,
              hintText: l10n.topicsSubjectHint,
            ),
          ),
          TextField(
            controller: _name,
            maxLength: 100,
            autofocus: widget.subject.isNotEmpty,
            decoration: InputDecoration(labelText: l10n.fieldTopic, hintText: l10n.topicsNameHint),
          ),
          if (!editing)
            TextField(
              controller: _keywords,
              decoration: InputDecoration(
                labelText: l10n.topicsKeywords,
                helperText: l10n.topicsKeywordsHelp,
                helperMaxLines: 3,
              ),
            ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(l10n.cancel)),
        FilledButton(
          onPressed: () {
            final subject = _subject.text.trim();
            final name = _name.text.trim();
            if (subject.isEmpty || name.isEmpty) return;
            Navigator.of(context).pop(
              NewTopic(
                subject: subject,
                name: name,
                keywords: [
                  for (final k in _keywords.text.split(','))
                    if (k.trim().isNotEmpty) k.trim(),
                ],
              ),
            );
          },
          child: Text(l10n.save),
        ),
      ],
    );
  }
}

/// The AI draft: every topic labelled as a suggestion; the learner keeps what fits.
class _DraftSheet extends StatefulWidget {
  const _DraftSheet({required this.draft});

  final TopicDraft draft;

  @override
  State<_DraftSheet> createState() => _DraftSheetState();
}

class _DraftSheetState extends State<_DraftSheet> {
  late final Set<int> _kept = {for (var i = 0; i < widget.draft.topics.length; i++) i};

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final topics = widget.draft.topics;
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.85),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              child: Text(
                l10n.topicsDraftLabel(widget.draft.questionsConsidered, widget.draft.model),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final (i, t) in topics.indexed)
                    CheckboxListTile(
                      value: _kept.contains(i),
                      title: Text('${t.subject} › ${t.name}'),
                      subtitle: t.keywords.isEmpty ? null : Text(t.keywords.join(', ')),
                      onChanged: (on) =>
                          setState(() => on == true ? _kept.add(i) : _kept.remove(i)),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _kept.isEmpty
                      ? null
                      : () => Navigator.of(context).pop([
                          for (final (i, t) in topics.indexed)
                            if (_kept.contains(i)) t,
                        ]),
                  child: Text(l10n.topicsDraftKeep(_kept.length)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
