import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../app/routes.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/localization/generated/app_localizations.dart';
import '../../../core/utils/app_log.dart';
import '../../../core/widgets/section_card.dart';
import '../../documents/presentation/documents_screen.dart' show uploadErrorMessage;
import '../../question_bank/application/question_bank_providers.dart';
import '../application/practice_providers.dart';
import '../domain/practice_models.dart';
import '../../exams/presentation/exam_switcher.dart';
import '../../exams/application/active_exam.dart';

/// Practice tab: start practice or a mock test, review tools and recent sessions.
class PracticeHubScreen extends ConsumerWidget {
  const PracticeHubScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    ref.watch(pendingAnswersFlushProvider); // send answers saved while offline
    return Scaffold(
      appBar: AppBar(title: Text(l10n.practiceHubTitle), actions: const [ExamSwitcher()]),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: AppSpacing.maxContentWidth),
          child: RefreshIndicator(
            onRefresh: () async {
              ref
                ..invalidate(mockTestsProvider)
                ..invalidate(sessionHistoryProvider);
            },
            child: ListView(
              padding: const EdgeInsets.all(AppSpacing.md),
              children: [
                SectionCard(
                  icon: Icons.quiz_outlined,
                  title: l10n.practiceStartTitle,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(l10n.practiceStartMessage),
                      const SizedBox(height: AppSpacing.sm),
                      FilledButton.icon(
                        icon: const Icon(Icons.play_arrow),
                        label: Text(l10n.practiceStart),
                        onPressed: () => _setUpPractice(context, ref),
                      ),
                      if (ref.watch(offlineStatusProvider).value case final offline?) ...[
                        if (offline.questions > 0) ...[
                          const SizedBox(height: AppSpacing.sm),
                          Row(
                            spacing: AppSpacing.xs,
                            children: [
                              const Icon(Icons.offline_pin_outlined, size: 18),
                              Expanded(
                                child: Text(
                                  l10n.offlineReady(offline.questions),
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ),
                            ],
                          ),
                        ],
                        if (offline.toUpload > 0)
                          Text(
                            l10n.offlineToUpload(offline.toUpload),
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                SectionCard(
                  icon: Icons.insights_outlined,
                  title: l10n.repeatsTitle,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(l10n.repeatsHubMessage),
                      const SizedBox(height: AppSpacing.sm),
                      OutlinedButton.icon(
                        icon: const Icon(Icons.insights_outlined),
                        label: Text(l10n.repeatsOpen),
                        onPressed: () => context.push(AppRoutes.repeats),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                const _MockTestsCard(),
                const SizedBox(height: AppSpacing.md),
                SectionCard(
                  icon: Icons.replay,
                  title: l10n.reviewToolsTitle,
                  child: Column(
                    children: [
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.bookmark_outline),
                        title: Text(l10n.bookmarksTitle),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => context.push(AppRoutes.bookmarks),
                      ),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.error_outline),
                        title: Text(l10n.incorrectTitle),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => context.push(AppRoutes.incorrect),
                      ),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.library_books_outlined),
                        title: Text(l10n.questionBankOpen),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => context.push(AppRoutes.questionBank),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                const _HistoryCard(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _setUpPractice(BuildContext context, WidgetRef ref) async {
    final request = await showModalBottomSheet<PracticeRequest>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => const _PracticeSetupSheet(),
    );
    if (request == null || !context.mounted) return;
    await startAndOpen(context, () => ref.read(practiceRepositoryProvider).startPractice(request));
  }
}

/// Starts a session and opens it, explaining failures.
Future<void> startAndOpen(
  BuildContext context,
  Future<PracticeSessionView> Function() start,
) async {
  final l10n = AppLocalizations.of(context);
  final messenger = ScaffoldMessenger.of(context);
  try {
    final session = await start();
    if (context.mounted) await context.push(AppRoutes.practiceSession(session.id));
  } on ServerFailure catch (failure) {
    messenger.showSnackBar(
      SnackBar(
        content: Text(switch (failure.code) {
          'no_questions_available' => l10n.practiceNoQuestions,
          'not_enough_questions' => '${l10n.mockUnavailable} ${failure.message ?? ''}',
          _ => uploadErrorMessage(l10n, failure),
        }),
      ),
    );
  } on AppFailure catch (failure) {
    messenger.showSnackBar(SnackBar(content: Text(uploadErrorMessage(l10n, failure))));
  } on Object catch (error, stack) {
    logError('Starting a session failed', error, stack);
  }
}

class _PracticeSetupSheet extends ConsumerStatefulWidget {
  const _PracticeSetupSheet();

  @override
  ConsumerState<_PracticeSetupSheet> createState() => _PracticeSetupSheetState();
}

class _PracticeSetupSheetState extends ConsumerState<_PracticeSetupSheet> {
  String? _subject;
  String? _topicId;
  int _count = 10;
  bool _includeUnverified = false;
  bool _includeAi = false;
  bool _includeShared = true;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final exam = ref.watch(activeExamProvider);
    final topics = ref.watch(topicsProvider(exam)).value ?? const [];
    final subjects = {for (final t in topics) t.subject}.toList()..sort();
    final subjectTopics = topics.where((t) => t.subject == _subject).toList();

    // Scrolls on short screens (the sheet has grown with each option).
    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          AppSpacing.lg,
          0,
          AppSpacing.lg,
          AppSpacing.lg + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.practiceSetupTitle, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: AppSpacing.md),
            DropdownButtonFormField<String?>(
              initialValue: _subject,
              isExpanded: true,
              decoration: InputDecoration(labelText: l10n.practiceSubject),
              items: [
                DropdownMenuItem(value: null, child: Text(l10n.practiceMixed)),
                for (final s in subjects) DropdownMenuItem(value: s, child: Text(s)),
              ],
              onChanged: (value) => setState(() {
                _subject = value;
                _topicId = null;
              }),
            ),
            if (_subject != null) ...[
              const SizedBox(height: AppSpacing.md),
              DropdownButtonFormField<String?>(
                key: ValueKey(_subject),
                initialValue: _topicId,
                isExpanded: true,
                decoration: InputDecoration(labelText: l10n.practiceTopic),
                items: [
                  DropdownMenuItem(value: null, child: Text(l10n.practiceTopicAny)),
                  for (final t in subjectTopics) DropdownMenuItem(value: t.id, child: Text(t.name)),
                ],
                onChanged: (value) => setState(() => _topicId = value),
              ),
            ],
            const SizedBox(height: AppSpacing.md),
            Text(l10n.practiceCount, style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: AppSpacing.sm),
            SegmentedButton<int>(
              segments: [
                for (final n in const [5, 10, 20, 30]) ButtonSegment(value: n, label: Text('$n')),
              ],
              selected: {_count},
              onSelectionChanged: (s) => setState(() => _count = s.first),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(l10n.practiceIncludeUnverified),
              subtitle: Text(l10n.practiceIncludeUnverifiedHint),
              value: _includeUnverified,
              onChanged: (v) => setState(() => _includeUnverified = v),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(l10n.practiceIncludeAi),
              subtitle: Text(l10n.practiceIncludeAiHint),
              value: _includeAi,
              onChanged: (v) => setState(() => _includeAi = v),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(l10n.practiceIncludeShared),
              subtitle: Text(l10n.practiceIncludeSharedHint),
              value: _includeShared,
              onChanged: (v) => setState(() => _includeShared = v),
            ),
            const SizedBox(height: AppSpacing.sm),
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: FilledButton(
                onPressed: () => Navigator.of(context).pop(
                  PracticeRequest(
                    examCode: exam,
                    subject: _subject,
                    topicId: _topicId,
                    count: _count,
                    includeUnverified: _includeUnverified,
                    includeAi: _includeAi,
                    includeShared: _includeShared,
                  ),
                ),
                child: Text(l10n.practiceStart),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MockTestsCard extends ConsumerWidget {
  const _MockTestsCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final mocks = ref.watch(mockTestsProvider);
    return SectionCard(
      icon: Icons.timer_outlined,
      title: l10n.mockTestsTitle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.mockTestsMessage),
          const SizedBox(height: AppSpacing.sm),
          switch (mocks) {
            AsyncData(:final value) when value.isEmpty => Text(l10n.mockTestsNone),
            AsyncData(:final value) => Column(
              children: [for (final mock in value) _MockTile(mock: mock)],
            ),
            AsyncError(:final error) => Text(
              error is AppFailure ? uploadErrorMessage(l10n, error) : l10n.bankLoadError,
            ),
            _ => const LinearProgressIndicator(),
          },
        ],
      ),
    );
  }
}

class _MockTile extends ConsumerWidget {
  const _MockTile({required this.mock});

  final MockTestView mock;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final details = [
      if (mock.durationMinutes != null)
        l10n.mockTestDetails(mock.totalQuestions, mock.durationMinutes!),
      if (mock.negativeMarks != null && mock.negativeMarks! > 0)
        l10n.mockNegative(mock.negativeMarks!.toStringAsFixed(2)),
    ].join(' · ');
    final short = mock.sections.where((s) => s.available < s.needed).toList();
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(mock.name),
      subtitle: Text(
        [
          details,
          if (!mock.available) l10n.mockUnavailable,
          for (final s in short) l10n.mockSectionShort(s.subject, s.available, s.needed),
        ].where((s) => s.isNotEmpty).join('\n'),
      ),
      isThreeLine: !mock.available,
      trailing: FilledButton.tonal(
        onPressed: mock.available ? () => _confirmAndStart(context, ref) : null,
        child: Text(l10n.mockStart),
      ),
    );
  }

  Future<void> _confirmAndStart(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.mockConfirmTitle),
        content: Text(l10n.mockConfirmMessage),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: Text(l10n.cancel)),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.mockStart),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    await startAndOpen(context, () => ref.read(practiceRepositoryProvider).startMock(mock.code));
  }
}

