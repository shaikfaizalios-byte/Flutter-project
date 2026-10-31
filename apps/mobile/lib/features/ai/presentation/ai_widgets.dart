import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/localization/generated/app_localizations.dart';
import '../../../core/utils/app_log.dart';
import '../../../core/widgets/section_card.dart';
import '../../concepts/domain/concept.dart';
import '../../question_bank/data/questions_repository.dart';
import '../../question_bank/domain/question.dart';
import '../application/ai_providers.dart';
import '../data/ai_repository.dart';

/// Learner-facing text for AI and report failures.
String aiErrorMessage(AppLocalizations l10n, Object error) => switch (error) {
  NetworkFailure() || TimeoutFailure() => l10n.aiErrorOffline,
  ServerFailure(code: 'ai_disabled') => l10n.aiErrorDisabled,
  ServerFailure(code: 'ai_unavailable') => l10n.aiErrorUnavailable,
  ServerFailure(code: 'rate_limited') => l10n.aiErrorRateLimited,
  ServerFailure(code: 'plus_required') => l10n.aiErrorPlusRequired,
  ServerFailure(code: 'ai_allowance_used') => l10n.aiErrorAllowanceUsed,
  ServerFailure(code: 'not_eligible') => l10n.aiErrorNotEligible,
  ServerFailure(code: 'explanation_exists') => l10n.aiErrorExplanationExists,
  ServerFailure(code: 'topic_already_set') => l10n.aiErrorTopicSet,
  _ => l10n.aiErrorGeneric,
};

Future<T?> _run<T>(BuildContext context, Future<T> Function() action) async {
  final l10n = AppLocalizations.of(context);
  final messenger = ScaffoldMessenger.of(context);
  try {
    return await action();
  } on Object catch (error, stack) {
    if (error is! AppFailure) logError('AI action failed', error, stack);
    messenger.showSnackBar(
      SnackBar(content: Text(aiErrorMessage(l10n, error)), action: needsPlusAction(context, error)),
    );
    return null;
  }
}

/// "See Plus" on an error that a subscription (or next month) would solve.
SnackBarAction? needsPlusAction(BuildContext context, Object error) => switch (error) {
  ServerFailure(code: 'plus_required' || 'ai_allowance_used') => SnackBarAction(
    label: AppLocalizations.of(context).plusSee,
    onPressed: () => GoRouter.of(context).push(AppRoutes.plus),
  ),
  _ => null,
};

/// "AI-generated" badge used wherever AI text appears.
class AiLabel extends StatelessWidget {
  const AiLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Chip(
      visualDensity: VisualDensity.compact,
      avatar: Icon(Icons.auto_awesome, size: 16, color: colors.onTertiaryContainer),
      label: Text(text),
      // The chip theme's label colour (onSurface) is unreadable on this container.
      labelStyle: Theme.of(context).chipTheme.labelStyle
          ?.copyWith(color: colors.onTertiaryContainer),
      backgroundColor: colors.tertiaryContainer,
    );
  }
}

/// Question review: AI provenance, explanation drafts, topic suggestion and similar
/// questions. Shown only when AI is configured (drafts stay reviewable regardless).
class AiAssistCard extends ConsumerStatefulWidget {
  const AiAssistCard({super.key, required this.question, required this.onChanged});

  final BankQuestion question;

  /// Called with the refreshed question after an AI action.
  final ValueChanged<BankQuestion> onChanged;

  @override
  ConsumerState<AiAssistCard> createState() => _AiAssistCardState();
}

class _AiAssistCardState extends ConsumerState<AiAssistCard> {
  bool _busy = false;

