import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/app_features.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/localization/generated/app_localizations.dart';
import '../../../core/utils/clock.dart';
import '../../../core/widgets/empty_state.dart';
import '../../ai/presentation/ai_widgets.dart';
import '../../question_bank/domain/question.dart';
import '../../question_bank/presentation/figure_view.dart';
import '../../question_bank/presentation/question_widgets.dart';
import '../../question_bank/presentation/shared_report.dart';
import '../application/practice_providers.dart';
import '../../../core/localization/content_language.dart';
import '../../../core/widgets/rich_question_text.dart';
import '../domain/cbt.dart';
import '../domain/practice_models.dart';
import 'format_answers.dart';
import 'result_view.dart';
import '../domain/mistake_reason.dart';

part 'cbt_view.dart';

/// A practice session or mock test. Shows the result once the session is submitted.
class SessionScreen extends ConsumerWidget {
  const SessionScreen({super.key, required this.sessionId});

  final String sessionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(sessionControllerProvider(sessionId));
    return switch (state) {
      AsyncData(:final value) when value.session.submitted => Scaffold(
        appBar: AppBar(title: Text(l10n.resultTitle)),
        body: ResultView(session: value.session),
      ),
      AsyncData(:final value)
          when value.session.cbt != null && ref.watch(appFeaturesProvider).examProfiles =>
        _CbtView(sessionId: sessionId, state: value),
      AsyncData(:final value) => _SessionBody(sessionId: sessionId, state: value),
      AsyncError(:final error) => Scaffold(
        appBar: AppBar(),
        body: EmptyState(
          icon: Icons.cloud_off,
          title: l10n.sessionLoadError,
          message: error is NetworkFailure || error is TimeoutFailure
              ? l10n.sessionOfflineOpen
              : null,
          action: OutlinedButton(
            onPressed: () => ref.invalidate(sessionControllerProvider(sessionId)),
            child: Text(l10n.retry),
          ),
        ),
      ),
      _ => Scaffold(
        appBar: AppBar(),
        body: const Center(child: CircularProgressIndicator()),
      ),
    };
  }
}

class _SessionBody extends ConsumerWidget {
  const _SessionBody({required this.sessionId, required this.state});

  final String sessionId;
  final SessionState state;

  SessionController _controller(WidgetRef ref) =>
      ref.read(sessionControllerProvider(sessionId).notifier);

