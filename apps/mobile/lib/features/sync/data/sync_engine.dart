import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';

import '../../../core/database/app_database.dart';
import '../../exams/application/exam_catalog_controller.dart' show examCatalogCacheKey;
import '../../../core/database/sync_outbox.dart';
import '../../../core/utils/app_log.dart';
import 'sync_api.dart';

/// Result of one sync run.
@immutable
class SyncReport {
  const SyncReport({
    this.pushed = 0,
    this.pulled = 0,
    this.dropped = 0,
    this.pulledEntities = const {},
  });

  final int pushed;
  final int pulled;

  /// Record types that changed locally because of the pull.
  final Set<String> pulledEntities;

  /// Local changes the server refused (invalid); they are not retried.
  final int dropped;
}

/// Device side of sync (rules: docs/database.md "Sync rules").
///
/// 1. **Push**: every record in the outbox is uploaded with its *current* local state (or
///    as deleted if it no longer exists). Outbox rows are cleared only if they were not
///    changed again meanwhile.
/// 2. **Pull**: all server changes after the stored cursor are fetched, then applied in
///    one transaction (parents before children, foreign keys checked at commit). A record
///    that still has a local pending change is skipped: the local change wins and is
///    pushed next time. Applying pulled data never marks anything dirty.
class SyncEngine {
  SyncEngine(this._db, this._api);

  final AppDatabase _db;
  final SyncApi _api;

  static const cursorKey = 'sync_cursor';
  static const lastSyncedKey = 'sync_last_synced_at';
  static const _batch = 200;

  Future<SyncReport> run() async {
    final (pushed, dropped) = await _push();
    final entities = await _pull();
    await _setSetting(lastSyncedKey, DateTime.now().toUtc().toIso8601String());
    return SyncReport(
      pushed: pushed,
      pulled: entities.length,
      dropped: dropped,
      pulledEntities: entities.toSet(),
    );
  }

  /// Number of local changes waiting to be uploaded.
  Stream<int> watchPending() {
    final count = _db.syncOutbox.entityId.count();
    return (_db.selectOnly(
      _db.syncOutbox,
    )..addColumns([count])).watchSingle().map((row) => row.read(count) ?? 0);
  }

  /// One-off count of local changes waiting to be uploaded.
  Future<int> pendingCount() async {
    final count = _db.syncOutbox.entityId.count();
    final row = await (_db.selectOnly(_db.syncOutbox)..addColumns([count])).getSingle();
    return row.read(count) ?? 0;
  }

  Future<DateTime?> lastSyncedAt() async => DateTime.tryParse(await _setting(lastSyncedKey) ?? '');

  /// Queues every local record for upload (first sync of an account on this device).
  Future<void> markAllDirty() => _db.transaction(() async {
    for (final id in await _ids(_db.concepts, _db.concepts.id)) {
      await _db.markDirty(SyncEntity.concept, id);
    }
    if ((await _db.select(_db.studyProfiles).get()).isNotEmpty) {
      await _db.markDirty(SyncEntity.studyProfile, SyncEntity.profileId);
    }
    for (final id in await _ids(_db.revisionCards, _db.revisionCards.id)) {
      await _db.markDirty(SyncEntity.revisionCard, id);
    }
    for (final review in await _db.select(_db.cardReviews).get()) {
      if (review.syncId != null) await _db.markDirty(SyncEntity.cardReview, review.syncId!);
    }
    if (await _setting(SyncEntity.revisionOffsetsId) != null) {
      await _db.markDirty(SyncEntity.setting, SyncEntity.revisionOffsetsId);
    }
  });

  /// Removes everything that belongs to the signed-in learner from this device (sign-out
  /// or switching accounts). Device preferences (language, theme) stay.
  Future<void> eraseLocalUserData() => _db.transaction(() async {
    await _db.delete(_db.cardReviews).go();
    await _db.delete(_db.revisionCards).go();
    await _db.delete(_db.concepts).go();
    await _db.delete(_db.studyProfiles).go();
    await _db.delete(_db.pendingAnswers).go();
    await _db.delete(_db.syncOutbox).go();
    await (_db.delete(_db.appSettings)..where(
          (s) => s.key.isIn([
            SyncEntity.revisionOffsetsId,
            cursorKey,
            lastSyncedKey,
            examCatalogCacheKey,
          ]),
        ))
        .go();
  });

