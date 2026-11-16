import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/localization/content_language.dart';
import '../../../core/localization/generated/app_localizations.dart';
import '../../../core/utils/app_log.dart';
import '../../../core/utils/calendar_date.dart';
import '../../../core/utils/clock.dart';
import '../../../core/widgets/section_card.dart';
import '../../ai/presentation/ai_widgets.dart';
import '../../concepts/application/concepts_providers.dart';
import '../../exams/application/active_exam.dart';
import '../../revision/application/revision_providers.dart';
import '../../settings/application/app_preferences.dart';
import '../data/current_affairs_repository.dart';
import '../domain/current_affairs.dart';

enum _Source { text, pdf }

enum _CardState { pending, saved, skipped }

/// Current affairs from the learner's own sources: pasted text or a PDF they chose (PrepLoop
/// fetches no web page). The AI drafts cards, each with the quote it comes from; the learner
/// approves each one, and approved cards become AI-labelled concepts on the revision ladder.
class CurrentAffairsScreen extends ConsumerStatefulWidget {
  const CurrentAffairsScreen({super.key});

  @override
  ConsumerState<CurrentAffairsScreen> createState() => _CurrentAffairsScreenState();
}

class _CurrentAffairsScreenState extends ConsumerState<CurrentAffairsScreen> {
  final _text = TextEditingController();
  _Source _source = _Source.text;
  bool _busy = false;
  Object? _failure;
  CurrentAffairsDraft? _draft;
  List<_CardState> _states = const [];

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _run(Future<CurrentAffairsDraft> Function(String exam) request) async {
    final exam = ref.read(activeExamProvider);
    if (exam == null) return;
    setState(() {
      _busy = true;
      _failure = null;
    });
    try {
      final draft = await request(exam);
      if (!mounted) return;
      setState(() {
        _draft = draft;
        _states = [for (final _ in draft.cards) _CardState.pending];
      });
    } on Object catch (error, stack) {
      if (error is! AppFailure) logError('Current affairs drafts failed', error, stack);
      if (mounted) setState(() => _failure = error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _fromText() {
    final language = _language();
    return _run(
      (exam) => ref
          .read(currentAffairsRepositoryProvider)
          .fromText(examCode: exam, text: _text.text.trim(), language: language),
    );
  }

  Future<void> _fromPdf() async {
    final file = await ref.read(currentAffairsPdfPickerProvider)();
    if (file == null || !mounted) return;
    final language = _language();
    await _run(
      (exam) => ref
          .read(currentAffairsRepositoryProvider)
          .fromPdf(examCode: exam, name: file.name, bytes: file.bytes, language: language),
    );
  }

  ContentLanguage _language() =>
      ref.read(appPreferencesProvider).contentLanguageFor(Localizations.localeOf(context));

  Future<void> _approve(int index) async {
    final exam = ref.read(activeExamProvider);
    final card = _draft?.cards[index];
    if (exam == null || card == null) return;
    final l10n = AppLocalizations.of(context);
    try {
      final concept = await ref
          .read(conceptsRepositoryProvider)
          .create(
            currentAffairsConcept(
              card,
              examCode: exam,
              language: _language(),
              today: CalendarDate.fromDateTime(ref.read(clockProvider)()),
              sourceLine: l10n.caSourceLine(card.sourceLabel, card.quote),
            ),
          );
      await ref.read(revisionRepositoryProvider).addConcept(concept.id);
      if (mounted) setState(() => _states = [..._states]..[index] = _CardState.saved);
    } on Object catch (error, stack) {
      logError('Saving a current affairs card failed', error, stack);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.caSaveFailed)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final exam = ref.watch(activeExamProvider);
    final draft = _draft;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.caTitle)),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: AppSpacing.maxContentWidth),
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.md),
            children: [
              Text(l10n.caIntro),
              const SizedBox(height: AppSpacing.md),
              SegmentedButton<_Source>(
                showSelectedIcon: false,
                segments: [
                  ButtonSegment(value: _Source.text, label: Text(l10n.caPaste)),
                  ButtonSegment(value: _Source.pdf, label: Text(l10n.caPdf)),
                ],
                selected: {_source},
                onSelectionChanged: (s) => setState(() => _source = s.single),
              ),
              const SizedBox(height: AppSpacing.md),
              if (_source == _Source.text) ...[
                TextField(
                  controller: _text,
                  minLines: 4,
                  maxLines: 12,
                  maxLength: 20000,
                  decoration: InputDecoration(
                    labelText: l10n.caPasteLabel,
                    border: const OutlineInputBorder(),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
                FilledButton.icon(
                  icon: const Icon(Icons.auto_awesome_outlined),
                  label: Text(l10n.caDraft),
                  onPressed: _busy || exam == null || _text.text.trim().length < 20
                      ? null
                      : _fromText,
                ),
              ] else
                FilledButton.icon(
                  icon: const Icon(Icons.picture_as_pdf_outlined),
                  label: Text(l10n.caChoosePdf),
                  onPressed: _busy || exam == null ? null : _fromPdf,
                ),
              if (_busy) ...[
                const SizedBox(height: AppSpacing.md),
                const LinearProgressIndicator(),
              ],
              if (_failure case final failure?) ...[
                const SizedBox(height: AppSpacing.md),
                Text(
                  aiErrorMessage(l10n, failure),
                  style: TextStyle(color: theme.colorScheme.error),
                ),
              ],
              if (draft != null) ...[
                const SizedBox(height: AppSpacing.lg),
                Text(l10n.caDraftsTitle, style: theme.textTheme.titleMedium),
                Text(l10n.caAiLabel, style: theme.textTheme.bodySmall),
                if (draft.noText) Text(l10n.caNoText),
                if (!draft.noText && draft.cards.isEmpty) Text(l10n.caNoCards),
                if (draft.leftOut) Text(l10n.caLeftOut, style: theme.textTheme.bodySmall),
                if (draft.dropped > 0)
                  Text(l10n.caDropped(draft.dropped), style: theme.textTheme.bodySmall),
                const SizedBox(height: AppSpacing.sm),
                for (final (i, card) in draft.cards.indexed)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                    child: _DraftCard(
                      card: card,
                      state: _states[i],
                      onApprove: () => _approve(i),
                      onSkip: () =>
                          setState(() => _states = [..._states]..[i] = _CardState.skipped),
                    ),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _DraftCard extends StatelessWidget {
  const _DraftCard({
    required this.card,
    required this.state,
    required this.onApprove,
    required this.onSkip,
  });

  final CurrentAffairsCard card;
  final _CardState state;
  final VoidCallback onApprove;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return SectionCard(
      icon: Icons.auto_awesome_outlined,
      title: card.front,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(card.back),
          const SizedBox(height: AppSpacing.xs),
          Text(l10n.caSourceLine(card.sourceLabel, card.quote), style: theme.textTheme.bodySmall),
          const SizedBox(height: AppSpacing.sm),
          switch (state) {
            _CardState.saved => Text(
              l10n.caSaved,
              style: TextStyle(color: theme.colorScheme.primary),
            ),
            _CardState.skipped => Text(l10n.caSkipped, style: theme.textTheme.bodySmall),
            _CardState.pending => Wrap(
              spacing: AppSpacing.sm,
              children: [
                FilledButton.tonal(onPressed: onApprove, child: Text(l10n.caApprove)),
                TextButton(onPressed: onSkip, child: Text(l10n.caSkip)),
              ],
            ),
          },
        ],
      ),
    );
  }
}
