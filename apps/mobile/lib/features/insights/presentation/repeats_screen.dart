import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/app_features.dart';

import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../core/localization/generated/app_localizations.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/section_card.dart';
import '../../practice/application/practice_providers.dart';
import '../../practice/domain/practice_models.dart';
import '../../practice/presentation/practice_hub_screen.dart' show startAndOpen;
import '../data/insights_repository.dart';
import '../domain/radar.dart';
import '../domain/repeats.dart';
import 'radar_sharing_card.dart';
import '../../exams/application/active_exam.dart';
import '../../concepts/application/concepts_providers.dart';

/// Which topics and question types (patterns) repeat across the papers the learner imported.
/// Every number states its basis; reviewed counts are kept apart from suggestions.
class RepeatsScreen extends ConsumerStatefulWidget {
  const RepeatsScreen({super.key});

  @override
  ConsumerState<RepeatsScreen> createState() => _RepeatsScreenState();
}

class _RepeatsScreenState extends ConsumerState<RepeatsScreen> {
  String? _exam;
  String _view = 'mine'; // mine: your papers · shared: the shared bank · radar: all learners

  /// The other side: what these papers did not ask.
  bool _notRepeated = false;

  RepeatsQuery get _query => (examCode: _exam, scope: _view == 'shared' ? 'shared' : 'mine');

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    // Repeats of the current exam (switched with the exam switcher).
    _exam = ref.watch(activeExamProvider);
    final radar = ref.watch(appFeaturesProvider).repeatRadar;
    final view = !radar && _view == 'radar' ? 'mine' : _view;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.repeatsTitle)),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: AppSpacing.maxContentWidth),
          child: RefreshIndicator(
            onRefresh: () async => ref
              ..invalidate(repeatsProvider(_query))
              ..invalidate(radarProvider(_exam)),
            child: ListView(
              padding: const EdgeInsets.all(AppSpacing.md),
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.md),
                  child: SegmentedButton<String>(
                    showSelectedIcon: false,
                    segments: [
                      ButtonSegment(value: 'mine', label: Text(l10n.repeatsYourPapers)),
                      ButtonSegment(value: 'shared', label: Text(l10n.repeatsSharedBank)),
                      if (radar)
                        ButtonSegment(value: 'radar', label: Text(l10n.repeatsAllLearners)),
                    ],
                    selected: {view},
                    onSelectionChanged: (s) => setState(() => _view = s.first),
                  ),
                ),
                if (view != 'radar')
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.md),
                    child: SegmentedButton<bool>(
                      showSelectedIcon: false,
                      segments: [
                        ButtonSegment(value: false, label: Text(l10n.repeatsKindRepeated)),
                        ButtonSegment(value: true, label: Text(l10n.repeatsKindNotRepeated)),
                      ],
                      selected: {_notRepeated},
                      onSelectionChanged: (s) => setState(() => _notRepeated = s.first),
                    ),
                  ),
                if (view == 'radar') ..._radar(context) else ..._own(context),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _radar(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return [
      ...switch (ref.watch(radarProvider(_exam))) {
        AsyncData(:final value) => _radarContent(context, value),
        AsyncError() => [
          EmptyState(
            icon: Icons.cloud_off,
            title: l10n.bankLoadError,
            action: OutlinedButton(
              onPressed: () => ref.invalidate(radarProvider(_exam)),
              child: Text(l10n.retry),
            ),
          ),
        ],
        _ => [
          const Padding(
            padding: EdgeInsets.all(AppSpacing.xl),
            child: Center(child: CircularProgressIndicator()),
          ),
        ],
      },
      const SizedBox(height: AppSpacing.md),
      RadarSharingCard(examCode: _exam),
    ];
  }

  List<Widget> _radarContent(BuildContext context, RadarReport report) {
    final l10n = AppLocalizations.of(context);
    final small = Theme.of(context).textTheme.bodySmall;
    final basis = report.basis;
    if (basis.shifts == 0) {
      return [
        SectionCard(
          icon: Icons.radar,
          title: l10n.radarEmptyTitle,
          child: Text(l10n.radarEmptyMessage(basis.minAccounts)),
        ),
      ];
    }
    final years = basis.years;
    return [
      SectionCard(
        icon: Icons.info_outline,
        title: years.isEmpty
            ? l10n.radarBasis(basis.shifts)
            : l10n.radarBasisYears(basis.shifts, years.first, years.last),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: AppSpacing.xs,
          children: [
            Text(l10n.radarHowCounted(basis.minAccounts), style: small),
            if (basis.withheld > 0) Text(l10n.radarWithheld(basis.withheld), style: small),
            Text(
              l10n.radarMostRule((RepeatRules.share * 100).round(), RepeatRules.minPapers),
              style: small,
            ),
          ],
        ),
      ),
      const SizedBox(height: AppSpacing.md),
      for (final topic in report.topics)
        _RadarTopicCard(topic: topic, basis: basis, examCode: _exam),
    ];
  }

  List<Widget> _own(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return [
      ...switch (ref.watch(repeatsProvider(_query))) {
        AsyncData(:final value) => _content(context, value),
        AsyncError() => [
          EmptyState(
            icon: Icons.cloud_off,
            title: l10n.bankLoadError,
            action: OutlinedButton(
              onPressed: () => ref.invalidate(repeatsProvider(_query)),
              child: Text(l10n.retry),
            ),
          ),
        ],
        _ => [
          const Padding(
            padding: EdgeInsets.all(AppSpacing.xl),
            child: Center(child: CircularProgressIndicator()),
          ),
        ],
      },
    ];
  }

  List<Widget> _content(BuildContext context, RepeatsReport report) {
    final l10n = AppLocalizations.of(context);
    if (report.papers.total == 0 && _view == 'shared') {
      return [
        EmptyState(
          icon: Icons.public,
          title: l10n.repeatsSharedEmptyTitle,
          message: l10n.repeatsSharedEmptyMessage,
        ),
      ];
    }
    if (report.papers.total == 0) {
      return [
        EmptyState(
          icon: Icons.insights_outlined,
          title: l10n.repeatsEmptyTitle,
          message: l10n.repeatsEmptyMessage,
          action: FilledButton.icon(
            icon: const Icon(Icons.upload_file),
            label: Text(l10n.repeatsImportPapers),
            onPressed: () => context.push(AppRoutes.documents),
          ),
        ),
      ];
    }
    if (_notRepeated) return _notRepeatedContent(context, report);
    final reviewed = report.topics.where((t) => t.confirmed.questions > 0).toList();
    final unreviewedOnly = report.topics
        .where((t) => t.confirmed.questions == 0 && t.unreviewed > 0)
        .toList();
    return [
      _BasisCard(basis: report.papers, shared: _view == 'shared'),
      const SizedBox(height: AppSpacing.md),
      if (reviewed.isEmpty && unreviewedOnly.isNotEmpty)
        Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.md),
          child: SectionCard(
            icon: Icons.rule,
            title: l10n.repeatsNeedsReviewTitle,
            child: Text(l10n.repeatsNeedsReviewMessage),
          ),
        ),
      for (final topic in [...reviewed, ...unreviewedOnly])
        _TopicCard(topic: topic, basis: report.papers, examCode: _exam),
      if (report.similarGroups.isNotEmpty) ...[
        const SizedBox(height: AppSpacing.md),
        Text(l10n.repeatsSimilarTitle, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: AppSpacing.xs),
        Text(l10n.repeatsSimilarNote, style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: AppSpacing.sm),
        for (final group in report.similarGroups) _SimilarCard(group: group, basis: report.papers),
      ],
    ];
  }
}