  Future<void> _submit(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final unanswered = state.session.items.length - state.session.answeredCount;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.sessionSubmitTitle),
        content: Text(l10n.sessionUnanswered(unanswered)),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: Text(l10n.cancel)),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.sessionSubmit),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _controller(ref).submit();
    } on Object {
      messenger.showSnackBar(SnackBar(content: Text(l10n.sessionSubmitFailed)));
    }
  }

  Future<void> _finishSection(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final section = state.session.openSection;
    if (section == null) return;
    final unanswered = [
      for (final i in state.session.items)
        if (section.contains(i.position) && !i.answered) i,
    ].length;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.sessionFinishSectionTitle),
        content: Text(l10n.sessionFinishSectionMessage(unanswered)),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: Text(l10n.cancel)),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.sessionFinishSection),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _controller(ref).finishSection();
    } on Object {
      messenger.showSnackBar(SnackBar(content: Text(l10n.sessionSubmitFailed)));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final session = state.session;
    final item = state.item;
    final shown = item.translationIn(ref.watch(shownLanguageProvider));
    final isMock = session.mode == SessionMode.mock;
    // Mocks and the starter check: answers can change and are marked after submitting.
    final testLike = session.mode.testLike;
    final last = state.current == session.items.length - 1;
    final open = session.openSection;
    final canGoBack =
        state.current > 0 && session.isOpen(session.items[state.current - 1].position);
    // The open section's last question (another section follows): finish it to move on.
    final endOfSection = open != null && !last && item.position == open.lastPosition;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.sessionQuestionOf(state.current + 1, session.items.length)),
        actions: [
          if (isMock) _Countdown(sessionId: sessionId, state: state),
          if (item.questionId != null && !item.shared && !session.offline)
            IconButton(
              tooltip: item.bookmarked ? l10n.sessionRemoveBookmark : l10n.sessionBookmark,
              icon: Icon(item.bookmarked ? Icons.bookmark : Icons.bookmark_border),
              onPressed: () => _controller(ref).toggleBookmark(),
            ),
          if (item.questionId != null && !session.offline)
            IconButton(
              tooltip: item.shared ? l10n.sharedReportTitle : l10n.reportTitle,
              icon: const Icon(Icons.flag_outlined),
              onPressed: () => item.shared
                  ? reportSharedContent(context, ref, item.questionId!)
                  : reportQuestion(context, ref, item.questionId!),
            ),
          if (isMock)
            IconButton(
              tooltip: l10n.sessionPalette,
              icon: const Icon(Icons.grid_view),
              onPressed: () => _showPalette(context, ref),
            ),
          TextButton(
            onPressed: state.submitting ? null : () => _submit(context, ref),
            child: Text(testLike ? l10n.sessionSubmit : l10n.sessionFinish),
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
              if (open != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: Card(
                    color: Theme.of(context).colorScheme.secondaryContainer,
                    child: ListTile(
                      leading: const Icon(Icons.timer_outlined),
                      title: Text(
                        l10n.sessionSectionOf(
                          session.currentSection! + 1,
                          session.sections.length,
                          open.name,
                        ),
                      ),
                      subtitle: Text(l10n.sessionSectionHint(open.minutes)),
                    ),
                  ),
                ),
              if (session.mode == SessionMode.diagnostic)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: Card(
                    color: Theme.of(context).colorScheme.secondaryContainer,
                    child: ListTile(
                      leading: const Icon(Icons.flag_outlined),
                      title: Text(l10n.starterCheckTitle),
                      subtitle: Text(l10n.starterCheckHint),
                    ),
                  ),
                ),
              if (session.offline)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: Card(
                    color: Theme.of(context).colorScheme.secondaryContainer,
                    child: ListTile(
                      leading: const Icon(Icons.cloud_off),
                      title: Text(l10n.offlineSessionNote),
                    ),
                  ),
                ),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.xs,
                children: [
                  if (item.origin != null)
                    OriginChip(origin: item.origin!, librarySource: item.librarySource),
                  if (!item.verified)
                    Chip(
                      visualDensity: VisualDensity.compact,
                      avatar: const Icon(Icons.warning_amber, size: 16),
                      label: Text(l10n.sessionNotReviewed),
                    ),
                  if (item.section != null)
                    Chip(visualDensity: VisualDensity.compact, label: Text(item.section!)),
                ],
              ),
              if (item.shared && item.sharedSource != null)
                Text(
                  l10n.sharedBankSource(item.sharedSource!),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              if (item.sourceFilename != null && item.sourcePage != null)
                Text(
                  l10n.questionSource(item.sourceFilename!, item.sourcePage!),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              if (item.passage != null) ...[
                const SizedBox(height: AppSpacing.sm),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: RichQuestionText(item.passage!.text),
                  ),
                ),
              ],
              const SizedBox(height: AppSpacing.md),
              if (item.translations.isNotEmpty && ref.watch(appFeaturesProvider).examProfiles)
                _LanguageChoice(item: item),
              if (item.stem == null)
                Text(l10n.sessionQuestionRemoved)
              else
                RichQuestionText(
                  shown?.stem ?? item.stem!,
                  key: ValueKey('stem-${item.position}-${shown?.language}'),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              if (item.questionId != null)
                QuestionFigures(questionId: item.questionId!, figures: item.figures),
              const SizedBox(height: AppSpacing.md),
              if (item.isTyped)
                _TypedAnswerBox(
                  key: ValueKey('typed-${item.position}'),
                  item: item,
                  locked: !testLike && item.answered,
                  onSubmit: (text) => _controller(ref).submitTyped(text),
                ),
              if (item.takesResponse)
                ResponseAnswer(
                  key: ValueKey('response-${item.position}'),
                  item: item,
                  locked: !testLike && item.answered,
                  onSubmit: (response) => _controller(ref).submitResponse(response),
                ),
              if (!item.takesResponse)
                for (final option in item.options)
                  _OptionTile(
                    label: option.label,
                    text: shown?.option(option.position) ?? option.text,
                    figure: item.questionId == null
                        ? null
                        : switch (optionFigure(item.figures, option.position)) {
                            final f? => QuestionFigureView(
                              questionId: item.questionId!,
                              figure: f,
                              zoomable: false,
                            ),
                            null => null,
                          },
                    selected: item.selectedPosition == option.position,
                    correct: item.feedback?.correctPosition == option.position,
                    showFeedback: item.feedback != null,
                    onTap: () => _controller(ref).select(option.position),
                  ),
              if (state.queuedPositions.contains(item.position)) ...[
                const SizedBox(height: AppSpacing.sm),
                Row(
                  children: [
                    const Icon(Icons.cloud_upload_outlined, size: 18),
                    const SizedBox(width: AppSpacing.xs),
                    Expanded(
                      child: Text(
                        testLike ? l10n.sessionSavedOffline : l10n.sessionFeedbackOffline,
                      ),
                    ),
                  ],
                ),
              ],
              if (item.feedback != null) _FeedbackPanel(item: item, sessionId: sessionId),
            ],
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            children: [
              OutlinedButton(
                onPressed: canGoBack ? () => _controller(ref).goTo(state.current - 1) : null,
                child: Text(l10n.sessionPrevious),
              ),
              const Spacer(),
              if (endOfSection)
                FilledButton(
                  onPressed: state.submitting ? null : () => _finishSection(context, ref),
                  child: Text(l10n.sessionFinishSection),
                )
              else if (last)
                FilledButton(
                  onPressed: state.submitting ? null : () => _submit(context, ref),
                  child: Text(testLike ? l10n.sessionSubmit : l10n.sessionFinish),
                )
              else
                FilledButton(
                  onPressed: () => _controller(ref).goTo(state.current + 1),
                  child: Text(l10n.sessionNext),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _showPalette(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.md, 0, AppSpacing.md, AppSpacing.md),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l10n.sessionPalette, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: AppSpacing.xs,
                runSpacing: AppSpacing.xs,
                children: [
                  for (final (index, item) in state.session.items.indexed)
                    if (state.session.isOpen(item.position))
                      ChoiceChip(
                        label: Text('${index + 1}'),
                        selected: item.selectedPosition != null,
                        onSelected: (_) {
                          Navigator.of(sheetContext).pop();
                          _controller(ref).goTo(index);
                        },
                      ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Which language the session's questions are read in. Null: as the paper printed them.
class ShownLanguage extends Notifier<String?> {
  @override
  String? build() => null;

  void show(String? language) => state = language;
}

final shownLanguageProvider = NotifierProvider.autoDispose<ShownLanguage, String?>(
  ShownLanguage.new,
);

/// Switches a question between the paper's language and its linked translations.
class _LanguageChoice extends ConsumerWidget {
  const _LanguageChoice({required this.item});

  final SessionItemView item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final shown = item.translationIn(ref.watch(shownLanguageProvider))?.language;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Wrap(
        spacing: AppSpacing.sm,
        children: [
          ChoiceChip(
            label: Text(l10n.sessionOriginalLanguage),
            selected: shown == null,
            onSelected: (_) => ref.read(shownLanguageProvider.notifier).show(null),
          ),
          for (final translation in item.translations)
            ChoiceChip(
              label: Text(contentLanguageName(l10n, ContentLanguage(translation.language))),
              selected: shown == translation.language,
              onSelected: (_) =>
                  ref.read(shownLanguageProvider.notifier).show(translation.language),
            ),
        ],
      ),
    );
  }
}

/// Answer box of a typed-in question (e.g. CAT TITA). Number keyboard for numeric answers.
class _TypedAnswerBox extends StatefulWidget {
  const _TypedAnswerBox({
    super.key,
    required this.item,
    required this.locked,
    required this.onSubmit,
  });

  final SessionItemView item;
  final bool locked;
  final Future<bool> Function(String text) onSubmit;

  @override
  State<_TypedAnswerBox> createState() => _TypedAnswerBoxState();
}

class _TypedAnswerBoxState extends State<_TypedAnswerBox> {
  late final _controller = TextEditingController(text: widget.item.typedAnswer ?? '');

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    if (_controller.text.trim().isEmpty) return;
    FocusScope.of(context).unfocus();
    widget.onSubmit(_controller.text);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: AppSpacing.sm,
      children: [
        TextField(
          controller: _controller,
          enabled: !widget.locked,
          maxLength: 100,
          keyboardType: widget.item.typedAnswerNumeric
              ? const TextInputType.numberWithOptions(decimal: true, signed: true)
              : TextInputType.text,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _submit(),
          decoration: InputDecoration(
            labelText: l10n.sessionTypedAnswerLabel,
            helperText: l10n.sessionTypedAnswerHelp,
          ),
        ),
        if (!widget.locked)
          FilledButton(onPressed: _submit, child: Text(l10n.sessionTypedAnswerSave)),
      ],
    );
  }
}