  // --- push ---------------------------------------------------------------------------

  Future<(int, int)> _push() async {
    var pushed = 0;
    var dropped = 0;
    for (var round = 0; round < 50; round++) {
      final entries =
          await (_db.select(_db.syncOutbox)
                ..orderBy([(o) => OrderingTerm.asc(o.changedAt)])
                ..limit(_batch))
              .get();
      if (entries.isEmpty) break;
      final changes = [for (final e in entries) await _changeFor(e.entity, e.entityId)];
      final outcome = await _api.push(changes); // throws when offline: outbox kept
      await _db.transaction(() async {
        for (final entry in entries) {
          await (_db.delete(_db.syncOutbox)..where(
                (o) =>
                    o.entity.equals(entry.entity) &
                    o.entityId.equals(entry.entityId) &
                    o.version.equals(entry.version),
              ))
              .go();
        }
        // Deleted elsewhere: the deletion wins, so remove our copy too.
        for (final key in outcome.ignoredDeleted) {
          final (entity, id) = _split(key);
          await _deleteLocal(entity, id);
        }
      });
      if (outcome.rejected.isNotEmpty) {
        logError('Sync rejected ${outcome.rejected.length} changes', outcome.rejected.keys);
      }
      pushed += outcome.accepted;
      dropped += outcome.rejected.length;
      if (entries.length < _batch) break;
    }
    return (pushed, dropped);
  }

  Future<SyncChange> _changeFor(String entity, String id) async {
    final data = switch (entity) {
      SyncEntity.concept => await _conceptData(id),
      SyncEntity.studyProfile => await _profileData(),
      SyncEntity.revisionCard => await _cardData(id),
      SyncEntity.cardReview => await _reviewData(id),
      SyncEntity.setting => await _settingData(id),
      _ => null,
    };
    return SyncChange(entity: entity, id: id, deleted: data == null, data: data);
  }

  Future<Map<String, dynamic>?> _conceptData(String id) async {
    final c = await (_db.select(_db.concepts)..where((t) => t.id.equals(id))).getSingleOrNull();
    if (c == null) return null;
    return {
      'exam_code': c.examCode,
      'title': c.title,
      'notes': c.notes,
      'subject': c.subject,
      'topic': c.topic,
      'subtopic': c.subtopic,
      'language': c.language,
      'tags': c.tags,
      'source_reference': c.sourceReference,
      'archived_at': _iso(c.archivedAt),
      'created_at': _iso(c.createdAt),
      'updated_at': _iso(c.updatedAt),
    };
  }

  Future<Map<String, dynamic>?> _profileData() async {
    final p = await _db.select(_db.studyProfiles).getSingleOrNull();
    if (p == null) return null;
    return {
      'exam_codes': p.examCodes,
      'target_exam_date': p.targetExamDate,
      'daily_study_minutes': p.dailyStudyMinutes,
      'reminder_minutes': p.reminderMinutes,
      'onboarding_completed_at': _iso(p.onboardingCompletedAt),
      'updated_at': _iso(p.updatedAt),
    };
  }

