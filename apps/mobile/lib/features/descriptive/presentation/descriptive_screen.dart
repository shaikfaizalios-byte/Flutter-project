import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../core/localization/generated/app_localizations.dart';
import '../../../core/widgets/rich_question_text.dart';
import '../../ai/application/ai_providers.dart';
import '../../ai/presentation/ai_widgets.dart';
import '../../exams/application/active_exam.dart';
import '../../plus/presentation/plus_prompt.dart';
import '../../settings/application/app_preferences.dart';
import '../application/descriptive_providers.dart';
import '../data/descriptive_repository.dart';
import '../domain/descriptive_models.dart';

/// Marks without a needless ".0".
String marksText(double marks) =>
    marks == marks.roundToDouble() ? marks.toInt().toString() : marks.toString();

String descriptiveLevelLabel(AppLocalizations l10n, String level) => switch (level) {
  'define_list' => l10n.descriptiveLevelDefine,
  'short_explanation' => l10n.descriptiveLevelShort,
  'full_explanation' => l10n.descriptiveLevelFull,
  'analyse_compare' => l10n.descriptiveLevelAnalyse,
  'case_evaluate' => l10n.descriptiveLevelCase,
  'paper' => l10n.descriptiveLevelPaper,
  _ => level,
};

/// Written practice on a topic: five questions, each asking for more, with estimated marks.
class DescriptiveScreen extends ConsumerWidget {
  const DescriptiveScreen({super.key, required this.topicId, required this.topicName});

  final String topicId;
  final String topicName;

  int _paperQuestions(WidgetRef ref) {
    final topics = ref.watch(descriptiveOverviewProvider).value?.topics ?? const [];
    return topics.where((t) => t.topicId == topicId).firstOrNull?.paperQuestions ?? 0;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final exam = ref.watch(activeExamProvider);
    final status = ref.watch(aiStatusProvider).value;

    final Widget body;
    if (exam == null || status == null) {
      body = const Center(child: CircularProgressIndicator());
    } else if (status.enabled && status.needsPlus) {
      body = PlusPrompt(message: l10n.descriptivePlusMessage);
    } else if (!status.enabled) {
      body = Text(l10n.ladderAiOff);
    } else {
      final language = ref
          .watch(appPreferencesProvider)
          .aiLanguageFor(Localizations.localeOf(context));
      final key = (examCode: exam, topicId: topicId, language: language);
      final state = ref.watch(descriptiveRunProvider(key));
      final run = ref.read(descriptiveRunProvider(key).notifier);
      body = switch (state.stage) {
        DescriptiveStage.intro => _Intro(
          paperQuestions: _paperQuestions(ref),
          onStart: run.start,
          onPapers: () => run.start(fromPapers: true),
        ),
        DescriptiveStage.writing => _Waiting(text: l10n.descriptiveWriting),
        DescriptiveStage.question ||
        DescriptiveStage.marking => _Step(key: ValueKey(state.current), state: state, run: run),
        DescriptiveStage.finished => _Finished(state: state),
        DescriptiveStage.failed => _Failed(state: state, run: run),
      };
    }
    return Scaffold(
      appBar: AppBar(title: Text(topicName)),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: AppSpacing.maxContentWidth),
          child: ListView(padding: const EdgeInsets.all(AppSpacing.md), children: [body]),
        ),
      ),
    );
  }
}

class _Intro extends StatelessWidget {
  const _Intro({required this.paperQuestions, required this.onStart, required this.onPapers});

  final int paperQuestions;
  final Future<void> Function() onStart;
  final Future<void> Function() onPapers;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: AppSpacing.sm,
      children: [
        Text(l10n.descriptiveIntro),
        Text(l10n.descriptivePrivacy, style: Theme.of(context).textTheme.bodySmall),
        const _EstimateNote(),
        FilledButton(onPressed: onStart, child: Text(l10n.descriptiveStart)),
        if (paperQuestions > 0)
          OutlinedButton(
            onPressed: onPapers,
            child: Text(l10n.descriptiveUsePapers(paperQuestions)),
          ),
      ],
    );
  }
}

