import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../core/localization/generated/app_localizations.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/section_card.dart';
import '../../ai/presentation/ai_widgets.dart';
import '../../exams/application/active_exam.dart';
import '../../exams/application/exam_catalog_controller.dart';
import '../application/chapters_providers.dart';
import '../domain/chapters.dart';
import 'repeats_screen.dart';

/// How often each chapter appeared, by shift, year and session, for the current exam.
class ChaptersScreen extends ConsumerWidget {
  const ChaptersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final exam = ref.watch(activeExamProvider);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.chaptersTitle)),
      body: exam == null
          ? EmptyState(icon: Icons.bar_chart, title: l10n.chaptersEmpty)
          : ref
                .watch(chapterReportProvider(exam))
                .when(
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (_, _) => EmptyState(
                    icon: Icons.cloud_off_outlined,
                    title: l10n.chaptersFailed,
                    action: OutlinedButton(
                      onPressed: () => ref.invalidate(chapterReportProvider(exam)),
                      child: Text(l10n.retry),
                    ),
                  ),
                  data: (report) => _Report(exam: exam, report: report),
                ),
    );
  }
}

class _Report extends ConsumerWidget {
  const _Report({required this.exam, required this.report});

  final String exam;
  final ChapterReport report;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final basis = report.basis;
    final small = theme(context).textTheme.bodySmall;
    final rules = ref.watch(repeatRulesProvider);
    final hints = ref.watch(conceptHintsProvider(exam)).value ?? const <ConceptHint>[];
    final shared = ref.watch(sharedChaptersProvider).value ?? const <SharedChapter>[];
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: [
        Text(l10n.chaptersBasis(basis.shifts, basis.questions)),
        Text(l10n.chaptersNote, style: small),
        if (basis.shifts > 0 && basis.shifts < rules.reliablePapers)
          Text(l10n.chaptersSmallSample(basis.shifts), style: small),
        if (basis.unreviewed > 0) Text(l10n.chaptersUnreviewed(basis.unreviewed), style: small),
        const SizedBox(height: AppSpacing.md),
        if (report.chapters.isEmpty)
          Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Text(l10n.chaptersEmpty, textAlign: TextAlign.center),
          ),
        for (final chapter in report.chapters) _ChapterCard(chapter: chapter, basis: basis),
        if (shared.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.md),
          _SharedCard(chapters: shared),
        ],
        if (hints.isNotEmpty) ...[const SizedBox(height: AppSpacing.md), _HintsCard(hints: hints)],
      ],
    );
  }
}

ThemeData theme(BuildContext context) => Theme.of(context);

class _ChapterCard extends StatelessWidget {
  const _ChapterCard({required this.chapter, required this.basis});

  final ChapterWeight chapter;
  final ShiftBasis basis;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Card(
      child: ExpansionTile(
        title: Text(chapter.name),
        subtitle: Text(
          [
            if (chapter.subject.isNotEmpty) chapter.subject,
            l10n.chaptersAppeared(chapter.shifts, basis.shifts),
          ].join(' · '),
        ),
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        childrenPadding: const EdgeInsets.fromLTRB(AppSpacing.md, 0, AppSpacing.md, AppSpacing.md),
        children: [
          for (final year in chapter.years)
            if (basis.year(year.year) case final YearWeight all)
              Text(
                l10n.chaptersYear(
                  '${year.year}',
                  weightPercent(year.questions, all.questions) ?? 0,
                  year.shifts,
                  all.shifts,
                ),
              ),
          for (final session in chapter.sessions)
            if (basis.session(session.session) case final SessionWeight all)
              Text(l10n.chaptersSession(session.session, session.shifts, all.shifts)),
          if (chapter.topics.length > 1) ...[
            const SizedBox(height: AppSpacing.sm),
            for (final topic in chapter.topics)
              Text(
                '${topic.name} · ${l10n.chaptersAppeared(topic.shifts, basis.shifts)}',
                style: theme(context).textTheme.bodySmall,
              ),
          ],
        ],
      ),
    );
  }
}

class _SharedCard extends ConsumerWidget {
  const _SharedCard({required this.chapters});

  final List<SharedChapter> chapters;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    return SectionCard(
      icon: Icons.join_inner,
      title: l10n.chaptersSharedTitle,
      child: Column(
        children: [
          for (final chapter in chapters)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(chapter.name),
              subtitle: Text(
                [
                  for (final exam in chapter.exams)
                    l10n.chaptersSharedExam(
                      ref.watch(examNameProvider(exam.examCode)),
                      exam.shifts,
                      exam.totalShifts,
                    ),
                ].join('\n'),
              ),
            ),
        ],
      ),
    );
  }
}

class _HintsCard extends StatelessWidget {
  const _HintsCard({required this.hints});

  final List<ConceptHint> hints;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return SectionCard(
      icon: Icons.auto_awesome,
      title: l10n.chaptersHintsTitle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AiLabel(l10n.chaptersHintsNote),
          for (final hint in hints)
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              title: Text(hint.label),
              subtitle: Text(l10n.chaptersHintShifts(hint.topicName, hint.shifts)),
              children: [
                for (final question in hint.questions)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    title: Text(
                      question.excerpt ?? l10n.chaptersHintQuestion(question.number ?? 0),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: question.year == null ? null : Text('${question.year}'),
                    onTap: () => context.push(AppRoutes.question(question.questionId)),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}
