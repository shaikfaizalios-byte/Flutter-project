import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/localization/generated/app_localizations.dart';
import '../../../core/utils/app_log.dart';
import '../../../core/widgets/section_card.dart';
import '../data/feedback_repository.dart';

/// Suggest a feature to add, remove or change. The PrepLoop team reads every suggestion and
/// sets its status, which the learner sees here.
class SuggestionsScreen extends ConsumerStatefulWidget {
  const SuggestionsScreen({super.key});

  @override
  ConsumerState<SuggestionsScreen> createState() => _SuggestionsScreenState();
}

class _SuggestionsScreenState extends ConsumerState<SuggestionsScreen> {
  final _text = TextEditingController();
  final _form = GlobalKey<FormState>();
  SuggestionKind _kind = SuggestionKind.add;
  bool _sending = false;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (!(_form.currentState?.validate() ?? false)) return;
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _sending = true);
    try {
      await ref.read(feedbackRepositoryProvider).suggest(_kind, _text.text);
      _text.clear();
      ref.invalidate(mySuggestionsProvider);
      messenger.showSnackBar(SnackBar(content: Text(l10n.suggestionSent)));
    } on AppFailure catch (failure) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(switch (failure) {
            ServerFailure(code: 'rate_limited') => l10n.suggestionTooMany,
            NetworkFailure() || TimeoutFailure() => l10n.suggestionOffline,
            _ => l10n.suggestionFailed,
          }),
        ),
      );
    } on Object catch (error, stack) {
      logError('Sending a suggestion failed', error, stack);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.suggestionsTitle)),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: AppSpacing.maxContentWidth),
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.md),
            children: [
              Text(l10n.suggestionsIntro, style: theme.textTheme.bodyMedium),
              const SizedBox(height: AppSpacing.md),
              Form(
                key: _form,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SegmentedButton<SuggestionKind>(
                      showSelectedIcon: false,
                      segments: [
                        for (final kind in SuggestionKind.values)
                          ButtonSegment(value: kind, label: Text(_kindLabel(l10n, kind))),
                      ],
                      selected: {_kind},
                      onSelectionChanged: (s) => setState(() => _kind = s.first),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    TextFormField(
                      controller: _text,
                      minLines: 4,
                      maxLines: 8,
                      maxLength: SuggestionRules.maxLength,
                      decoration: InputDecoration(
                        labelText: l10n.suggestionField,
                        hintText: _hint(l10n, _kind),
                        alignLabelWithHint: true,
                      ),
                      validator: (value) => (value ?? '').trim().length < SuggestionRules.minLength
                          ? l10n.suggestionTooShort(SuggestionRules.minLength)
                          : null,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    FilledButton.icon(
                      icon: const Icon(Icons.send_outlined),
                      label: Text(l10n.suggestionSend),
                      onPressed: _sending ? null : _send,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      l10n.suggestionPrivacy,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              const _MySuggestions(),
            ],
          ),
        ),
      ),
    );
  }
}

String _kindLabel(AppLocalizations l10n, SuggestionKind kind) => switch (kind) {
  SuggestionKind.add => l10n.suggestionKindAdd,
  SuggestionKind.remove => l10n.suggestionKindRemove,
  SuggestionKind.change => l10n.suggestionKindChange,
  SuggestionKind.other => l10n.suggestionKindOther,
};

String _hint(AppLocalizations l10n, SuggestionKind kind) => switch (kind) {
  SuggestionKind.add => l10n.suggestionHintAdd,
  SuggestionKind.remove => l10n.suggestionHintRemove,
  SuggestionKind.change => l10n.suggestionHintChange,
  SuggestionKind.other => l10n.suggestionHintOther,
};

String _statusLabel(AppLocalizations l10n, String status) => switch (status) {
  'read' => l10n.suggestionStatusRead,
  'planned' => l10n.suggestionStatusPlanned,
  'done' => l10n.suggestionStatusDone,
  'declined' => l10n.suggestionStatusDeclined,
  _ => l10n.suggestionStatusNew,
};

class _MySuggestions extends ConsumerWidget {
  const _MySuggestions();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).toLanguageTag();
    return SectionCard(
      icon: Icons.history,
      title: l10n.suggestionsMine,
      child: switch (ref.watch(mySuggestionsProvider)) {
        AsyncData(:final value) when value.isEmpty => Text(l10n.suggestionsNone),
        AsyncData(:final value) => Column(
          children: [
            for (final s in value)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(s.text, maxLines: 3, overflow: TextOverflow.ellipsis),
                subtitle: Text(
                  '${_kindLabel(l10n, s.kind)} · ${_statusLabel(l10n, s.status)} · '
                  '${DateFormat.yMMMd(locale).format(s.createdAt.toLocal())}',
                ),
              ),
          ],
        ),
        AsyncError() => Text(l10n.suggestionOffline),
        _ => const LinearProgressIndicator(),
      },
    );
  }
}