  Future<void> _act(Future<void> Function(AiRepository ai) action) async {
    setState(() => _busy = true);
    await _run(context, () => action(ref.read(aiRepositoryProvider)));
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _refresh() async {
    final updated = await ref.read(questionsRepositoryProvider).get(widget.question.id);
    widget.onChanged(updated);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final q = widget.question;
    final enabled = ref.watch(aiStatusProvider).value?.enabled ?? false;
    final draft = q.aiExplanation;
    final eligible =
        q.origin == QuestionOrigin.source &&
        q.status == VerificationStatus.verified &&
        q.correctPosition != null &&
        !q.imageDependent;
    final needsExplanation = (q.explanation ?? '').trim().isEmpty;

    final children = <Widget>[
      if (q.ai != null)
        Text(
          [
            l10n.aiProvenance(q.ai!.model, q.ai!.promptVersion),
            if (q.ai!.sourceNote != null) q.ai!.sourceNote!,
            if (q.ai!.sourceQuestionId != null) l10n.aiBasedOnQuestion,
          ].join(' · '),
          style: theme.textTheme.bodySmall,
        ),
      if (q.origin == QuestionOrigin.source && needsExplanation && draft != null) ...[
        AiLabel(
          draft.status == AiDraftStatus.approved ? l10n.aiExplanationApproved : l10n.aiDraftLabel,
        ),
        if (!draft.modelConfident)
          Text(l10n.aiUnsure, style: TextStyle(color: theme.colorScheme.error)),
        const SizedBox(height: AppSpacing.xs),
        SelectableText(draft.text),
        if (draft.status == AiDraftStatus.draft)
          Wrap(
            spacing: AppSpacing.sm,
            children: [
              FilledButton.tonal(
                onPressed: _busy
                    ? null
                    : () => _act((ai) async {
                        await ai.reviewExplanation(draft.id, approve: true);
                        await _refresh();
                      }),
                child: Text(l10n.aiApprove),
              ),
              OutlinedButton(
                onPressed: _busy ? null : () => _editAndApprove(draft),
                child: Text(l10n.aiEditApprove),
              ),
              TextButton(
                onPressed: _busy
                    ? null
                    : () => _act((ai) async {
                        await ai.reviewExplanation(draft.id, approve: false);
                        await _refresh();
                      }),
                child: Text(l10n.reject),
              ),
            ],
          ),
      ],
      if (enabled && eligible && needsExplanation && draft == null)
        OutlinedButton.icon(
          icon: const Icon(Icons.auto_awesome),
          label: Text(l10n.aiDraftExplanation),
          onPressed: _busy
              ? null
              : () => _act((ai) async {
                  await ai.draftExplanation(q.id);
                  await _refresh();
                }),
        ),
      if (enabled && q.topicStatus == 'unassigned' && q.subject != null)
        OutlinedButton.icon(
          icon: const Icon(Icons.label_outline),
          label: Text(l10n.aiSuggestTopic),
          onPressed: _busy
              ? null
              : () => _act((ai) async {
                  final messenger = ScaffoldMessenger.of(context);
                  final (updated, suggested) = await ai.suggestTopic(q.id);
                  widget.onChanged(updated);
                  if (!suggested) {
                    messenger.showSnackBar(SnackBar(content: Text(l10n.aiNoTopic)));
                  }
                }),
        ),
      if (enabled && eligible)
        OutlinedButton.icon(
          icon: const Icon(Icons.library_add_outlined),
          label: Text(l10n.aiGenerateSimilar),
          onPressed: _busy ? null : () => _generate(q),
        ),
      if (enabled && q.origin == QuestionOrigin.source && !eligible && needsExplanation)
        Text(l10n.aiApproveFirst, style: theme.textTheme.bodySmall),
    ];
    if (children.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.md),
      child: SectionCard(
        icon: Icons.auto_awesome,
        title: l10n.aiAssistTitle,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: AppSpacing.sm,
          children: [
            ...children,
            Text(l10n.aiReviewNote, style: theme.textTheme.bodySmall),
          ],
        ),
      ),
    );
  }

  Future<void> _editAndApprove(AiExplanation draft) async {
    final text = await showDialog<String>(
      context: context,
      builder: (context) => _EditExplanationDialog(initial: draft.text),
    );
    if (text == null || text.isEmpty) return;
    await _act((ai) async {
      await ai.reviewExplanation(draft.id, approve: true, text: text);
      await _refresh();
    });
  }

  Future<void> _generate(BankQuestion source) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final choice = await showGenerateDialog(
      context,
      language: source.language,
      notice: l10n.aiGenerateFromQuestionNotice,
    );
    if (choice == null) return;
    await _act((ai) async {
      final result = await ai.generateFromQuestion(source, language: choice.$2, count: choice.$1);
      messenger.showSnackBar(SnackBar(content: Text(generatedMessage(l10n, result))));
    });
  }
}

String generatedMessage(AppLocalizations l10n, GeneratedQuestions result) => [
  l10n.aiGenerated(result.created.length),
  if (result.rejected > 0) l10n.aiGeneratedRejected(result.rejected),
].join(' ');

