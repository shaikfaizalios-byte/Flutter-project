import '../../concepts/domain/concept.dart';
import 'imported_document.dart';

/// Server-backed document storage. Methods throw `AppFailure`s on errors.
abstract interface class DocumentsRepository {
  Future<List<ImportedDocument>> list();

  /// Uploads [source]; [onProgress] receives 0..1 as bytes are sent.
  Future<ImportedDocument> upload(
    UploadSource source, {
    required String examCode,
    required ContentLanguage language,
    void Function(double progress)? onProgress,
    UploadCancellation? cancellation,
  });

  /// Permanently deletes the document and its original file on the server.
  Future<void> delete(String id);
}

/// Lets the UI cancel an in-flight upload without depending on Dio.
class UploadCancellation {
  final List<void Function()> _listeners = [];
  bool _cancelled = false;

  bool get isCancelled => _cancelled;

  void cancel() {
    if (_cancelled) return;
    _cancelled = true;
    for (final listener in _listeners) {
      listener();
    }
  }

  void onCancel(void Function() listener) => _cancelled ? listener() : _listeners.add(listener);
}
