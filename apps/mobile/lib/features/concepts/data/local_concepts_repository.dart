import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/sync_outbox.dart';
import '../domain/concept.dart';
import '../domain/concepts_repository.dart';

/// Offline-first concept storage backed by the on-device database.
class LocalConceptsRepository implements ConceptsRepository {
  LocalConceptsRepository(this._db, {DateTime Function()? clock, Uuid? uuid})
    : _clock = clock ?? DateTime.now,
      _uuid = uuid ?? const Uuid();

  final AppDatabase _db;
  final DateTime Function() _clock;
  final Uuid _uuid;

  @override
  Stream<List<Concept>> watch([ConceptQuery query = const ConceptQuery()]) {
    final select = _db.select(_db.concepts)
      ..where((c) => _matches(c, query))
      ..orderBy([(c) => OrderingTerm.desc(c.updatedAt), (c) => OrderingTerm.asc(c.id)]);
    return select.watch().map((rows) => rows.map(_toDomain).toList(growable: false));
  }

  @override
  Stream<Concept?> watchById(String id) => (_db.select(
    _db.concepts,
  )..where((c) => c.id.equals(id))).watchSingleOrNull().map((r) => r == null ? null : _toDomain(r));

  @override
  Future<Concept?> getById(String id) async {
    final row = await (_db.select(_db.concepts)..where((c) => c.id.equals(id))).getSingleOrNull();
    return row == null ? null : _toDomain(row);
  }

  @override
  Stream<int> watchActiveCount() {
    final count = _db.concepts.id.count();
    final query = _db.selectOnly(_db.concepts)
      ..addColumns([count])
      ..where(_db.concepts.archivedAt.isNull());
    return query.watchSingle().map((row) => row.read(count) ?? 0);
  }

  @override
  Stream<ConceptFacets> watchFacets({String? examCode}) {
    final c = _db.concepts;
    final query = _db.selectOnly(c, distinct: true)..addColumns([c.examCode, c.subject, c.topic]);
    if (examCode != null) query.where(c.examCode.equals(examCode));
    return query.watch().map((rows) {
      final exams = <String>{};
      final subjects = <String, String>{};
      final topics = <String, Map<String, String>>{};
      for (final row in rows) {
        final subject = row.read(c.subject)!;
        final topic = row.read(c.topic)!;
        exams.add(row.read(c.examCode)!);
        subjects.putIfAbsent(subject.toLowerCase(), () => subject);
        topics
            .putIfAbsent(subject.toLowerCase(), () => {})
            .putIfAbsent(topic.toLowerCase(), () => topic);
      }
      int byText(String a, String b) => a.toLowerCase().compareTo(b.toLowerCase());
      return ConceptFacets(
        examCodes: exams.toList()..sort(),
        subjects: subjects.values.toList()..sort(byText),
        topicsBySubject: {
          for (final entry in topics.entries) entry.key: entry.value.values.toList()..sort(byText),
        },
      );
    });
  }

  @override
  Future<Concept> create(ConceptDraft draft) async {
    final clean = _validated(draft);
    final now = _clock().toUtc();
    final row = await _db.transaction(() async {
      final inserted = await _db
          .into(_db.concepts)
          .insertReturning(
            ConceptsCompanion.insert(
              id: _uuid.v4(),
              examCode: clean.examCode,
              title: clean.title,
              notes: Value(clean.notes),
              subject: clean.subject,
              topic: clean.topic,
              subtopic: Value(clean.subtopic),
              language: clean.language.code,
              tags: Value(clean.tags),
              sourceReference: Value(clean.sourceReference),
              createdAt: now,
              updatedAt: now,
            ),
          );
      await _db.markDirty(SyncEntity.concept, inserted.id);
      return inserted;
    });
    return _toDomain(row);
  }

