import 'package:preploop/core/errors/app_failure.dart';
import 'package:preploop/features/sync/data/sync_api.dart';

class _Stored {
  _Stored(this.change, this.seq);

  SyncChange change;
  int seq;
}

/// In-memory server with the backend's sync rules: a note edit from an older version is a
/// conflict (the server keeps its own and returns it), card reviews are append-only, other
/// records: last writer wins; deleted records stay deleted; pull pages after a cursor. Several devices
/// (databases) can share one instance.
class FakeSyncServer implements SyncApi {
  FakeSyncServer({this.pageSize = 500});

  int pageSize;
  bool offline = false;

  /// `entity:id` keys the server rejects as invalid.
  final reject = <String>{};

  /// Runs during a push, before it is applied (to simulate concurrent local edits).
  Future<void> Function()? duringPush;

  final _records = <String, _Stored>{};
  int _seq = 0;
  int pushCount = 0;

  Map<String, dynamic>? data(String entity, String id) => _records['$entity:$id']?.change.data;

  bool isDeleted(String entity, String id) => _records['$entity:$id']?.change.deleted ?? false;

  Iterable<String> get keys => _records.keys;

  @override
  Future<PushOutcome> push(List<SyncChange> changes) async {
    if (offline) throw const NetworkFailure();
    pushCount++;
    await duringPush?.call();
    var accepted = 0;
    final ignored = <String>[];
    final rejected = <String, String>{};
    final seqs = <String, int>{};
    final conflicts = <SyncChange>[];
    for (final change in changes) {
      if (reject.contains(change.key)) {
        rejected[change.key] = 'invalid';
        continue;
      }
      final existing = _records[change.key];
      if (existing != null && existing.change.deleted) {
        ignored.add(change.key);
        continue;
      }
      if (existing != null && change.entity == 'card_review' && !change.deleted) {
        seqs[change.key] = existing.seq; // reviews are never rewritten
        accepted++;
        continue;
      }
      if (existing != null &&
          change.entity == 'concept' &&
          !change.deleted &&
          change.baseSeq != null &&
          change.baseSeq != existing.seq) {
        conflicts.add(_withSeq(existing));
        continue;
      }
      _records[change.key] = _Stored(change, ++_seq);
      seqs[change.key] = _seq;
      accepted++;
    }
    return PushOutcome(
      accepted: accepted,
      ignoredDeleted: ignored,
      rejected: rejected,
      seqs: seqs,
      conflicts: conflicts,
    );
  }

  @override
  Future<PullPage> pull(int cursor) async {
    if (offline) throw const NetworkFailure();
    final after = _records.values.where((r) => r.seq > cursor).toList()
      ..sort((a, b) => a.seq.compareTo(b.seq));
    final page = after.take(pageSize).toList();
    return PullPage(
      changes: [for (final r in page) _withSeq(r)],
      cursor: page.isEmpty ? cursor : page.last.seq,
      hasMore: after.length > page.length,
    );
  }

  static SyncChange _withSeq(_Stored r) => SyncChange(
    entity: r.change.entity,
    id: r.change.id,
    deleted: r.change.deleted,
    data: r.change.data,
    seq: r.seq,
  );
}