/// What the official key said about this question, when it's more than one plain answer.
String? keyNoteText(AppLocalizations l10n, SessionItemView item, AnswerFeedback feedback) {
  String label(int position) =>
      item.options.where((o) => o.position == position).firstOrNull?.label ?? '$position';
  return switch (feedback.keyNote) {
    'dropped' => l10n.sessionKeyDropped,
    'several' => l10n.sessionKeySeveral(feedback.acceptedPositions.map(label).join(', ')),
    'changed' => l10n.sessionKeyChanged,
    _ => null,
  };
}

class _OptionTile extends StatelessWidget {
  const _OptionTile({
    required this.label,
    required this.text,
    required this.selected,
    required this.correct,
    required this.showFeedback,
    required this.onTap,
    this.figure,
  });

  final String label;
  final String text;

  /// The option's figure from the paper, when the option is a picture.
  final Widget? figure;
  final bool selected;
  final bool correct;
  final bool showFeedback;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final (background, icon) = switch ((showFeedback, selected, correct)) {
      (true, _, true) => (colors.primaryContainer, Icons.check_circle),
      (true, true, false) => (colors.errorContainer, Icons.cancel),
      (false, true, _) => (colors.secondaryContainer, Icons.radio_button_checked),
      _ => (null, Icons.radio_button_unchecked),
    };
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Semantics(
        selected: selected,
        button: true,
        child: Card(
          color: background,
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Row(
                children: [
                  Icon(icon),
                  const SizedBox(width: AppSpacing.sm),
                  Text('($label)  ', style: const TextStyle(fontWeight: FontWeight.bold)),
                  Expanded(
                    child: figure == null
                        ? RichQuestionText(text, selectable: false)
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            spacing: AppSpacing.xs,
                            children: [
                              if (text.isNotEmpty) RichQuestionText(text, selectable: false),
                              figure!,
                            ],
                          ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FeedbackPanel extends ConsumerWidget {
  const _FeedbackPanel({required this.item, required this.sessionId});

  final SessionItemView item;
  final String sessionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final feedback = item.feedback!;
    final correctLabel =
        item.options.where((o) => o.position == feedback.correctPosition).firstOrNull?.label ??
        '${feedback.correctPosition ?? ''}';
    return Card(
      margin: const EdgeInsets.only(top: AppSpacing.sm),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (feedback.isCorrect != null)
              Text(
                feedback.isCorrect! ? l10n.sessionCorrect : l10n.sessionIncorrect,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: feedback.isCorrect!
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).colorScheme.error,
                ),
              ),
            Text(switch (correctAnswerText(item, feedback)) {
              final String words => l10n.sessionCorrectTypedAnswer(words),
              null =>
                feedback.correctTypedAnswer != null
                    ? l10n.sessionCorrectTypedAnswer(feedback.correctTypedAnswer!)
                    : l10n.sessionCorrectAnswer(correctLabel),
            }),
            if (keyNoteText(l10n, item, feedback) case final String note) Text(note),
            if (feedback.percentRight != null)
              Text(l10n.sessionPercentRight(feedback.percentRight!)),
            if (feedback.explanation != null && feedback.explanation!.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.sm),
              if (feedback.explanationByAi) AiLabel(l10n.aiExplanationLabel),
              RichQuestionText(feedback.explanation!),
            ],
            if (feedback.isCorrect == false) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(l10n.mistakeAsk, style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: AppSpacing.xs),
              Wrap(
                spacing: AppSpacing.xs,
                runSpacing: AppSpacing.xs,
                children: [
                  for (final reason in MistakeReason.values)
                    ChoiceChip(
                      label: Text(reason.label(l10n)),
                      selected: item.mistakeReason == reason,
                      onSelected: (_) => ref
                          .read(sessionControllerProvider(sessionId).notifier)
                          .setMistakeReason(item.position, reason),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Mock-test countdown from the server deadline. Submits (idempotently) at zero.
class _Countdown extends ConsumerStatefulWidget {
  const _Countdown({required this.sessionId, required this.state});

  final String sessionId;
  final SessionState state;

  @override
  ConsumerState<_Countdown> createState() => _CountdownState();
}

class _CountdownState extends ConsumerState<_Countdown> {
  Timer? _ticker;
  bool _submitting = false;
  DateTime? _retryAfter;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  void _tick() {
    if (!mounted) return;
    setState(() {});
    final left = widget.state.remainingSeconds(ref.read(clockProvider)());
    final now = DateTime.now();
    if (left == 0 && !_submitting && (_retryAfter == null || now.isAfter(_retryAfter!))) {
      _submitting = true;
      final lastSection =
          widget.state.session.currentSection == widget.state.session.sections.length - 1;
      widget.state.session.sectional && !lastSection ? _nextSection() : _submitOnTimeUp();
    }
  }

  /// A section's time is up: the server opened the next one; load it.
  Future<void> _nextSection() async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(sessionControllerProvider(widget.sessionId).notifier).refresh();
      messenger.showSnackBar(SnackBar(content: Text(l10n.sessionSectionTimeUp)));
    } on Object {
      _retryAfter = DateTime.now().add(const Duration(seconds: 15));
    }
    _submitting = false;
  }

  Future<void> _submitOnTimeUp() async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(sessionControllerProvider(widget.sessionId).notifier).submit();
      messenger.showSnackBar(SnackBar(content: Text(l10n.sessionTimeUp)));
    } on Object {
      // Offline: answers stay queued and the server treats its deadline as final. Retry
      // shortly; opening the session again also shows the submitted result.
      _retryAfter = DateTime.now().add(const Duration(seconds: 15));
      _submitting = false;
    }
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final left = widget.state.remainingSeconds(ref.watch(clockProvider)()) ?? 0;
    final text = formatClock(left);
    final urgent = left <= 300;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
      child: Center(
        child: Semantics(
          label: l10n.sessionTimeLeft(text),
          child: Text(
            text,
            style: TextStyle(
              fontFeatures: const [FontFeature.tabularFigures()],
              fontWeight: FontWeight.bold,
              color: urgent ? Theme.of(context).colorScheme.error : null,
            ),
          ),
        ),
      ),
    );
  }
}

/// 3725 -> "1:02:05", 125 -> "02:05".
String formatClock(int seconds) {
  final h = seconds ~/ 3600;
  final m = (seconds % 3600) ~/ 60;
  final s = seconds % 60;
  String two(int v) => v.toString().padLeft(2, '0');
  return h > 0 ? '$h:${two(m)}:${two(s)}' : '${two(m)}:${two(s)}';
}