class _HistoryCard extends ConsumerWidget {
  const _HistoryCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final history = ref.watch(sessionHistoryProvider);
    final locale = Localizations.localeOf(context).toLanguageTag();
    return SectionCard(
      icon: Icons.history,
      title: l10n.historyTitle,
      child: switch (history) {
        AsyncData(:final value) when value.isEmpty => Text(l10n.historyEmpty),
        AsyncData(:final value) => Column(
          children: [
            for (final s in value.take(10))
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  s.mode == SessionMode.mock ? Icons.timer_outlined : Icons.quiz_outlined,
                ),
                title: Text(
                  s.mode == SessionMode.mock
                      ? l10n.historyMock(s.formatName ?? '')
                      : l10n.historyPractice,
                ),
                subtitle: Text(DateFormat.yMMMd(locale).add_jm().format(s.startedAt.toLocal())),
                trailing: Text(
                  s.submitted && s.score != null
                      ? l10n.historyScore(_fmt(s.score!), _fmt(s.maxScore ?? 0))
                      : l10n.historyInProgress,
                ),
                onTap: () => context.push(AppRoutes.practiceSession(s.id)),
              ),
          ],
        ),
        AsyncError(:final error) => Text(
          error is AppFailure ? uploadErrorMessage(l10n, error) : l10n.bankLoadError,
        ),
        _ => const LinearProgressIndicator(),
      },
    );
  }
}

String _fmt(double value) =>
    value == value.roundToDouble() ? value.toStringAsFixed(0) : value.toStringAsFixed(2);
