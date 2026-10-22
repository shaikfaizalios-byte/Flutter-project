import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../localization/generated/app_localizations.dart';
import '../utils/app_log.dart';
import '../utils/external_links.dart';
import 'adaptive_action.dart';

/// Opens a Google search for [query] in the browser; says so when nothing could open it.
Future<void> openWebSearch(BuildContext context, WidgetRef ref, String query) async {
  final messenger = ScaffoldMessenger.of(context);
  final failed = AppLocalizations.of(context).webSearchOpenFailed;
  var opened = false;
  try {
    opened = await ref.read(linkOpenerProvider)(googleSearchUri(query));
  } on Object catch (error, stack) {
    logError('Opening a web search failed', error, stack);
  }
  if (!opened) messenger.showSnackBar(SnackBar(content: Text(failed)));
}

/// "Search on Google" as a text button (in cards).
class WebSearchButton extends ConsumerWidget {
  const WebSearchButton({super.key, required this.query, required this.label});

  final String query;
  final String label;

  @override
  Widget build(BuildContext context, WidgetRef ref) => TextButton.icon(
    icon: const Icon(Icons.travel_explore),
    label: Text(label),
    onPressed: () => openWebSearch(context, ref, query),
  );
}

/// The same as an app bar action.
class WebSearchAction extends ConsumerWidget {
  const WebSearchAction({super.key, required this.query});

  final String query;

  @override
  Widget build(BuildContext context, WidgetRef ref) => AdaptiveAction(
    icon: Icons.travel_explore,
    label: AppLocalizations.of(context).webSearchLearnMore,
    onPressed: () => openWebSearch(context, ref, query),
  );
}