extension on _RepeatsScreenState {
  /// Syllabus topics these papers never asked, topics asked in only one paper, and question
  /// types not seen yet. Always with its basis and the warning that it is not a prediction.
  List<Widget> _notRepeatedContent(BuildContext context, RepeatsReport report) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final gaps = report.notRepeated;
    final small = theme.textTheme.bodySmall;
    final bySubject = <String, List<TopicRef>>{};
    for (final t in gaps.notSeen) {
      bySubject.putIfAbsent(t.subject, () => []).add(t);
    }
    final byTopic = <String, List<String>>{};
    for (final g in gaps.patternsNotSeen) {
      byTopic.putIfAbsent(g.topicName, () => []).add(g.name);
    }
    final once = report.seenOnce;

    void study(TopicRef topic) {
      ref.read(conceptQueryProvider.notifier)
        ..setSubject(topic.subject)
        ..setTopic(topic.name);
      context.go(AppRoutes.study);
    }

    return [
      _BasisCard(basis: report.papers, shared: _view == 'shared'),
      const SizedBox(height: AppSpacing.md),
      SectionCard(
        icon: Icons.info_outline,
        title: l10n.notRepeatedWhatTitle,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: AppSpacing.xs,
          children: [
            Text(l10n.notRepeatedNotAPrediction, style: small),
            if (gaps.questionsWithoutTopic > 0)
              Text(l10n.notRepeatedWithoutTopic(gaps.questionsWithoutTopic), style: small),
          ],
        ),
      ),
      const SizedBox(height: AppSpacing.md),
      SectionCard(
        icon: Icons.visibility_off_outlined,
        title: l10n.notRepeatedNotSeenTitle(gaps.notSeen.length),
        child: gaps.notSeen.isEmpty
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    report.topics.isEmpty ? l10n.notRepeatedNoSyllabus : l10n.notRepeatedAllSeen,
                  ),
                  if (report.topics.isEmpty && _exam != null)
                    TextButton(
                      onPressed: () => context.push(AppRoutes.examTopics(_exam!)),
                      child: Text(l10n.masteryAddSyllabus),
                    ),
                ],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final entry in bySubject.entries) ...[
                    Padding(
                      padding: const EdgeInsets.only(top: AppSpacing.sm),
                      child: Text(entry.key, style: theme.textTheme.titleSmall),
                    ),
                    for (final topic in entry.value)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                        title: Text(topic.name),
                        trailing: TextButton(
                          onPressed: () => study(topic),
                          child: Text(l10n.notRepeatedStudy),
                        ),
                      ),
                  ],
                ],
              ),
      ),
      if (once.isNotEmpty) ...[
        const SizedBox(height: AppSpacing.md),
        SectionCard(
          icon: Icons.looks_one_outlined,
          title: l10n.notRepeatedOnceTitle(once.length),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l10n.notRepeatedOnceNote, style: small),
              for (final topic in once)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  title: Text('${topic.name}  ·  ${topic.subject}'),
                  subtitle: topic.confirmed.years.isEmpty
                      ? null
                      : Text(l10n.repeatsByYear(_years(topic.confirmed.years))),
                ),
            ],
          ),
        ),
      ],
      if (byTopic.isNotEmpty) ...[
        const SizedBox(height: AppSpacing.md),
        SectionCard(
          icon: Icons.category_outlined,
          title: l10n.notRepeatedTypesTitle(gaps.patternsNotSeen.length),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l10n.notRepeatedTypesNote, style: small),
              for (final entry in byTopic.entries)
                Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.sm),
                  child: Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(text: '${entry.key}: ', style: theme.textTheme.titleSmall),
                        TextSpan(text: entry.value.join(' · ')),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    ];
  }
}