class _Waiting extends StatelessWidget {
  const _Waiting({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) =>
      Column(spacing: AppSpacing.md, children: [const CircularProgressIndicator(), Text(text)]);
}

class _EstimateNote extends StatelessWidget {
  const _EstimateNote();

  @override
  Widget build(BuildContext context) => Text(
    AppLocalizations.of(context).descriptiveEstimateLabel,
    style: Theme.of(context).textTheme.labelMedium,
  );
}

class _Step extends ConsumerStatefulWidget {
  const _Step({super.key, required this.state, required this.run});

  final DescriptiveRunState state;
  final DescriptiveRun run;

  @override
  ConsumerState<_Step> createState() => _StepState();
}

class _StepState extends ConsumerState<_Step> {
  final _answer = TextEditingController();
  bool _fromPhoto = false;
  bool _reading = false;
  bool _unclear = false;
  Object? _photoFailure;

  @override
  void dispose() {
    _answer.dispose();
    super.dispose();
  }

  /// Adds what was read to the answer box, for the learner to correct before sending.
  Future<void> _readPhoto() async {
    final photo = await ref.read(photoPickerProvider)();
    if (photo == null || !mounted) return;
    setState(() {
      _reading = true;
      _photoFailure = null;
    });
    try {
      final reading = await ref
          .read(descriptiveRepositoryProvider)
          .readPhoto(photo.name, photo.bytes);
      if (!mounted) return;
      setState(() {
        final before = _answer.text.trim();
        _answer.text = before.isEmpty ? reading.text : '$before\n${reading.text}';
        _fromPhoto = true;
        _unclear = reading.unclear;
      });
    } on Object catch (error) {
      if (mounted) setState(() => _photoFailure = error);
    } finally {
      if (mounted) setState(() => _reading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final state = widget.state;
    final step = state.step!;
    final result = step.result;
    final marking = state.stage == DescriptiveStage.marking;
    final failure = state.failure ?? _photoFailure;
    final total = state.session!.steps.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: AppSpacing.sm,
      children: [
        Text(
          l10n.descriptiveStepOf(step.step, total, descriptiveLevelLabel(l10n, step.level)),
          style: theme.textTheme.titleMedium,
        ),
        Text(
          l10n.descriptiveMarksAndLength(marksText(step.marks), step.wordLimit),
          style: theme.textTheme.bodySmall,
        ),
        Text(
          step.fromPaper
              ? l10n.descriptiveFromPaper(step.paperLabel ?? '')
              : l10n.descriptiveAiQuestion,
          style: theme.textTheme.bodySmall,
        ),
        RichQuestionText(step.stem ?? '', style: theme.textTheme.bodyLarge),
        if (result != null)
          _Result(
            result: result,
            fromPaper: step.fromPaper,
            last: step.step == total,
            onNext: widget.run.next,
          )
        else if (marking)
          _Waiting(text: l10n.descriptiveMarking)
        else ...[
          TextField(
            controller: _answer,
            minLines: 6,
            maxLines: 16,
            maxLength: 20000,
            decoration: InputDecoration(
              labelText: l10n.descriptiveYourAnswer,
              border: const OutlineInputBorder(),
              alignLabelWithHint: true,
            ),
          ),
          if (_fromPhoto) Text(l10n.descriptiveCheckPhoto, style: theme.textTheme.bodySmall),
          if (_unclear)
            Text(
              l10n.descriptivePhotoUnclear,
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error),
            ),
          if (failure != null)
            Text(
              aiErrorMessage(l10n, failure),
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error),
            ),
          OutlinedButton.icon(
            onPressed: _reading ? null : _readPhoto,
            icon: const Icon(Icons.photo_outlined),
            label: Text(_reading ? l10n.descriptiveReadingPhoto : l10n.descriptiveFromPhoto),
          ),
          ListenableBuilder(
            listenable: _answer,
            builder: (context, _) => FilledButton(
              onPressed: _answer.text.trim().isEmpty
                  ? null
                  : () => unawaited(widget.run.submit(_answer.text.trim(), fromPhoto: _fromPhoto)),
              child: Text(l10n.descriptiveSubmit),
            ),
          ),
        ],
      ],
    );
  }
}

