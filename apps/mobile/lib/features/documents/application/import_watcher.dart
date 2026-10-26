import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/app_log.dart';
import '../domain/imported_document.dart';
import 'documents_providers.dart';

/// Papers imported in this session that are still being read, and the one that just finished
/// (shown once as a message wherever the learner is).
@immutable
class ImportWatch {
  const ImportWatch({this.active = const [], this.finished});

  final List<ImportedDocument> active;
  final ImportedDocument? finished;
}

/// Read pages, then found the questions (or failed): nothing more will change by itself.
bool importFinished(ImportedDocument d) =>
    d.status == DocumentStatus.failed ||
    (d.status == DocumentStatus.completed && d.segmentationStatus != 'pending');

/// Follows uploaded papers until they are ready, on any screen. Polls the server only while
/// one is in progress.
class ImportWatcher extends Notifier<ImportWatch> {
  Timer? _timer;

  @override
  ImportWatch build() {
    ref.onDispose(() => _timer?.cancel());
    return const ImportWatch();
  }

  void follow(ImportedDocument document) {
    if (importFinished(document)) return;
    state = ImportWatch(
      active: [
        for (final d in state.active)
          if (d.id != document.id) d,
        document,
      ],
    );
    _schedule();
  }

  /// The "ready" message was shown.
  void acknowledge() => state = ImportWatch(active: state.active);

  void _schedule() {
    _timer?.cancel();
    if (state.active.isNotEmpty) _timer = Timer(documentPollInterval, _poll);
  }

  Future<void> _poll() async {
    try {
      final latest = {for (final d in await ref.read(documentsRepositoryProvider).list()) d.id: d};
      final active = <ImportedDocument>[];
      ImportedDocument? finished;
      for (final d in state.active) {
        final now = latest[d.id];
        if (now == null) continue; // deleted meanwhile
        if (importFinished(now)) {
          finished = now;
        } else {
          active.add(now);
        }
      }
      if (!ref.mounted) return;
      state = ImportWatch(active: active, finished: finished ?? state.finished);
      if (finished != null) ref.invalidate(documentListProvider);
    } on Object catch (error, stack) {
      logError('Checking an import failed', error, stack); // tried again shortly
    }
    if (ref.mounted) _schedule();
  }
}

final importWatcherProvider = NotifierProvider<ImportWatcher, ImportWatch>(ImportWatcher.new);
