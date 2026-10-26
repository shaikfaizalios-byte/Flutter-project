import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../core/localization/generated/app_localizations.dart';
import '../application/import_watcher.dart';
import '../domain/imported_document.dart';

/// Where a paper is in its import, in plain words: waiting, reading page x of y, finding the
/// questions, ready (with how many were found and how many need a look) or failed.
String importStatusText(AppLocalizations l10n, ImportedDocument d) => switch (d.status) {
  DocumentStatus.queued => l10n.documentStatusQueued,
  DocumentStatus.processing => l10n.documentStatusProcessing(d.pagesProcessed + 1, d.pageCount),
  DocumentStatus.completed when d.segmentationStatus == 'pending' => l10n.importFindingQuestions,
  DocumentStatus.completed => '${l10n.documentStatusCompleted} · ${importResultText(l10n, d)}',
  DocumentStatus.failed => l10n.documentStatusFailed,
};

/// "87 questions found · 9 need a look".
String importResultText(AppLocalizations l10n, ImportedDocument d) => d.questionsFound == 0
    ? l10n.documentQuestionsFound(0)
    : '${l10n.documentQuestionsFound(d.questionsFound)} · '
          '${l10n.importNeedALook(d.questionsToCheck)}';

/// Progress 0..1 while pages are read; null (moving bar) while waiting or finding questions.
double? importProgressValue(ImportedDocument d) =>
    d.status == DocumentStatus.processing ? d.progress : null;

/// Shows a message when a followed paper is ready (or failed), on whatever screen is open,
/// with a way to open it. Sits above the router's Navigator, so it opens pages through
/// [routerContext].
class ImportNotices extends ConsumerStatefulWidget {
  const ImportNotices({super.key, required this.routerContext});

  final BuildContext? Function() routerContext;

  @override
  ConsumerState<ImportNotices> createState() => _ImportNoticesState();
}

class _ImportNoticesState extends ConsumerState<ImportNotices> {
  @override
  void initState() {
    super.initState();
    ref.listenManual(importWatcherProvider.select((w) => w.finished), (_, done) {
      if (done != null) _show(done);
    });
  }

  void _show(ImportedDocument d) {
    final context = widget.routerContext();
    ref.read(importWatcherProvider.notifier).acknowledge();
    if (context == null || !context.mounted) return;
    final l10n = AppLocalizations.of(context);
    final router = GoRouter.of(context);
    final failed = d.status == DocumentStatus.failed;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 8),
        content: Text(
          failed
              ? l10n.importFailedNotice(d.filename)
              : l10n.importReadyNotice(d.filename, importResultText(l10n, d)),
        ),
        action: SnackBarAction(
          label: failed ? l10n.importOpenPapers : l10n.importReview,
          onPressed: () => failed
              ? router.push(AppRoutes.documents)
              : router.push(AppRoutes.documentReview(d.id)),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

/// Home: papers still being imported, each with its step and progress.
class ImportsInProgress extends ConsumerWidget {
  const ImportsInProgress({super.key, this.color});

  final Color? color;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final active = ref.watch(importWatcherProvider.select((w) => w.active));
    if (active.isEmpty) return const SizedBox.shrink();
    final style = Theme.of(context).textTheme.bodyMedium?.copyWith(color: color);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final d in active) ...[
          Text(l10n.importOnHome(d.filename, importStatusText(l10n, d)), style: style),
          const SizedBox(height: 4),
          LinearProgressIndicator(value: importProgressValue(d)),
          const SizedBox(height: 8),
        ],
      ],
    );
  }
}
