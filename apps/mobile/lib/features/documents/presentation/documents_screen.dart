import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../core/errors/app_failure.dart';
import '../../exams/application/exam_catalog_controller.dart';
import '../../../core/localization/generated/app_localizations.dart';
import '../../../core/utils/app_log.dart';
import '../../../core/widgets/empty_state.dart';
import '../../concepts/domain/concept.dart';
import '../application/documents_providers.dart';
import '../domain/imported_document.dart';
import 'import_progress.dart';
import '../../exams/application/active_exam.dart';
import '../../../core/database/app_database.dart';
import '../../exams/application/syllabus_prompt.dart';

/// Lists imported PDFs with live processing status, and imports new ones.
class DocumentsScreen extends ConsumerWidget {
  const DocumentsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final documents = ref.watch(documentListProvider);
    final upload = ref.watch(uploadControllerProvider);

    ref.listen(uploadControllerProvider, (_, next) {
      final messenger = ScaffoldMessenger.of(context);
      switch (next) {
        case UploadSucceeded():
          messenger.showSnackBar(SnackBar(content: Text(l10n.importDone)));
          ref.read(uploadControllerProvider.notifier).reset();
        case UploadFailed(:final failure):
          messenger.showSnackBar(SnackBar(content: Text(uploadErrorMessage(l10n, failure))));
          ref.read(uploadControllerProvider.notifier).reset();
        case UploadIdle() || UploadInProgress():
          break;
      }
    });

    return Scaffold(
      appBar: AppBar(title: Text(l10n.documentsTitle)),
      floatingActionButton: upload is UploadInProgress
          ? null
          : FloatingActionButton.extended(
              onPressed: () => _startImport(context, ref),
              icon: const Icon(Icons.upload_file),
              label: Text(l10n.documentsImport),
            ),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: AppSpacing.maxContentWidth),
          child: Column(
            children: [
              if (upload case UploadInProgress(:final filename, :final progress))
                _UploadBanner(filename: filename, progress: progress),
              Expanded(
                child: switch (documents) {
                  AsyncData(:final value) when value.isEmpty => EmptyState(
                    icon: Icons.picture_as_pdf_outlined,
                    title: l10n.documentsEmptyTitle,
                    message: l10n.documentsEmptyMessage,
                  ),
                  AsyncData(:final value) => RefreshIndicator(
                    onRefresh: () => ref.refresh(documentListProvider.future),
                    child: ListView.separated(
                      padding: const EdgeInsets.only(bottom: 88),
                      itemCount: value.length,
                      separatorBuilder: (context, index) => const Divider(height: 1),
                      itemBuilder: (context, index) => _DocumentTile(document: value[index]),
                    ),
                  ),
                  AsyncError(:final error) => EmptyState(
                    icon: _isConnectivity(error) ? Icons.cloud_off : Icons.error_outline,
                    title: _isConnectivity(error)
                        ? l10n.documentsOfflineTitle
                        : l10n.documentsLoadError,
                    message: _isConnectivity(error) ? l10n.documentsOfflineMessage : null,
                    action: OutlinedButton(
                      onPressed: () => ref.invalidate(documentListProvider),
                      child: Text(l10n.retry),
                    ),
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

  static bool _isConnectivity(Object error) =>
      error is NetworkFailure ||
      error is TimeoutFailure ||
      (error is ServerFailure && error.statusCode == 503);

  /// Before the first paper of an exam: offer to import its syllabus, so topics are in place
  /// to sort questions and track revision. Returns false when the learner went to do that.
  Future<bool> _syllabusFirst(BuildContext context, WidgetRef ref) async {
    final exam = ref.read(activeExamProvider);
    if (exam == null) return true;
    final db = ref.read(appDatabaseProvider);
    try {
      if (await syllabusSkipped(db, exam)) return true;
      final topics = await ref.read(examTopicsProvider(exam).future);
      if (topics.any((t) => t.own)) return true;
    } on Object catch (error, stack) {
      logError('Checking the syllabus failed', error, stack);
      return true; // offline or similar: don't block importing
    }
    if (!context.mounted) return false;
    final l10n = AppLocalizations.of(context);
    final name = ref.read(examNameProvider(exam));
    final choice = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.syllabusPromptTitle(name)),
        content: Text(l10n.syllabusPromptMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.syllabusPromptSkip),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.syllabusImport),
          ),
        ],
      ),
    );
    if (choice == null || !context.mounted) return false;
    if (choice) {
      unawaited(context.push(AppRoutes.examTopics(exam, importSyllabus: true)));
      return false;
    }
    await skipSyllabus(db, exam);
    return true;
  }

  Future<void> _startImport(BuildContext context, WidgetRef ref) async {
    if (!await _syllabusFirst(context, ref) || !context.mounted) return;
    final UploadSource? source;
    try {
      source = await ref.read(pdfPickerProvider)();
    } on Object catch (error, stack) {
      logError('Picking a PDF failed', error, stack);
      return;
    }
    if (source == null || !context.mounted) return;
    final choice = await showModalBottomSheet<_ImportChoice>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => _ImportSheet(filename: source!.name),
    );
    if (choice == null) return;
    await ref
        .read(uploadControllerProvider.notifier)
        .upload(source, examCode: choice.examCode, language: choice.language);
  }
}

