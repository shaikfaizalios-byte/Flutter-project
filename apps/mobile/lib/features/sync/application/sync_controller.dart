import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/sync_outbox.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/network/api_client.dart';
import '../../../core/utils/app_log.dart';
import '../../auth/application/auth_controller.dart';
import '../../study_plan/application/study_profile_controller.dart';
import '../data/sync_api.dart';
import '../data/sync_engine.dart';

final syncApiProvider = Provider<SyncApi>((ref) => RemoteSyncApi(ref.watch(dioProvider)));

final syncEngineProvider = Provider<SyncEngine>(
  (ref) => SyncEngine(ref.watch(appDatabaseProvider), ref.watch(syncApiProvider)),
);

/// Background syncing (start, resume, shortly after local changes). Off in widget tests,
/// which drive sync explicitly.
final autoSyncProvider = Provider<bool>((ref) => true);

/// Waits this long after a local change before syncing (changes are batched).
const syncDebounce = Duration(seconds: 3);

@immutable
class SyncStatus {
  const SyncStatus({this.syncing = false, this.pending = 0, this.lastSyncedAt, this.error});

  final bool syncing;

  /// Local changes not uploaded yet.
  final int pending;
  final DateTime? lastSyncedAt;

  /// Why the last attempt failed (null after a success).
  final AppFailure? error;

  SyncStatus copyWith({
    bool? syncing,
    int? pending,
    DateTime? lastSyncedAt,
    AppFailure? Function()? error,
  }) => SyncStatus(
    syncing: syncing ?? this.syncing,
    pending: pending ?? this.pending,
    lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
    error: error != null ? error() : this.error,
  );
}

class SyncController extends Notifier<SyncStatus> {
  Future<void>? _running;
  Timer? _debounce;

  @override
  SyncStatus build() {
    final engine = ref.watch(syncEngineProvider);
    final pending = engine.watchPending().listen((count) {
      state = state.copyWith(pending: count);
      if (count > 0 && ref.read(autoSyncProvider)) {
        _debounce?.cancel();
        _debounce = Timer(syncDebounce, syncNow);
      }
    });
    ref.onDispose(() {
      pending.cancel();
      _debounce?.cancel();
    });
    if (ref.read(autoSyncProvider)) {
      final lifecycle = AppLifecycleListener(onResume: syncNow);
      ref.onDispose(lifecycle.dispose);
      Future.microtask(syncNow);
    }
    unawaited(
      engine.lastSyncedAt().then((at) {
        if (ref.mounted && at != null) state = state.copyWith(lastSyncedAt: at);
      }),
    );
    return const SyncStatus();
  }

  /// Uploads local changes and downloads changes from other devices. Safe to call any
  /// time: runs once at a time and does nothing when signed out.
  Future<void> syncNow() => _running ??= _run().whenComplete(() => _running = null);

  Future<void> _run() async {
    if (!ref.read(authControllerProvider).signedIn) return;
    state = state.copyWith(syncing: true);
    try {
      final engine = ref.read(syncEngineProvider);
      final report = await engine.run();
      if (report.pulledEntities.contains(SyncEntity.studyProfile)) {
        await ref.read(studyProfileProvider.notifier).reload();
      }
      final pending = await engine.pendingCount();
      if (!ref.mounted) return;
      state = state.copyWith(
        syncing: false,
        pending: pending,
        lastSyncedAt: DateTime.now(),
        error: () => null,
      );
    } on AppFailure catch (failure) {
      final pending = await ref.read(syncEngineProvider).pendingCount();
      if (ref.mounted) {
        state = state.copyWith(syncing: false, pending: pending, error: () => failure);
      }
    } on Object catch (error, stack) {
      logError('Sync failed', error, stack);
      if (ref.mounted) {
        state = state.copyWith(
          syncing: false,
          error: () => const ServerFailure(statusCode: 0, code: 'sync_failed'),
        );
      }
    }
  }
}

final syncControllerProvider = NotifierProvider<SyncController, SyncStatus>(SyncController.new);
