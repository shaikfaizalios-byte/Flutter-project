import 'package:drift/drift.dart';

import 'app_database.dart';

/// Names of synced record types (must match the server's sync entities).
abstract final class SyncEntity {
  static const concept = 'concept';
  static const studyProfile = 'study_profile';
  static const revisionCard = 'revision_card';
  static const cardReview = 'card_review';
  static const setting = 'setting';

  /// Fixed ids for singletons and settings.
  static const profileId = 'profile';
  static const revisionOffsetsId = 'revision_day_offsets';
}

/// Marks a record as changed on this device, so the next sync uploads its current state.
/// Call inside the same transaction as the change.
extension SyncOutboxWrites on AppDatabase {
  Future<void> markDirty(String entity, String id) => into(syncOutbox).insert(
    SyncOutboxCompanion.insert(entity: entity, entityId: id, changedAt: DateTime.now().toUtc()),
    onConflict: DoUpdate(
      (old) => SyncOutboxCompanion.custom(
        version: old.version + const Constant(1),
        changedAt: Variable(DateTime.now().toUtc()),
      ),
    ),
  );
}
