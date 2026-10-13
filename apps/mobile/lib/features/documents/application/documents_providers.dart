import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/network/api_client.dart';
import '../../../core/utils/app_log.dart';
import '../../concepts/domain/concept.dart';
import '../data/remote_documents_repository.dart';
import '../domain/documents_repository.dart';
import '../domain/imported_document.dart';

final documentsRepositoryProvider = Provider<DocumentsRepository>(
  (ref) => RemoteDocumentsRepository(ref.watch(dioProvider)),
);

/// Opens the platform file picker for a single PDF; null if the user cancels.
/// Overridden in tests.
final pdfPickerProvider = Provider<Future<UploadSource?> Function()>((ref) => _pickPdf);

Future<UploadSource?> _pickPdf() async {
  final file = await FilePicker.pickFile(type: FileType.custom, allowedExtensions: ['pdf']);
  if (file == null) return null;
  final length = await file.length() ?? (await file.readAsBytes()).length;
  return UploadSource(name: file.name, length: length, open: file.readAsByteStream);
}

/// How often the list refreshes while any document is still being processed.
const documentPollInterval = Duration(seconds: 3);

/// The imported documents, refreshed automatically while any is queued or processing.
class DocumentList extends AsyncNotifier<List<ImportedDocument>> {
  Timer? _poll;

  @override
  Future<List<ImportedDocument>> build() async {
    ref.onDispose(() => _poll?.cancel());
    final documents = await ref.watch(documentsRepositoryProvider).list();
    _poll?.cancel();
    if (documents.any((d) => d.status.isActive)) {
      _poll = Timer(documentPollInterval, ref.invalidateSelf);
    }
    return documents;
  }

  Future<void> delete(String id) async {
    await ref.read(documentsRepositoryProvider).delete(id);
    ref.invalidateSelf();
  }
}

final documentListProvider =
    AsyncNotifierProvider.autoDispose<DocumentList, List<ImportedDocument>>(
      DocumentList.new,
      // Show connectivity problems instead of retrying silently; the user can retry.
      retry: (retryCount, error) => null,
    );

@immutable
sealed class UploadState {
  const UploadState();
}

class UploadIdle extends UploadState {
  const UploadIdle();
}

class UploadInProgress extends UploadState {
  const UploadInProgress(this.filename, this.progress, this.cancellation);

  final String filename;
  final double progress;
  final UploadCancellation cancellation;
}

class UploadSucceeded extends UploadState {
  const UploadSucceeded(this.document);

  final ImportedDocument document;
}

class UploadFailed extends UploadState {
  const UploadFailed(this.failure);

  final AppFailure failure;
}

/// Drives one upload at a time and refreshes the list when it finishes.
class UploadController extends Notifier<UploadState> {
  @override
  UploadState build() => const UploadIdle();

  bool get isUploading => state is UploadInProgress;

  Future<void> upload(
    UploadSource source, {
    required String examCode,
    required ContentLanguage language,
  }) async {
    if (isUploading) return; // no duplicate submissions
    final cancellation = UploadCancellation();
    state = UploadInProgress(source.name, 0, cancellation);
    try {
      final document = await ref
          .read(documentsRepositoryProvider)
          .upload(
            source,
            examCode: examCode,
            language: language,
            cancellation: cancellation,
            onProgress: (p) {
              if (state case UploadInProgress(:final filename)) {
                state = UploadInProgress(filename, p, cancellation);
              }
            },
          );
      state = UploadSucceeded(document);
      ref.invalidate(documentListProvider);
    } on CancelledFailure {
      state = const UploadIdle();
    } on AppFailure catch (failure) {
      state = UploadFailed(failure);
    } on Object catch (error, stack) {
      logError('Upload failed', error, stack);
      state = UploadFailed(UnexpectedFailure(error));
    }
  }

  void cancel() {
    if (state case UploadInProgress(:final cancellation)) cancellation.cancel();
  }

  void reset() => state = const UploadIdle();
}

final uploadControllerProvider = NotifierProvider<UploadController, UploadState>(
  UploadController.new,
);
