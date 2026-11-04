import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../core/localization/generated/app_localizations.dart';
import '../../plus/presentation/plus_prompt.dart';
import '../../settings/application/app_preferences.dart';
import '../application/ai_providers.dart';
import '../application/quick_answers.dart';
import 'ai_widgets.dart';
import 'study_answer_view.dart';

/// A whole paper in 10-15 simple points, in the learner's AI language. The paper's text goes to
/// the AI provider when this screen opens (the learner asked for it); nothing is stored.
class PaperSummaryScreen extends ConsumerWidget {
  const PaperSummaryScreen({
    super.key,
    required this.documentId,
    required this.name,
    required this.examCode,
  });

  final String documentId;
  final String name;
  final String examCode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final status = ref.watch(aiStatusProvider).value;
    final language = ref
        .watch(appPreferencesProvider)
        .aiLanguageFor(Localizations.localeOf(context));
    final key = (documentId: documentId, examCode: examCode, language: language);

    final Widget body;
    if (status == null) {
      body = const Center(child: CircularProgressIndicator());
    } else if (!status.enabled) {
      body = Text(l10n.aiErrorDisabled);
    } else if (status.needsPlus) {
      body = PlusPrompt(message: l10n.plusPromptSearch);
    } else {
      body = switch (ref.watch(paperSummaryProvider(key))) {
        AsyncData(:final value) when value.found => StudyAnswerView(answer: value),
        AsyncData() => Text(l10n.paperSummaryNoText),
        AsyncError(:final error) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(aiErrorMessage(l10n, error)),
            TextButton(
              onPressed: () => ref.invalidate(paperSummaryProvider(key)),
              child: Text(l10n.retry),
            ),
          ],
        ),
        _ => Row(
          children: [
            const SizedBox.square(dimension: 16, child: CircularProgressIndicator(strokeWidth: 2)),
            const SizedBox(width: AppSpacing.sm),
            Expanded(child: Text(l10n.paperSummaryLoading, style: theme.textTheme.bodyMedium)),
          ],
        ),
      };
    }

    return Scaffold(
      appBar: AppBar(title: Text(l10n.paperSummaryTitle(name))),
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
