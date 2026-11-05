import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../core/localization/generated/app_localizations.dart';
import '../application/ladder_providers.dart';
import '../domain/ladder_models.dart';

/// "Any topic": the exam's topics to search, the ones repeated in the learner's papers first.
class LadderTopicsScreen extends ConsumerStatefulWidget {
  const LadderTopicsScreen({super.key});

  @override
  ConsumerState<LadderTopicsScreen> createState() => _LadderTopicsScreenState();
}

class _LadderTopicsScreenState extends ConsumerState<LadderTopicsScreen> {
  String _search = '';

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final overview = ref.watch(ladderOverviewProvider);
    final query = _search.trim().toLowerCase();
    return Scaffold(
      appBar: AppBar(title: Text(l10n.ladderPickTopic)),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: AppSpacing.maxContentWidth),
          child: Column(
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
                child: switch (overview) {
                  AsyncData(:final value) => ListView(
                    children: [
                      for (final topic in value?.topics ?? const <LadderTopic>[])
                        if (query.isEmpty ||
                            topic.name.toLowerCase().contains(query) ||
                            topic.subject.toLowerCase().contains(query))
                          ListTile(
                            title: Text(topic.name),
                            subtitle: Text(
                              topic.papers > 0
                                  ? '${topic.subject} · ${l10n.ladderTopicPapers(topic.papers)}'
                                  : topic.subject,
                            ),
                            onTap: () => context.pushReplacement(
                              AppRoutes.ladderRun(topic.topicId, topic.name),
                            ),
                          ),
                    ],
                  ),
                  AsyncError() => Padding(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: Text(l10n.ladderNoConnection),
                  ),
                  _ => const Center(child: CircularProgressIndicator()),
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
