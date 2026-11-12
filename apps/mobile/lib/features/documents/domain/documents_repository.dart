import 'dart:typed_data';

import '../../concepts/domain/concept.dart';
import 'imported_document.dart';
import 'paper_details.dart';

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

  /// Adds PrepLoop's made-up sample papers to [examCode] (asking twice adds nothing).
  Future<List<ImportedDocument>> addSamples({required String examCode});

  /// Permanently deletes the document and its original file on the server.
  Future<void> delete(String id);

  /// One page (1-based) of the original PDF as PNG bytes, exactly as uploaded.
  Future<Uint8List> pageImage(String id, int page);

  Future<void> setDetails(String id, PaperDetails details);

  /// Papers that look like another set of this one. Only suggestions.
  Future<List<OtherSet>> duplicateSuggestions(String id);

  /// This paper is another set of [otherId] and counts once, as that paper.
  Future<void> markAsSetOf(String id, String otherId);

  /// Fills in missing answers from a separate key. An existing answer is never replaced.
  Future<AnswerKeyResult> sendKeyText(String id, String text);
  Future<AnswerKeyResult> sendKeyFile(String id, UploadSource source);
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
