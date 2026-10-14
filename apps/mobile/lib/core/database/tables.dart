import 'dart:convert';

import 'package:drift/drift.dart';

/// Stores a list of strings as a JSON array in a TEXT column.
class StringListConverter extends TypeConverter<List<String>, String> {
  const StringListConverter();

  @override
  List<String> fromSql(String fromDb) => (jsonDecode(fromDb) as List<Object?>).cast<String>();

  @override
  String toSql(List<String> value) => jsonEncode(value);
}

/// Locally stored concepts. IDs are client-generated UUIDs so rows can later be
/// synchronised without remapping (see docs/database.md, "Sync rules").
@DataClassName('ConceptRow')
class Concepts extends Table {
  TextColumn get id => text()();
  TextColumn get examCode => text().withLength(min: 1, max: 32)();
  TextColumn get title => text().withLength(min: 1, max: 200)();
  TextColumn get notes => text().withDefault(const Constant(''))();
  TextColumn get subject => text().withLength(min: 1, max: 100)();
  TextColumn get topic => text().withLength(min: 1, max: 100)();
  TextColumn get subtopic => text().nullable()();
  TextColumn get language => text().withLength(min: 2, max: 8)();
  TextColumn get tags =>
      text().map(const StringListConverter()).withDefault(const Constant('[]'))();
  TextColumn get sourceReference => text().nullable()();
  DateTimeColumn get archivedAt => dateTime().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// Small key/value store for device-local settings (language, theme, ...).
@DataClassName('AppSettingRow')
class AppSettings extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column<Object>> get primaryKey => {key};
}

/// The learner's study setup from onboarding (single row, id = 1). Added in schema v2.
@DataClassName('StudyProfileRow')
class StudyProfiles extends Table {
  // Drift idiom: a column check refers to its own getter.
  // ignore: recursive_getters
  IntColumn get id => integer().check(id.equals(1))();

  /// Selected exam codes as a JSON array; empty means "not chosen yet".
  TextColumn get examCodes =>
      text().map(const StringListConverter()).withDefault(const Constant('[]'))();

  /// Calendar date `yyyy-MM-dd` (no time or timezone, so it never shifts).
  TextColumn get targetExamDate => text().nullable()();
  IntColumn get dailyStudyMinutes => integer().nullable()();

  /// Local wall-clock time as minutes after midnight (0–1439).
  IntColumn get reminderMinutes => integer().nullable()();
  DateTimeColumn get onboardingCompletedAt => dateTime().nullable()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// Practice/mock answers not yet confirmed by the server (offline queue). One row per
/// session question; a newer answer replaces the queued one. Added in schema v3.
@DataClassName('PendingAnswerRow')
class PendingAnswers extends Table {
  TextColumn get sessionId => text()();
  IntColumn get position => integer()();

  /// Null clears the answer.
  IntColumn get selectedPosition => integer().nullable()();

  /// Monotonic per device; the server ignores updates older than the one it has.
  IntColumn get clientSeq => integer()();
  IntColumn get timeSpentMs => integer().nullable()();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {sessionId, position};
}

/// Flashcards on the revision schedule. Added in schema v4.
///
/// Concept cards show the concept's current title and notes (joined, so edits show up);
/// question cards keep a snapshot of a verified source question so they can be revised
/// offline. AI-generated content is never stored here (Phase 9 adds it with a label).
@DataClassName('RevisionCardRow')
class RevisionCards extends Table {
  TextColumn get id => text()();

  /// `concept` or `question`.
  TextColumn get kind => text()();
  TextColumn get conceptId =>
      text().nullable().unique().references(Concepts, #id, onDelete: KeyAction.cascade)();

  /// Server question id (question cards).
  TextColumn get questionId => text().nullable().unique()();

  /// Question cards: stem with options (front) and answer with explanation (back).
  TextColumn get front => text().nullable()();
  TextColumn get back => text().nullable()();
  TextColumn get sourceFilename => text().nullable()();
  IntColumn get sourcePage => integer().nullable()();
  TextColumn get examCode => text().nullable()();
  TextColumn get subject => text().nullable()();
  TextColumn get topic => text().nullable()();

  /// Why the card exists: `added` (by the learner) or `incorrect_answer` (from practice).
  TextColumn get reason => text().withDefault(const Constant('added'))();
  IntColumn get step => integer()();
  IntColumn get gapDays => integer()();

  /// Calendar date `yyyy-MM-dd` (no timezone, so "due today" never shifts).
  TextColumn get dueOn => text()();
  IntColumn get reviewCount => integer().withDefault(const Constant(0))();
  IntColumn get lapseCount => integer().withDefault(const Constant(0))();
  DateTimeColumn get lastReviewedAt => dateTime().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// One row per flashcard review (recall rating and the resulting schedule), kept for
/// progress analytics in Phase 8. Added in schema v4.
@DataClassName('CardReviewRow')
@TableIndex(name: 'card_reviews_sync_id', columns: {#syncId}, unique: true)
class CardReviews extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get cardId => text().references(RevisionCards, #id, onDelete: KeyAction.cascade)();

  /// Stable id across devices (sync, schema v5); local [id]s are per device.
  TextColumn get syncId => text().nullable()();
  DateTimeColumn get reviewedAt => dateTime()();

  /// `again`, `hard`, `good` or `easy`.
  TextColumn get rating => text()();
  TextColumn get dueBefore => text()();
  TextColumn get dueAfter => text()();
  IntColumn get gapDays => integer()();
}

/// Records changed on this device that still need uploading (sync, schema v5). One row per
/// record: the upload reads the record's current state, so repeated edits coalesce. The
/// version grows on every change, so an edit made during an upload is not lost.
@DataClassName('SyncOutboxRow')
class SyncOutbox extends Table {
  /// `concept`, `study_profile`, `revision_card`, `card_review` or `setting`.
  TextColumn get entity => text()();
  TextColumn get entityId => text()();
  IntColumn get version => integer().withDefault(const Constant(1))();
  DateTimeColumn get changedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {entity, entityId};
}
