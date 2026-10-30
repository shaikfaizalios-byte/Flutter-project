import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../core/localization/generated/app_localizations.dart';
import '../../ai/data/ai_repository.dart';
import '../../ai/presentation/ai_widgets.dart';
import '../../concepts/domain/concept.dart';
import '../../concepts/presentation/concept_form_screen.dart';
import '../application/learn_providers.dart';
import 'learn_widgets.dart';

/// A short AI lesson for a learner new to a topic, labelled as unchecked AI. From here the
/// learner can check what they learnt or keep the lesson as a concept.
class TopicLessonScreen extends StatelessWidget {
  const TopicLessonScreen({super.key, required this.choice});

  final TopicChoice choice;

  @override
  Widget build(BuildContext context) => LearnScreenFrame(
    title: AppLocalizations.of(context).learnLessonTitle(choice.topic),
    choice: choice,
    body: (request) => _LessonBody(request: request),
  );
}

class _LessonBody extends ConsumerWidget {
  const _LessonBody({required this.request});

  final LearnRequest request;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    return switch (ref.watch(topicLessonProvider(request))) {
      AsyncData(:final value) => _LessonView(lesson: value),
      AsyncError(:final error) => LearnError(
        error: error,
        onRetry: () => ref.invalidate(topicLessonProvider(request)),
      ),
      _ => LearnLoading(l10n.learnLessonLoading),
    };
  }
}

/// Lesson text as notes for a concept (the learner edits it before saving). The first line
/// keeps the AI label wherever the notes appear (revision cards, search).
String lessonNotes(AppLocalizations l10n, TopicLesson lesson) => [
  '[${l10n.learnAiLabel}]',
  lesson.overview,
  '${l10n.learnKeyPoints}:\n${lesson.keyPoints.map((p) => '• $p').join('\n')}',
  if (lesson.exampleQuestion != null)
    '${l10n.learnExample}:\n${lesson.exampleQuestion}\n${lesson.exampleAnswer}',
  if (lesson.commonMistakes.isNotEmpty)
    '${l10n.learnMistakes}:\n${lesson.commonMistakes.map((m) => '• $m').join('\n')}',
].join('\n\n');

class _LessonView extends StatefulWidget {
  const _LessonView({required this.lesson});

  final TopicLesson lesson;

  @override
  State<_LessonView> createState() => _LessonViewState();
}

class _LessonViewState extends State<_LessonView> {
  bool _answerShown = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final lesson = widget.lesson;

    Widget heading(String text) => Padding(
      padding: const EdgeInsets.only(top: AppSpacing.md, bottom: AppSpacing.xs),
      child: Semantics(header: true, child: Text(text, style: theme.textTheme.titleMedium)),
    );
    Widget bullets(List<String> items) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final item in items)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.xs),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('•  '),
                Expanded(child: SelectableText(item)),
              ],
            ),
          ),
      ],
    );

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: [
        Align(alignment: Alignment.centerLeft, child: AiLabel(l10n.learnAiLabel)),
        if (lesson.subject != null) Text(lesson.subject!, style: theme.textTheme.bodySmall),
        if (!lesson.confident) ...[
          const SizedBox(height: AppSpacing.sm),
          Card(
            color: theme.colorScheme.errorContainer,
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.sm),
              child: Text(
                l10n.learnNotConfident,
                style: TextStyle(color: theme.colorScheme.onErrorContainer),
              ),
            ),
          ),
        ],
        heading(l10n.learnOverview),
        SelectableText(lesson.overview),
        heading(l10n.learnKeyPoints),
        bullets(lesson.keyPoints),
        if (lesson.exampleQuestion != null) ...[
          heading(l10n.learnExample),
          SelectableText(lesson.exampleQuestion!),
          const SizedBox(height: AppSpacing.xs),
          if (_answerShown)
            SelectableText(lesson.exampleAnswer!)
          else
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: () => setState(() => _answerShown = true),
                child: Text(l10n.learnShowAnswer),
              ),
            ),
        ],
        if (lesson.commonMistakes.isNotEmpty) ...[
          heading(l10n.learnMistakes),
          bullets(lesson.commonMistakes),
        ],
        const SizedBox(height: AppSpacing.md),
        Text(l10n.learnCaution(lesson.model), style: theme.textTheme.bodySmall),
        const SizedBox(height: AppSpacing.md),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            FilledButton.icon(
              icon: const Icon(Icons.fact_check_outlined),
              label: Text(l10n.learnTestMe),
              onPressed: () => context.pushReplacement(
                AppRoutes.topicQuiz(lesson.topic, subject: lesson.subject),
              ),
            ),
            // A lesson the AI wasn't sure about can be read but not kept as notes.
            if (lesson.confident)
              OutlinedButton.icon(
                icon: const Icon(Icons.bookmark_add_outlined),
                label: Text(l10n.learnSaveConcept),
                onPressed: () => context.push(
                  AppRoutes.newConceptIn(lesson.subject ?? '', lesson.topic),
                  extra: ConceptPrefill(
                    notes: lessonNotes(l10n, lesson),
                    tags: const [aiGeneratedTag],
                    source: l10n.learnConceptSource(lesson.model),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}
