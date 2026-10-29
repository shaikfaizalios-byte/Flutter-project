import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../core/localization/generated/app_localizations.dart';
import '../../../core/widgets/empty_state.dart';
import '../../ai/application/ai_providers.dart';
import '../../ai/data/ai_repository.dart';
import '../../ai/presentation/ai_widgets.dart';
import '../../concepts/domain/concept.dart';
import '../../exams/application/active_exam.dart';
import '../../plus/presentation/plus_prompt.dart';
import '../application/learn_providers.dart';

/// Lessons and questions are written in the interface language.
ContentLanguage learnLanguage(BuildContext context) =>
    Localizations.localeOf(context).languageCode == 'hi'
    ? ContentLanguage.hindi
    : ContentLanguage.english;

/// A lesson or knowledge-check screen: shows why AI can't be used (off, needs Plus, no exam)
/// or builds [body] with the request for the current exam.
class LearnScreenFrame extends ConsumerWidget {
  const LearnScreenFrame({
    super.key,
    required this.title,
    required this.choice,
    required this.body,
  });

  final String title;
  final TopicChoice choice;
  final Widget Function(LearnRequest request) body;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final exam = ref.watch(activeExamProvider);
    final status = ref.watch(aiStatusProvider);
    final Widget content = switch (status) {
      AsyncData(:final value) when !value.enabled || exam == null => EmptyState(
        icon: Icons.auto_awesome_outlined,
        title: l10n.learnNeedsAi,
      ),
      AsyncData(:final value) when value.needsPlus => Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: PlusPrompt(message: l10n.learnPlusMessage),
      ),
      AsyncData() => body((examCode: exam!, choice: choice, language: learnLanguage(context))),
      _ => const Center(child: CircularProgressIndicator()),
    };
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: AppSpacing.maxContentWidth),
          child: content,
        ),
      ),
    );
  }
}

/// Loading message while the AI writes.
class LearnLoading extends StatelessWidget {
  const LearnLoading(this.message, {super.key});

  final String message;

  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const CircularProgressIndicator(),
        const SizedBox(height: AppSpacing.md),
        Text(message),
      ],
    ),
  );
}

/// An AI failure with a retry button (and "See Plus" when that would solve it).
class LearnError extends StatelessWidget {
  const LearnError({super.key, required this.error, required this.onRetry});

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final plus = needsPlusAction(context, error);
    return EmptyState(
      icon: Icons.cloud_off_outlined,
      title: aiErrorMessage(l10n, error),
      action: Wrap(
        spacing: AppSpacing.sm,
        children: [
          FilledButton(onPressed: onRetry, child: Text(l10n.retry)),
          if (plus != null) TextButton(onPressed: plus.onPressed, child: Text(plus.label)),
        ],
      ),
    );
  }
}
