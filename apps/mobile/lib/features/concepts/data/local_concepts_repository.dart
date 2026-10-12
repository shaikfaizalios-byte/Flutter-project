import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../../core/database/app_database.dart';
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
  Stream<List<Concept>> watch({String query = '', bool includeArchived = false}) {
    final q = query.trim();
    final select = _db.select(_db.concepts)
      ..where((c) {
        Expression<bool> condition = const Constant(true);
        if (!includeArchived) condition = condition & c.archivedAt.isNull();
        if (q.isNotEmpty) {
          final pattern = '%${_escapeLike(q)}%';
          condition =
              condition &
              (c.title.like(pattern, escapeChar: r'\') |
                  c.notes.like(pattern, escapeChar: r'\') |
                  c.topic.like(pattern, escapeChar: r'\') |
                  c.subtopic.like(pattern, escapeChar: r'\'));
        }
        return condition;
      })
      ..orderBy([(c) => OrderingTerm.desc(c.updatedAt), (c) => OrderingTerm.asc(c.id)]);
    return select.watch().map((rows) => rows.map(_toDomain).toList(growable: false));
  }

  @override
  Future<Concept> create(ConceptDraft draft) async {
    final clean = draft.normalized();
    final errors = ConceptRules.validate(clean);
    if (errors.isNotEmpty) throw InvalidConceptException(errors);

    final now = _clock().toUtc();
    final row = await _db
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
    return _toDomain(row);
  }

  @override
  Future<void> setArchived(String id, {required bool archived}) async {
    final now = _clock().toUtc();
    final query = _db.update(_db.concepts)..where((c) => c.id.equals(id));
    if (archived) {
      // Keep the first archive timestamp if already archived.
      query.where((c) => c.archivedAt.isNull());
    }
    await query.write(
      ConceptsCompanion(archivedAt: Value(archived ? now : null), updatedAt: Value(now)),
    );
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
