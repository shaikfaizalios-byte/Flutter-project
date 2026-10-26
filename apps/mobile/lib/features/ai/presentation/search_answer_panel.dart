import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../core/localization/generated/app_localizations.dart';
import '../application/ai_providers.dart';
import '../application/quick_answers.dart';
import '../data/ai_repository.dart';
import 'ai_widgets.dart';
import 'quick_answer_panel.dart';
import '../../plus/presentation/plus_prompt.dart';

/// The Study search's AI answer from the learner's own material (RAG): the answer, then the
/// sources it cites, each opening the page, question or concept so the learner can check it.
/// When the material doesn't cover the search, a general AI answer ([QuickAnswerPanel]) follows.
/// Nothing is sent before the learner taps "Ask AI" once. Shown only when the server has AI.
class SearchAnswerPanel extends ConsumerWidget {
  const SearchAnswerPanel({super.key, required this.query});

  final String query;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final status = ref.watch(aiStatusProvider).value;
    if (!(status?.enabled ?? false)) return const SizedBox.shrink();
    final on = ref.watch(quickAnswersOnProvider);

    final Widget body;
    if (status!.needsPlus) {
      body = PlusPrompt(message: l10n.plusPromptSearch);
    } else if (!on) {
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.quickAnswerOffer, style: theme.textTheme.bodySmall),
          const SizedBox(height: AppSpacing.xs),
          FilledButton.tonalIcon(
            icon: const Icon(Icons.auto_awesome),
            label: Text(l10n.quickAnswerAsk),
            onPressed: () => ref.read(quickAnswersOnProvider.notifier).set(on: true),
          ),
        ],
      );
    } else {
      body = switch (ref.watch(searchAnswerProvider(query))) {
        AsyncData(value: final a?) when a.found && a.answer != null => _Found(answer: a),
        AsyncData(value: _?) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.searchAnswerNotCovered, style: theme.textTheme.bodySmall),
            QuickAnswerPanel(query: query),
          ],
        ),
        AsyncError(:final error) => Row(
          children: [
            Expanded(child: Text(aiErrorMessage(l10n, error), style: theme.textTheme.bodySmall)),
            TextButton(
              onPressed: () => ref.invalidate(searchAnswerProvider(query)),
              child: Text(l10n.retry),
            ),
          ],
        ),
        _ => Row(
          children: [
            const SizedBox.square(dimension: 16, child: CircularProgressIndicator(strokeWidth: 2)),
            const SizedBox(width: AppSpacing.sm),
            Text(l10n.searchAnswerLoading, style: theme.textTheme.bodySmall),
          ],
        ),
      };
    }

    // A Material (not a decorated box) so the source rows' tap ripples show on it.
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.sm),
      child: Material(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppSpacing.sm),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.sm),
          child: SizedBox(
            width: double.infinity,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Semantics(
                  header: true,
                  child: Text(l10n.searchAnswerTitle, style: theme.textTheme.titleSmall),
                ),
                const SizedBox(height: AppSpacing.xs),
                body,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Found extends ConsumerWidget {
  const _Found({required this.answer});

  final SearchAnswer answer;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    // Calm on purpose: no badges or warning colours while the learner reads. The panel title
    // and the note at the bottom say it was written by AI.
    final fromPapers = _Column(
      title: l10n.searchAnswerFromPapers,
      children: [
        SelectableText(answer.answer!),
        const SizedBox(height: AppSpacing.sm),
        Text(l10n.searchAnswerSources, style: theme.textTheme.labelLarge),
        for (final source in answer.cited) _SourceTile(source: source),
      ],
    );
    final simple = answer.simple == null
        ? null
        : _Column(title: l10n.searchAnswerSimple, children: [SelectableText(answer.simple!)]);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LayoutBuilder(
          builder: (context, constraints) => simple == null
              ? fromPapers
              : constraints.maxWidth >= twoColumnWidth
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: fromPapers),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(child: simple),
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    fromPapers,
                    const SizedBox(height: AppSpacing.md),
                    simple,
                  ],
                ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(l10n.searchAnswerCaution(answer.model ?? ''), style: theme.textTheme.bodySmall),
        TextButton(
          onPressed: () => ref.read(quickAnswersOnProvider.notifier).set(on: false),
          child: Text(l10n.quickAnswerTurnOff),
        ),
      ],
    );
  }
}

/// Side by side from this width; one under the other on phones.
const twoColumnWidth = 560.0;

/// One part of the answer: a small heading over its content.
class _Column extends StatelessWidget {
  const _Column({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: theme.textTheme.titleSmall?.copyWith(color: theme.colorScheme.primary)),
        const SizedBox(height: AppSpacing.xs),
        ...children,
      ],
    );
  }
}

class _SourceTile extends StatelessWidget {
  const _SourceTile({required this.source});

  final SearchAnswerSource source;

  String? get _route => switch (source.kind) {
    SearchSourceKind.page when source.documentId != null => AppRoutes.documentReview(
      source.documentId!,
    ),
    SearchSourceKind.question when source.questionId != null => AppRoutes.question(
      source.questionId!,
    ),
    SearchSourceKind.concept when source.conceptId != null => AppRoutes.concept(source.conceptId!),
    _ => null,
  };

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final route = _route;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      dense: true,
      leading: CircleAvatar(radius: 14, child: Text(source.key, textScaler: TextScaler.noScaling)),
      title: Text(source.label),
      subtitle: source.verified ? null : Text(l10n.searchAnswerUnchecked),
      trailing: Icon(switch (source.kind) {
        SearchSourceKind.page => Icons.picture_as_pdf_outlined,
        SearchSourceKind.question => Icons.quiz_outlined,
        SearchSourceKind.concept => Icons.menu_book_outlined,
      }),
      onTap: route == null ? null : () => context.push(route),
    );
  }
}
