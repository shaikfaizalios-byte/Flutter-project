import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../core/localization/generated/app_localizations.dart';
import '../../../core/widgets/section_card.dart';
import '../../ai/application/ai_providers.dart';
import '../../ai/data/ai_repository.dart';
import '../../exams/application/active_exam.dart';
import '../../mastery/application/mastery_providers.dart';
import '../../plus/presentation/plus_prompt.dart';

/// The three ways to start: learn a new topic, check one you know, or analyse a paper.
/// Learning and checking need AI; analysing a paper works without it.
class StartOptionsCard extends ConsumerWidget {
  const StartOptionsCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    if (ref.watch(activeExamProvider) == null) return const SizedBox.shrink();
    final status = ref.watch(aiStatusProvider).value;
    final aiOn = status?.enabled ?? false;
    final needsPlus = status?.needsPlus ?? false;
    final aiReady = aiOn && !needsPlus;

    Future<void> pickThen(String Function(TopicChoice) route) async {
      final choice = await pickTopic(context);
      if (choice != null && context.mounted) await context.push(route(choice));
    }

    return SectionCard(
      icon: Icons.route_outlined,
      title: l10n.learnStartTitle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Option(
            icon: Icons.school_outlined,
            title: l10n.learnOptionLearn,
            hint: aiOn ? l10n.learnOptionLearnHint : l10n.learnNeedsAi,
            onTap: aiReady
                ? () => pickThen((c) => AppRoutes.topicLesson(c.topic, subject: c.subject))
                : null,
          ),
          _Option(
            icon: Icons.fact_check_outlined,
            title: l10n.learnOptionTest,
            hint: aiOn ? l10n.learnOptionTestHint : l10n.learnNeedsAi,
            onTap: aiReady
                ? () => pickThen((c) => AppRoutes.topicQuiz(c.topic, subject: c.subject))
                : null,
          ),
          if (needsPlus) ...[
            PlusPrompt(message: l10n.learnPlusMessage),
            const SizedBox(height: AppSpacing.xs),
          ],
          _Option(
            icon: Icons.picture_as_pdf_outlined,
            title: l10n.learnOptionPaper,
            hint: l10n.learnOptionPaperHint,
            onTap: () => context.push(AppRoutes.documents),
          ),
        ],
      ),
    );
  }
}

class _Option extends StatelessWidget {
  const _Option({required this.icon, required this.title, required this.hint, this.onTap});

  final IconData icon;
  final String title;
  final String hint;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: EdgeInsets.zero,
    enabled: onTap != null,
    leading: Icon(icon),
    title: Text(title),
    subtitle: Text(hint),
    trailing: const Icon(Icons.chevron_right),
    onTap: onTap,
  );
}

/// Asks for a topic: one of the current exam's syllabus topics, or one the learner types.
Future<TopicChoice?> pickTopic(BuildContext context) => showModalBottomSheet<TopicChoice>(
  context: context,
  isScrollControlled: true,
  showDragHandle: true,
  builder: (context) => const _TopicPicker(),
);

class _TopicPicker extends ConsumerStatefulWidget {
  const _TopicPicker();

  @override
  ConsumerState<_TopicPicker> createState() => _TopicPickerState();
}

class _TopicPickerState extends ConsumerState<_TopicPicker> {
  final _typed = TextEditingController();

  @override
  void dispose() {
    _typed.dispose();
    super.dispose();
  }

  void _submitTyped() {
    final topic = _typed.text.trim();
    if (topic.length >= 2) Navigator.of(context).pop(TopicChoice(topic: topic));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final subjects = ref.watch(examMasteryProvider).value ?? const [];
    final topics = [
      for (final s in subjects)
        for (final t in s.topics) t,
    ];
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.8),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.md, 0, AppSpacing.md, AppSpacing.md),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Semantics(
                header: true,
                child: Text(l10n.learnPickTitle, style: theme.textTheme.titleMedium),
              ),
              const SizedBox(height: AppSpacing.sm),
              if (topics.isEmpty)
                Text(l10n.learnPickNoSyllabus, style: theme.textTheme.bodySmall)
              else ...[
                Text(l10n.learnPickSyllabus, style: theme.textTheme.labelLarge),
                Flexible(
                  child: ListView(
                    shrinkWrap: true,
                    children: [
                      for (final t in topics)
                        ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          title: Text(t.name),
                          subtitle: Text(t.subject),
                          onTap: () =>
                              Navigator.of(context)
                                  .pop(TopicChoice(topic: t.name, subject: t.subject)),
                        ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: AppSpacing.sm),
              TextField(
                controller: _typed,
                maxLength: 100,
                textInputAction: TextInputAction.go,
                onSubmitted: (_) => _submitTyped(),
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  labelText: l10n.learnPickTyped,
                  hintText: l10n.learnPickTypedHint,
                ),
              ),
              Text(l10n.learnPickSends, style: theme.textTheme.bodySmall),
              const SizedBox(height: AppSpacing.sm),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton(
                  onPressed: _typed.text.trim().length >= 2 ? _submitTyped : null,
                  child: Text(l10n.learnPickGo),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