/// User-facing message for an upload failure, based on the server's error code.
String uploadErrorMessage(AppLocalizations l10n, AppFailure failure) => switch (failure) {
  NetworkFailure() || TimeoutFailure() => l10n.uploadErrorOffline,
  ServerFailure(code: 'file_too_large') => l10n.uploadErrorTooLarge,
  ServerFailure(code: 'unsupported_file_type') => l10n.uploadErrorNotPdf,
  ServerFailure(code: 'encrypted_pdf') => l10n.uploadErrorEncrypted,
  ServerFailure(code: 'invalid_pdf') => l10n.uploadErrorInvalid,
  ServerFailure(code: 'too_many_pages') => l10n.uploadErrorTooManyPages,
  ServerFailure(code: 'empty_file') => l10n.uploadErrorEmpty,
  ServerFailure(code: 'rate_limited') => l10n.uploadErrorRateLimited,
  ServerFailure(statusCode: 503) => l10n.uploadErrorOffline,
  _ => l10n.uploadErrorGeneric,
};

class _UploadBanner extends ConsumerWidget {
  const _UploadBanner({required this.filename, required this.progress});

  final String filename;
  final double progress;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    return Card(
      margin: const EdgeInsets.all(AppSpacing.md),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text(l10n.importUploading(filename))),
                TextButton(
                  onPressed: ref.read(uploadControllerProvider.notifier).cancel,
                  child: Text(l10n.cancel),
                ),
              ],
            ),
            LinearProgressIndicator(value: progress),
          ],
        ),
      ),
    );
  }
}

class _ImportChoice {
  const _ImportChoice(this.examCode, this.language);

  final String examCode;
  final ContentLanguage language;
}

class _ImportSheet extends ConsumerStatefulWidget {
  const _ImportSheet({required this.filename});

  final String filename;

  @override
  ConsumerState<_ImportSheet> createState() => _ImportSheetState();
}

class _ImportSheetState extends ConsumerState<_ImportSheet> {
  late String _exam;

  ContentLanguage? _language;