  Future<Map<String, dynamic>?> _cardData(String id) async {
    final c = await (_db.select(
      _db.revisionCards,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
    if (c == null) return null;
    return {
      'kind': c.kind,
      'concept_id': c.conceptId,
      'question_id': c.questionId,
      'front': c.front,
      'back': c.back,
      'source_filename': c.sourceFilename,
      'source_page': c.sourcePage,
      'exam_code': c.examCode,
      'subject': c.subject,
      'topic': c.topic,
      'reason': c.reason,
      'step': c.step,
      'gap_days': c.gapDays,
      'due_on': c.dueOn,
      'review_count': c.reviewCount,
      'lapse_count': c.lapseCount,
      'last_reviewed_at': _iso(c.lastReviewedAt),
      'created_at': _iso(c.createdAt),
      'updated_at': _iso(c.updatedAt),
    };
  }

  Future<Map<String, dynamic>?> _reviewData(String syncId) async {
    final r = await (_db.select(
      _db.cardReviews,
    )..where((t) => t.syncId.equals(syncId))).getSingleOrNull();
    if (r == null) return null;
    return {
      'card_id': r.cardId,
      'reviewed_at': _iso(r.reviewedAt),
      'rating': r.rating,
      'due_before': r.dueBefore,
      'due_after': r.dueAfter,
      'gap_days': r.gapDays,
    };
  }

  Future<Map<String, dynamic>?> _settingData(String key) async {
    final value = await _setting(key);
    return value == null ? null : {'value': value};
  }

  // --- pull ---------------------------------------------------------------------------

  /// Applies server changes; returns the entity type of each applied change.
  Future<List<String>> _pull() async {
    var cursor = int.tryParse(await _setting(cursorKey) ?? '') ?? 0;
    final latest = <String, SyncChange>{}; // newest version of each record wins
    for (var page = 0; page < 1000; page++) {
      final result = await _api.pull(cursor);
      for (final change in result.changes) {
        latest[change.key] = change;
      }
      cursor = result.cursor;
      if (!result.hasMore) break;
    }
    final pending = {
      for (final o in await _db.select(_db.syncOutbox).get()) '${o.entity}:${o.entityId}',
    };
    const order = [
      SyncEntity.concept,
      SyncEntity.studyProfile,
      SyncEntity.setting,
      SyncEntity.revisionCard,
      SyncEntity.cardReview,
    ];
    final changes = latest.values.where((c) => !pending.contains(c.key)).toList()
      ..sort((a, b) => order.indexOf(a.entity).compareTo(order.indexOf(b.entity)));
    final applied = <String>[];
    await _db.transaction(() async {
      await _db.customStatement('PRAGMA defer_foreign_keys = ON');
      for (final change in changes) {
        if (await _apply(change)) applied.add(change.entity);
      }
      await _setSetting(cursorKey, '$cursor');
    });
    return applied;
  }

  Future<bool> _apply(SyncChange change) async {
    if (change.deleted || change.data == null) {
      await _deleteLocal(change.entity, change.id);
      return true;
    }
    final d = change.data!;
    switch (change.entity) {
      case SyncEntity.concept:
        await _db
            .into(_db.concepts)
            .insertOnConflictUpdate(
              ConceptsCompanion.insert(
                id: change.id,
                examCode: d['exam_code'] as String,
                title: d['title'] as String,
                notes: Value(d['notes'] as String? ?? ''),
                subject: d['subject'] as String,
                topic: d['topic'] as String,
                subtopic: Value(d['subtopic'] as String?),
                language: d['language'] as String,
                tags: Value((d['tags'] as List<dynamic>? ?? const []).cast<String>()),
                sourceReference: Value(d['source_reference'] as String?),
                archivedAt: Value(_date(d['archived_at'])),
                createdAt: _date(d['created_at'])!,
                updatedAt: _date(d['updated_at'])!,
              ),
            );
      case SyncEntity.studyProfile:
        await _db
            .into(_db.studyProfiles)
            .insertOnConflictUpdate(
              StudyProfilesCompanion.insert(
                id: const Value(1),
                examCodes: Value((d['exam_codes'] as List<dynamic>? ?? const []).cast<String>()),
                targetExamDate: Value(d['target_exam_date'] as String?),
                dailyStudyMinutes: Value(d['daily_study_minutes'] as int?),
                reminderMinutes: Value(d['reminder_minutes'] as int?),
                onboardingCompletedAt: Value(_date(d['onboarding_completed_at'])),
                updatedAt: _date(d['updated_at'])!,
              ),
            );
      case SyncEntity.setting:
        await _setSetting(change.id, d['value'] as String);
      case SyncEntity.revisionCard:
        final conceptId = d['concept_id'] as String?;
        if (conceptId != null && !await _exists(_db.concepts, _db.concepts.id, conceptId)) {
          return false; // its concept was deleted here; that deletion is being synced
        }
        await _db
            .into(_db.revisionCards)
            .insertOnConflictUpdate(
              RevisionCardsCompanion.insert(
                id: change.id,
                kind: d['kind'] as String,
                conceptId: Value(conceptId),
                questionId: Value(d['question_id'] as String?),
                front: Value(d['front'] as String?),
                back: Value(d['back'] as String?),
                sourceFilename: Value(d['source_filename'] as String?),
                sourcePage: Value(d['source_page'] as int?),
                examCode: Value(d['exam_code'] as String?),
                subject: Value(d['subject'] as String?),
                topic: Value(d['topic'] as String?),
                reason: Value(d['reason'] as String? ?? 'added'),
                step: d['step'] as int,
                gapDays: d['gap_days'] as int,
                dueOn: d['due_on'] as String,
                reviewCount: Value(d['review_count'] as int? ?? 0),
                lapseCount: Value(d['lapse_count'] as int? ?? 0),
                lastReviewedAt: Value(_date(d['last_reviewed_at'])),
                createdAt: _date(d['created_at'])!,
                updatedAt: _date(d['updated_at'])!,
              ),
            );
      case SyncEntity.cardReview:
        final cardId = d['card_id'] as String;
        if (!await _exists(_db.revisionCards, _db.revisionCards.id, cardId)) return false;
        if (await _exists(_db.cardReviews, _db.cardReviews.syncId, change.id)) return false;
        await _db
            .into(_db.cardReviews)
            .insert(
              CardReviewsCompanion.insert(
                cardId: cardId,
                syncId: Value(change.id),
                reviewedAt: _date(d['reviewed_at'])!,
                rating: d['rating'] as String,
                dueBefore: d['due_before'] as String,
                dueAfter: d['due_after'] as String,
                gapDays: d['gap_days'] as int,
              ),
            );
      default:
        return false;
    }
    return true;
  }

  Future<void> _deleteLocal(String entity, String id) async {
    switch (entity) {
      case SyncEntity.concept:
        await (_db.delete(_db.concepts)..where((t) => t.id.equals(id))).go();
      case SyncEntity.studyProfile:
        await _db.delete(_db.studyProfiles).go();
      case SyncEntity.revisionCard:
        await (_db.delete(_db.revisionCards)..where((t) => t.id.equals(id))).go();
      case SyncEntity.cardReview:
        await (_db.delete(_db.cardReviews)..where((t) => t.syncId.equals(id))).go();
      case SyncEntity.setting:
        await (_db.delete(_db.appSettings)..where((t) => t.key.equals(id))).go();
    }
  }

  // --- helpers ------------------------------------------------------------------------

  Future<List<String>> _ids(TableInfo<Table, Object?> table, GeneratedColumn<String> column) =>
      (_db.selectOnly(table)..addColumns([column])).map((r) => r.read(column)!).get();

  Future<bool> _exists(
    TableInfo<Table, Object?> table,
    GeneratedColumn<String> column,
    String value,
  ) async =>
      (await (_db.selectOnly(table)
            ..addColumns([column])
            ..where(column.equals(value)))
          .getSingleOrNull()) !=
      null;

  Future<String?> _setting(String key) async => (await (_db.select(
    _db.appSettings,
  )..where((s) => s.key.equals(key))).getSingleOrNull())?.value;

  Future<void> _setSetting(String key, String value) => _db
      .into(_db.appSettings)
      .insertOnConflictUpdate(AppSettingsCompanion.insert(key: key, value: value));

  static (String, String) _split(String key) {
    final i = key.indexOf(':');
    return (key.substring(0, i), key.substring(i + 1));
  }

  static String? _iso(DateTime? d) => d?.toUtc().toIso8601String();

  static DateTime? _date(Object? value) =>
      value is String ? DateTime.tryParse(value)?.toUtc() : null;
}