/// Asks how many questions (1–5) and in which language. Returns (count, language).
Future<(int, ContentLanguage)?> showGenerateDialog(
  BuildContext context, {
  required ContentLanguage language,
  required String notice,
}) => showDialog<(int, ContentLanguage)>(
  context: context,
  builder: (context) {
    var count = 3;
    var lang = language;
    final l10n = AppLocalizations.of(context);
    return StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        title: Text(l10n.aiGenerateTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(notice),
            const SizedBox(height: AppSpacing.md),
            SegmentedButton<int>(
              segments: [
                for (final n in const [1, 3, 5]) ButtonSegment(value: n, label: Text('$n')),
              ],
              selected: {count},
              onSelectionChanged: (s) => setState(() => count = s.first),
            ),
            const SizedBox(height: AppSpacing.sm),
            SegmentedButton<ContentLanguage>(
              segments: [
                ButtonSegment(value: ContentLanguage.english, label: Text(l10n.languageEnglish)),
                ButtonSegment(value: ContentLanguage.hindi, label: Text(l10n.languageHindi)),
              ],
              selected: {lang},
              onSelectionChanged: (s) => setState(() => lang = s.first),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(l10n.cancel)),
          FilledButton(
            onPressed: () => Navigator.of(context).pop((count, lang)),
            child: Text(l10n.aiGenerate),
          ),
        ],
      ),
    );
  },
);

/// Concept details: generate AI practice questions from the learner's own notes.
class ConceptAiButton extends ConsumerWidget {
  const ConceptAiButton({super.key, required this.concept});

  final Concept concept;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    if (!(ref.watch(aiStatusProvider).value?.enabled ?? false)) return const SizedBox.shrink();
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: OutlinedButton.icon(
        icon: const Icon(Icons.auto_awesome),
        label: Text(l10n.aiGenerateFromConcept),
        onPressed: () async {
          final messenger = ScaffoldMessenger.of(context);
          final choice = await showGenerateDialog(
            context,
            language: concept.language,
            notice: l10n.aiConceptNotice,
          );
          if (choice == null || !context.mounted) return;
          final result = await _run(
            context,
            () => ref
                .read(aiRepositoryProvider)
                .generateFromConcept(concept, language: choice.$2, count: choice.$1),
          );
          if (result != null) {
            messenger.showSnackBar(SnackBar(content: Text(generatedMessage(l10n, result))));
          }
        },
      ),
    );
  }
}

/// Lets a learner report a question as wrong or unclear (it goes back to review).
Future<void> reportQuestion(BuildContext context, WidgetRef ref, String questionId) async {
  final l10n = AppLocalizations.of(context);
  final messenger = ScaffoldMessenger.of(context);
  final report = await showDialog<(ReportReason, String)>(
    context: context,
    builder: (context) => const _ReportDialog(),
  );
  if (report == null || !context.mounted) return;
  final sent = await _run(
    context,
    () => ref.read(aiRepositoryProvider).report(questionId, report.$1, note: report.$2),
  );
  if (sent != null) messenger.showSnackBar(SnackBar(content: Text(l10n.reportSent)));
}

/// Owns its text controller so it is disposed with the dialog, not while it animates out.
class _EditExplanationDialog extends StatefulWidget {
  const _EditExplanationDialog({required this.initial});

  final String initial;

  @override
  State<_EditExplanationDialog> createState() => _EditExplanationDialogState();
}

class _EditExplanationDialogState extends State<_EditExplanationDialog> {
  late final _controller = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(l10n.aiEditApprove),
      content: TextField(controller: _controller, minLines: 3, maxLines: 10),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(l10n.cancel)),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_controller.text.trim()),
          child: Text(l10n.aiApprove),
        ),
      ],
    );
  }
}

class _ReportDialog extends StatefulWidget {
  const _ReportDialog();

  @override
  State<_ReportDialog> createState() => _ReportDialogState();
}

class _ReportDialogState extends State<_ReportDialog> {
  final _note = TextEditingController();
  var _reason = ReportReason.wrongAnswer;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(l10n.reportTitle),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RadioGroup<ReportReason>(
              groupValue: _reason,
              onChanged: (v) => setState(() => _reason = v ?? _reason),
              child: Column(
                children: [
                  for (final r in ReportReason.values)
                    RadioListTile<ReportReason>(
                      contentPadding: EdgeInsets.zero,
                      value: r,
                      title: Text(reportReasonLabel(l10n, r)),
                    ),
                ],
              ),
            ),
            TextField(
              controller: _note,
              maxLength: 300,
              decoration: InputDecoration(labelText: l10n.reportNote),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(l10n.cancel)),
        FilledButton(
          onPressed: () => Navigator.of(context).pop((_reason, _note.text.trim())),
          child: Text(l10n.reportSend),
        ),
      ],
    );
  }
}

String reportReasonLabel(AppLocalizations l10n, ReportReason reason) => switch (reason) {
  ReportReason.wrongAnswer => l10n.reportWrongAnswer,
  ReportReason.unclear => l10n.reportUnclear,
  ReportReason.incorrectContent => l10n.reportIncorrectContent,
  ReportReason.other => l10n.reportOther,
};