  @override
  Future<Concept> update(String id, ConceptDraft draft) async {
    var clean = _validated(draft);
    final rows = await _db.transaction(() async {
      // A concept made from an AI lesson stays labelled as AI, whatever its tags are edited to.
      final before = await (_db.select(
        _db.concepts,
      )..where((c) => c.id.equals(id))).getSingleOrNull();
      if (before != null &&
          before.tags.contains(aiGeneratedTag) &&
          !clean.tags.contains(aiGeneratedTag)) {
        clean = clean.withTags([...clean.tags, aiGeneratedTag]);
      }
      final updated = await (_db.update(_db.concepts)..where((c) => c.id.equals(id)))
          .writeReturning(
            ConceptsCompanion(
              examCode: Value(clean.examCode),
              title: Value(clean.title),
              notes: Value(clean.notes),
              subject: Value(clean.subject),
              topic: Value(clean.topic),
              subtopic: Value(clean.subtopic),
              language: Value(clean.language.code),
              tags: Value(clean.tags),
              sourceReference: Value(clean.sourceReference),
              updatedAt: Value(_clock().toUtc()),
            ),
          );
      if (updated.isNotEmpty) await _db.markDirty(SyncEntity.concept, id);
      return updated;
    });
    if (rows.isEmpty) throw ConceptNotFoundException(id);
    return _toDomain(rows.single);
  }

  @override
  Future<void> setArchived(String id, {required bool archived}) async {
    final now = _clock().toUtc();
    final query = _db.update(_db.concepts)..where((c) => c.id.equals(id));
    if (archived) {
      // Keep the first archive timestamp if already archived.
      query.where((c) => c.archivedAt.isNull());
    }
    await _db.transaction(() async {
      final changed = await query.write(
        ConceptsCompanion(archivedAt: Value(archived ? now : null), updatedAt: Value(now)),
      );
      if (changed > 0) await _db.markDirty(SyncEntity.concept, id);
    });
  }

  @override
  Future<void> delete(String id) => _db.transaction(() async {
    // Its revision card is deleted with it (cascade); the deletion must sync too.
    final cards =
        await (_db.selectOnly(_db.revisionCards)
              ..addColumns([_db.revisionCards.id])
              ..where(_db.revisionCards.conceptId.equals(id)))
            .map((r) => r.read(_db.revisionCards.id)!)
            .get();
    final deleted = await (_db.delete(_db.concepts)..where((c) => c.id.equals(id))).go();
    if (deleted == 0) return;
    await _db.markDirty(SyncEntity.concept, id);
    for (final card in cards) {
      await _db.markDirty(SyncEntity.revisionCard, card);
    }
  });

  static ConceptDraft _validated(ConceptDraft draft) {
    final clean = draft.normalized();
    final errors = ConceptRules.validate(clean);
    if (errors.isNotEmpty) throw InvalidConceptException(errors);
    return clean;
  }

  static Expression<bool> _matches($ConceptsTable c, ConceptQuery query) {
    Expression<bool> condition = query.archived ? c.archivedAt.isNotNull() : c.archivedAt.isNull();
    if (query.examCode case final exam?) condition &= c.examCode.equals(exam);
    if (query.subject case final subject?) {
      condition &= c.subject.lower().equals(subject.toLowerCase());
    }
    if (query.topic case final topic?) condition &= c.topic.lower().equals(topic.toLowerCase());
    final text = query.text.trim();
    if (text.isNotEmpty) {
      final pattern = '%${_escapeLike(text)}%';
      condition &=
          c.title.like(pattern, escapeChar: r'\') |
          c.notes.like(pattern, escapeChar: r'\') |
          c.topic.like(pattern, escapeChar: r'\') |
          c.subtopic.like(pattern, escapeChar: r'\');
    }
    return condition;
  }

  static String _escapeLike(String value) =>
      value.replaceAll(r'\', r'\\').replaceAll('%', r'\%').replaceAll('_', r'\_');

  static Concept _toDomain(ConceptRow row) => Concept(
    id: row.id,
    examCode: row.examCode,
    title: row.title,
    notes: row.notes,
    subject: row.subject,
    topic: row.topic,
    subtopic: row.subtopic,
    language: ContentLanguage.fromCode(row.language),
    tags: row.tags,
    sourceReference: row.sourceReference,
    archivedAt: row.archivedAt,
    createdAt: row.createdAt,
    updatedAt: row.updatedAt,
  );
}
