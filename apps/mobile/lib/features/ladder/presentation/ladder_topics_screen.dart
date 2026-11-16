import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../core/localization/generated/app_localizations.dart';
import '../../exams/application/active_exam.dart';
import '../application/ladder_providers.dart';
import '../domain/ladder_models.dart';

/// "Any topic": what the ladder is on. A topic of the exam (the ones repeated in the learner's
/// papers first), questions from the learner's papers, or a typed topic for the AI alone.
class LadderTopicsScreen extends ConsumerStatefulWidget {
  const LadderTopicsScreen({super.key});

  @override
  ConsumerState<LadderTopicsScreen> createState() => _LadderTopicsScreenState();
}

class _LadderTopicsScreenState extends ConsumerState<LadderTopicsScreen> {
  String _search = '';

  /// The learner's choice; until then the first one that has something to offer.
  LadderBasis? _basis;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final overview = ref.watch(ladderOverviewProvider);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.ladderPickTopic)),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: AppSpacing.maxContentWidth),
          child: switch (overview) {
            AsyncData(:final value) => _choices(context, value ?? const LadderOverview()),
            AsyncError() => Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Text(l10n.ladderNoConnection),
            ),
            _ => const Center(child: CircularProgressIndicator()),
          },
        ),
      ),
    );
  }

  Widget _choices(BuildContext context, LadderOverview overview) {
    final l10n = AppLocalizations.of(context);
    final basis =
        _basis ??
        (overview.topics.isNotEmpty
            ? LadderBasis.topic
            : overview.papers.isNotEmpty
            ? LadderBasis.paper
            : LadderBasis.typed);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.md, AppSpacing.md, 0),
          child: SegmentedButton<LadderBasis>(
            showSelectedIcon: false,
            segments: [
              ButtonSegment(value: LadderBasis.topic, label: Text(l10n.ladderChoiceTopics)),
              ButtonSegment(value: LadderBasis.paper, label: Text(l10n.ladderChoicePapers)),
              ButtonSegment(value: LadderBasis.typed, label: Text(l10n.ladderChoiceAi)),
            ],
            selected: {basis},
            onSelectionChanged: (choice) => setState(() => _basis = choice.single),
          ),
        ),
        Expanded(
          child: switch (basis) {
            LadderBasis.topic => _topics(context, overview.topics),
            LadderBasis.paper || LadderBasis.papers => _Papers(papers: overview.papers),
            LadderBasis.typed => const _TypedTopic(),
          },
        ),
      ],
    );
  }

  Widget _topics(BuildContext context, List<LadderTopic> all) {
    final l10n = AppLocalizations.of(context);
    final query = _search.trim().toLowerCase();
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: TextField(
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search),
              hintText: l10n.ladderSearchTopics,
              border: const OutlineInputBorder(),
            ),
            onChanged: (value) => setState(() => _search = value),
          ),
        ),
        Expanded(
          child: _TopicList(
            topics: [
              for (final topic in all)
                if (query.isEmpty ||
                    topic.name.toLowerCase().contains(query) ||
                    topic.subject.toLowerCase().contains(query))
                  topic,
            ],
            examHasTopics: all.isNotEmpty,
            tile: (topic) => ListTile(
              title: Text(topic.name),
              subtitle: Text(
                topic.papers > 0
                    ? '${topic.subject} · ${l10n.ladderTopicPapers(topic.papers)}'
                    : topic.subject,
              ),
              onTap: () => context.pushReplacement(AppRoutes.ladderRun(topic.topicId, topic.name)),
            ),
          ),
        ),
      ],
    );
  }
}

/// The matching topics, or why there are none: the exam has no topics yet (with a way to add
/// them), or the search matched nothing.
class _TopicList extends ConsumerWidget {
  const _TopicList({required this.topics, required this.examHasTopics, required this.tile});

  final List<LadderTopic> topics;
  final bool examHasTopics;
  final Widget Function(LadderTopic topic) tile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    if (topics.isNotEmpty) return ListView(children: [for (final t in topics) tile(t)]);
    final exam = ref.watch(activeExamProvider);
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(examHasTopics ? l10n.ladderNoTopicMatch : l10n.ladderNoTopics),
          if (!examHasTopics && exam != null) ...[
            const SizedBox(height: AppSpacing.sm),
            FilledButton.tonal(
              onPressed: () => context.push(AppRoutes.examTopics(exam)),
              child: Text(l10n.ladderAddTopics),
            ),
          ],
        ],
      ),
    );
  }
}

/// The learner's papers: one of them, or all of them mixed.
class _Papers extends StatelessWidget {
  const _Papers({required this.papers});

  final List<LadderPaper> papers;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    if (papers.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Text(l10n.ladderNoPapers),
      );
    }
    return ListView(
      children: [
        Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Text(l10n.ladderPaperNote, style: theme.textTheme.bodySmall),
        ),
        if (papers.length > 1)
          ListTile(
            leading: const Icon(Icons.library_books_outlined),
            title: Text(l10n.ladderAllPapers),
            subtitle: Text(l10n.ladderAllPapersHint),
            onTap: () => context.pushReplacement(
              AppRoutes.ladderRunOn(LadderBasis.papers.wire, '', l10n.ladderAllPapers),
            ),
          ),
        for (final paper in papers)
          ListTile(
            leading: const Icon(Icons.picture_as_pdf_outlined),
            title: Text(paper.name),
            subtitle: Text(l10n.ladderPaperCounts(paper.questions, paper.reviewed)),
            onTap: () => context.pushReplacement(
              AppRoutes.ladderRunOn(LadderBasis.paper.wire, paper.documentId, paper.name),
            ),
          ),
      ],
    );
  }
}

/// A topic the learner types: the AI writes from web references alone.
class _TypedTopic extends StatefulWidget {
  const _TypedTopic();

  @override
  State<_TypedTopic> createState() => _TypedTopicState();
}

class _TypedTopicState extends State<_TypedTopic> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String get _topic => _controller.text.trim().replaceAll(RegExp(r'\s+'), ' ');

  void _start() {
    if (_topic.length < 2) return;
    context.pushReplacement(AppRoutes.ladderRunOn(LadderBasis.typed.wire, '', _topic));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: [
        TextField(
          controller: _controller,
          maxLength: 100,
          textInputAction: TextInputAction.go,
          decoration: InputDecoration(
            labelText: l10n.ladderTypedLabel,
            hintText: l10n.ladderTypedHint,
            border: const OutlineInputBorder(),
          ),
          onChanged: (_) => setState(() {}),
          onSubmitted: (_) => _start(),
        ),
        Text(l10n.ladderTypedNote, style: theme.textTheme.bodySmall),
        const SizedBox(height: AppSpacing.md),
        FilledButton.icon(
          icon: const Icon(Icons.play_arrow),
          label: Text(l10n.ladderTypedStart),
          onPressed: _topic.length < 2 ? null : _start,
        ),
      ],
    );
  }
}