class _BasisCard extends StatelessWidget {
  const _BasisCard({required this.basis, this.shared = false});

  final PapersBasis basis;

  /// Counting the shared bank rather than the learner's own papers.
  final bool shared;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final small = Theme.of(context).textTheme.bodySmall;
    final years = basis.years;
    return SectionCard(
      icon: Icons.info_outline,
      title: switch ((shared, years.isEmpty)) {
        (true, true) => l10n.repeatsBasisShared(basis.total),
        (true, false) => l10n.repeatsBasisSharedYears(basis.total, years.first, years.last),
        (false, true) => l10n.repeatsBasis(basis.total),
        (false, false) => l10n.repeatsBasisYears(basis.total, years.first, years.last),
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: AppSpacing.xs,
        children: [
          if (RepeatRules.isSmallSample(basis))
            Text(
              l10n.repeatsSmallSample(basis.total, RepeatRules.reliablePapers),
              style: small?.copyWith(color: Theme.of(context).colorScheme.tertiary),
            ),
          if (basis.undated > 0) Text(l10n.repeatsUndated(basis.undated), style: small),
          Text(l10n.repeatsReviewedNote, style: small),
          Text(
            l10n.repeatsMostPapersRule((RepeatRules.share * 100).round(), RepeatRules.minPapers),
            style: small,
          ),
        ],
      ),
    );
  }
}

String _counts(AppLocalizations l10n, RepeatCounts counts, PapersBasis basis) =>
    l10n.repeatsInPapers(counts.papers, basis.total, counts.questions);

String _years(List<YearCount> years) => years.map((y) => '${y.year}: ${y.questions}').join(' · ');

class _TopicCard extends ConsumerWidget {
  const _TopicCard({required this.topic, required this.basis, required this.examCode});

  final TopicRepeat topic;
  final PapersBasis basis;
  final String? examCode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final small = theme.textTheme.bodySmall;
    final most = RepeatRules.seenInMostPapers(topic.confirmed, basis);
    final subtitle = [
      if (topic.confirmed.questions > 0) _counts(l10n, topic.confirmed, basis),
      if (topic.unreviewed > 0) l10n.repeatsUnreviewed(topic.unreviewed),
    ].join('\n');