  @override
  void initState() {
    super.initState();
    // New papers go to the current exam (switched from Home only).
    _exam = ref.read(activeExamProvider) ?? ref.read(examCatalogProvider).first.code;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    _language ??= Localizations.localeOf(context).languageCode == 'hi'
        ? ContentLanguage.hindi
        : ContentLanguage.english;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.importSheetTitle(widget.filename),
              style: theme.textTheme.titleLarge,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Icon(Icons.flag_outlined, size: 18, color: theme.colorScheme.onSurfaceVariant),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    l10n.importExamNote(ref.watch(examNameProvider(_exam))),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Text(l10n.fieldContentLanguage, style: theme.textTheme.labelLarge),
            const SizedBox(height: AppSpacing.sm),
            SegmentedButton<ContentLanguage>(
              segments: [
                ButtonSegment(value: ContentLanguage.english, label: Text(l10n.languageEnglish)),
                ButtonSegment(value: ContentLanguage.hindi, label: Text(l10n.languageHindi)),
              ],
              selected: {_language!},
              onSelectionChanged: (s) => setState(() => _language = s.first),
            ),
            const SizedBox(height: AppSpacing.lg),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(l10n.cancel)),
                const SizedBox(width: AppSpacing.sm),
                FilledButton(
                  onPressed: () => Navigator.of(context).pop(_ImportChoice(_exam, _language!)),
                  child: Text(l10n.importUpload),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DocumentTile extends ConsumerWidget {
  const _DocumentTile({required this.document});

  final ImportedDocument document;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final language = document.language == ContentLanguage.hindi
        ? l10n.languageHindi
        : l10n.languageEnglish;

    final statusText = importStatusText(l10n, document);
    final statusColor = switch (document.status) {
      DocumentStatus.queued => theme.colorScheme.onSurfaceVariant,
      DocumentStatus.failed => theme.colorScheme.error,
      _ => theme.colorScheme.primary,
    };
    final finding =
        document.status == DocumentStatus.completed && document.segmentationStatus == 'pending';

    return ListTile(
      onTap: document.status == DocumentStatus.failed
          ? null
          : () => showPaperActions(context, document),
      leading: Icon(
        document.status == DocumentStatus.failed ? Icons.error_outline : Icons.picture_as_pdf,
        color: statusColor,
      ),
      title: Text(document.filename, maxLines: 2, overflow: TextOverflow.ellipsis),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${ref.watch(examNameProvider(document.examCode))} · $language · '
            '${l10n.documentPages(document.pageCount)}',
          ),
          Text(statusText, style: TextStyle(color: statusColor)),
          if (document.status.isActive || finding)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.xs),
              child: LinearProgressIndicator(value: importProgressValue(document)),
            ),
          if (document.needsReviewCount > 0)
            Row(
              children: [
                Icon(Icons.flag_outlined, size: 16, color: theme.colorScheme.tertiary),
                const SizedBox(width: AppSpacing.xs),
                Text(l10n.documentNeedsReview(document.needsReviewCount)),
              ],
            ),
          if (document.status == DocumentStatus.failed)
            Text(switch (document.errorCode) {
              'processing_timeout' => l10n.documentErrorTimeout,
              'source_file_missing' => l10n.documentErrorSourceMissing,
              _ => l10n.documentErrorGeneric,
            }),
        ],
      ),
      isThreeLine: true,
      trailing: PopupMenuButton<String>(
        tooltip: l10n.documentOptions(document.filename),
        onSelected: (_) => _confirmDelete(context, ref),
        itemBuilder: (context) => [PopupMenuItem(value: 'delete', child: Text(l10n.conceptDelete))],
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.documentDeleteTitle),
        content: Text(l10n.documentDeleteMessage(document.filename)),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: Text(l10n.cancel)),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.conceptDelete),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ref.read(documentListProvider.notifier).delete(document.id);
      messenger.showSnackBar(SnackBar(content: Text(l10n.documentDeleted)));
    } on AppFailure catch (failure) {
      messenger.showSnackBar(SnackBar(content: Text(uploadErrorMessage(l10n, failure))));
    }
  }
}

/// What to do with a paper: solve its questions, read it as uploaded, or review what was read.
Future<void> showPaperActions(BuildContext context, ImportedDocument document) {
  final l10n = AppLocalizations.of(context);
  final router = GoRouter.of(context);
  final canSolve =
      document.canReview && document.segmentationStatus != 'pending' && document.questionsFound > 0;
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (sheet) {
      void open(String location) {
        Navigator.of(sheet).pop();
        router.push(location);
      }

      return SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.md, 0, AppSpacing.md, AppSpacing.sm),
              child: Text(
                l10n.paperActionsTitle(document.filename),
                style: Theme.of(sheet).textTheme.titleMedium,
              ),
            ),
            ListTile(
              leading: const Icon(Icons.edit_note),
              title: Text(l10n.paperSolve),
              subtitle: Text(
                canSolve ? l10n.paperSolveHint(document.questionsFound) : l10n.paperSolveNotReady,
              ),
              enabled: canSolve,
              onTap: () => open(AppRoutes.paperSolve(document.id, document.filename)),
            ),
            ListTile(
              leading: const Icon(Icons.chrome_reader_mode_outlined),
              title: Text(l10n.paperRead),
              subtitle: Text(l10n.paperReadHint),
              enabled: document.pageCount > 0,
              onTap: () =>
                  open(AppRoutes.paperRead(document.id, document.filename, document.pageCount)),
            ),
            ListTile(
              leading: const Icon(Icons.fact_check_outlined),
              title: Text(l10n.paperReview),
              subtitle: Text(l10n.paperReviewHint),
              enabled: document.canReview,
              onTap: () => open(AppRoutes.documentReview(document.id)),
            ),
          ],
        ),
      );
    },
  );
}