class _Result extends StatelessWidget {
  const _Result({
    required this.result,
    required this.fromPaper,
    required this.last,
    required this.onNext,
  });

  final DescriptiveResult result;
  final bool fromPaper;
  final bool last;
  final Future<void> Function() onNext;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final low = result.low;
    final high = result.high;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: AppSpacing.xs,
      children: [
        const _EstimateNote(),
        Text(
          l10n.descriptiveMarks(marksText(result.marks), marksText(result.marksPossible)),
          style: theme.textTheme.titleLarge,
        ),
        if (low != null && high != null)
          Text(l10n.descriptiveRange(marksText(low), marksText(high))),
        Text(l10n.descriptiveWordCount(result.wordCount), style: theme.textTheme.bodySmall),
        const SizedBox(height: AppSpacing.xs),
        Text(l10n.descriptiveByPoint, style: theme.textTheme.labelLarge),
        if (fromPaper) Text(l10n.descriptiveRubricNote, style: theme.textTheme.bodySmall),
        for (final point in result.points)
          ListTile(
            contentPadding: EdgeInsets.zero,
            dense: true,
            title: Text(point.point),
            subtitle: Text(point.comment),
            trailing: Text('${marksText(point.awarded)} / ${marksText(point.marks)}'),
          ),
        if (result.missingPoints.isNotEmpty) ...[
          Text(l10n.descriptiveMissing, style: theme.textTheme.labelLarge),
          for (final point in result.missingPoints) Text('• $point'),
        ],
        if (result.structure.isNotEmpty) Text(l10n.descriptiveStructure(result.structure)),
        if (result.relevance.isNotEmpty) Text(l10n.descriptiveRelevance(result.relevance)),
        if (result.length.isNotEmpty) Text(l10n.descriptiveLength(result.length)),
        const SizedBox(height: AppSpacing.xs),
        Text(
          result.modelAnswerFromPaper
              ? l10n.descriptiveAnswerFromPaper
              : l10n.descriptiveModelAnswer,
          style: theme.textTheme.labelLarge,
        ),
        RichQuestionText(result.modelAnswer),
        const SizedBox(height: AppSpacing.sm),
        FilledButton(
          onPressed: onNext,
          child: Text(last ? l10n.ladderSeeResults : l10n.ladderNext),
        ),
      ],
    );
  }
}

class _Finished extends StatelessWidget {
  const _Finished({required this.state});

  final DescriptiveRunState state;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final session = state.session!;
    final (marks, possible) = session.totals;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: AppSpacing.xs,
      children: [
        Text(l10n.ladderResultsTitle, style: theme.textTheme.titleLarge),
        const _EstimateNote(),
        Text(l10n.descriptiveMarks(marksText(marks), marksText(possible))),
        for (final step in session.steps)
          ListTile(
            contentPadding: EdgeInsets.zero,
            dense: true,
            title: Text(descriptiveLevelLabel(l10n, step.level)),
            trailing: Text('${marksText(step.result?.marks ?? 0)} / ${marksText(step.marks)}'),
          ),
      ],
    );
  }
}

class _Failed extends StatelessWidget {
  const _Failed({required this.state, required this.run});

  final DescriptiveRunState state;
  final DescriptiveRun run;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final failure = state.failure;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: AppSpacing.sm,
      children: [
        Text(failure == null ? l10n.ladderNoConnection : aiErrorMessage(l10n, failure)),
        FilledButton(onPressed: run.retry, child: Text(l10n.descriptiveTryAgain)),
      ],
    );
  }
}