    return Card(
      child: ExpansionTile(
        shape: const Border(),
        title: Text('${topic.name}  ·  ${topic.subject}'),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(subtitle),
            if (most)
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.xs),
                child: Chip(
                  visualDensity: VisualDensity.compact,
                  avatar: const Icon(Icons.priority_high, size: 16),
                  label: Text(l10n.repeatsSeenInMost),
                  backgroundColor: theme.colorScheme.secondaryContainer,
                ),
              ),
          ],
        ),
        childrenPadding: const EdgeInsets.fromLTRB(AppSpacing.md, 0, AppSpacing.md, AppSpacing.md),
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (topic.confirmed.years.isNotEmpty)
            Text(l10n.repeatsByYear(_years(topic.confirmed.years)), style: small),
          for (final pattern in topic.patterns)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(pattern.name),
              subtitle: Text(
                [
                  _counts(l10n, pattern.confirmed, basis),
                  if (pattern.confirmed.years.isNotEmpty)
                    l10n.repeatsByYear(_years(pattern.confirmed.years)),
                  if (pattern.unreviewed > 0) l10n.repeatsUnreviewed(pattern.unreviewed),
                ].join('\n'),
              ),
              trailing: pattern.confirmed.questions == 0
                  ? null
                  : TextButton(
                      onPressed: () => startAndOpen(
                        context,
                        () => ref
                            .read(practiceRepositoryProvider)
                            .startPractice(
                              PracticeRequest(examCode: examCode, patternId: pattern.patternId),
                            ),
                      ),
                      child: Text(l10n.repeatsPractise),
                    ),
            ),
          if (topic.withoutPattern > 0)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.xs),
              child: Text(l10n.repeatsWithoutPattern(topic.withoutPattern), style: small),
            ),
          if (topic.confirmed.questions > 0)
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: OutlinedButton.icon(
                icon: const Icon(Icons.play_arrow),
                label: Text(l10n.repeatsPractiseTopic),
                onPressed: () => startAndOpen(
                  context,
                  () => ref
                      .read(practiceRepositoryProvider)
                      .startPractice(PracticeRequest(examCode: examCode, topicId: topic.topicId)),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _SimilarCard extends StatelessWidget {
  const _SimilarCard({required this.group, required this.basis});

  final SimilarGroup group;
  final PapersBasis basis;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final small = Theme.of(context).textTheme.bodySmall;
    final heading = group.topicName ?? group.subject ?? l10n.repeatsSimilarUnclassified;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(heading, style: Theme.of(context).textTheme.titleSmall),
            Text(
              [
                l10n.repeatsSimilarPapers(group.papers, basis.total),
                if (group.years.isNotEmpty) group.years.join(', '),
              ].join(' · '),
              style: small,
            ),
            for (final q in group.questions)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(q.stemExcerpt, maxLines: 3, overflow: TextOverflow.ellipsis),
                subtitle: Text(
                  [
                    q.documentFilename,
                    if (q.questionNumber != null) l10n.questionNumberLabel(q.questionNumber!),
                    if (q.examYear != null) '${q.examYear}',
                  ].join(' · '),
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push(AppRoutes.question(q.questionId)),
              ),
          ],
        ),
      ),
    );
  }
}

class _RadarTopicCard extends ConsumerWidget {
  const _RadarTopicCard({required this.topic, required this.basis, required this.examCode});

  final RadarTopic topic;
  final RadarBasis basis;
  final String? examCode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final small = theme.textTheme.bodySmall;
    final most =
        basis.shifts >= RepeatRules.minPapers &&
        topic.counts.shifts / basis.shifts >= RepeatRules.share;
    String years(List<RadarYear> ys) => ys.map((y) => '${y.year}: ${y.shifts}').join(' · ');

    return Card(
      child: ExpansionTile(
        shape: const Border(),
        title: Text('${topic.name}  ·  ${topic.subject}'),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.radarInShifts(topic.counts.shifts, basis.shifts, topic.counts.questions)),
            if (most)
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.xs),
                child: Chip(
                  visualDensity: VisualDensity.compact,
                  avatar: const Icon(Icons.priority_high, size: 16),
                  label: Text(l10n.radarSeenInMost),
                  backgroundColor: theme.colorScheme.secondaryContainer,
                ),
              ),
          ],
        ),
        childrenPadding: const EdgeInsets.fromLTRB(AppSpacing.md, 0, AppSpacing.md, AppSpacing.md),
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (topic.counts.years.isNotEmpty)
            Text(l10n.radarShiftsByYear(years(topic.counts.years)), style: small),
          for (final pattern in topic.patterns)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(pattern.name),
              subtitle: Text(
                l10n.radarInShifts(pattern.counts.shifts, basis.shifts, pattern.counts.questions),
              ),
              trailing: TextButton(
                onPressed: () => startAndOpen(
                  context,
                  () => ref
                      .read(practiceRepositoryProvider)
                      .startPractice(
                        PracticeRequest(examCode: examCode, patternId: pattern.patternId),
                      ),
                ),
                child: Text(l10n.repeatsPractise),
              ),
            ),
        ],
      ),
    );
  }
}
