import 'package:flutter/foundation.dart';

import 'concept.dart';

/// What the concept list shows. Text search is combined (AND) with the filters.
@immutable
class ConceptQuery {
  const ConceptQuery({
    this.text = '',
    this.examCode,
    this.subject,
    this.topic,
    this.archived = false,
  });

  final String text;
  final String? examCode;

  /// Case-insensitive exact match.
  final String? subject;

  /// Case-insensitive exact match.
  final String? topic;

  /// `false`: active concepts only. `true`: archived concepts only.
  final bool archived;

  bool get hasFilters => examCode != null || subject != null || topic != null || archived;

  ConceptQuery copyWith({
    String? text,
    String? Function()? examCode,
    String? Function()? subject,
    String? Function()? topic,
    bool? archived,
  }) => ConceptQuery(
    text: text ?? this.text,
    examCode: examCode != null ? examCode() : this.examCode,
    subject: subject != null ? subject() : this.subject,
    topic: topic != null ? topic() : this.topic,
    archived: archived ?? this.archived,
  );

  @override
  bool operator ==(Object other) =>
      other is ConceptQuery &&
      other.text == text &&
      other.examCode == examCode &&
      other.subject == subject &&
      other.topic == topic &&
      other.archived == archived;

  @override
  int get hashCode => Object.hash(text, examCode, subject, topic, archived);
}

/// Filter choices derived from the learner's own concepts.
@immutable
class ConceptFacets {
  const ConceptFacets({
    this.examCodes = const [],
    this.subjects = const [],
    this.topicsBySubject = const {},
  });

  final List<String> examCodes;

  /// Distinct subjects (case-insensitive), sorted, first spelling kept.
  final List<String> subjects;

  /// Lower-cased subject → distinct topics in that subject.
  final Map<String, List<String>> topicsBySubject;

  /// Topics for [subject], or all topics when [subject] is null.
  List<String> topicsFor(String? subject) {
    if (subject != null) return topicsBySubject[subject.toLowerCase()] ?? const [];
    final all = <String, String>{};
    for (final topics in topicsBySubject.values) {
      for (final t in topics) {
        all.putIfAbsent(t.toLowerCase(), () => t);
      }
    }
    return all.values.toList()..sort(_compareText);
  }
}

int _compareText(String a, String b) => a.toLowerCase().compareTo(b.toLowerCase());

/// Concept storage contract. The current implementation is local-only
/// (offline-first); a synchronising implementation can replace it later without
/// changing the presentation layer.
abstract interface class ConceptsRepository {
  /// Emits matching concepts, most recently updated first, and re-emits on change.
  Stream<List<Concept>> watch([ConceptQuery query = const ConceptQuery()]);

  /// Emits the concept, or null once it no longer exists.
  Stream<Concept?> watchById(String id);

  /// One-off read; null if the concept does not exist.
  Future<Concept?> getById(String id);

  /// Number of active (non-archived) concepts.
  Stream<int> watchActiveCount();

  /// Filter choices across all concepts (active and archived).
  Stream<ConceptFacets> watchFacets();

  /// Validates, normalises and stores a new concept. Throws [InvalidConceptException].
  Future<Concept> create(ConceptDraft draft);

  /// Replaces the editable fields. Throws [InvalidConceptException] or
  /// [ConceptNotFoundException].
  Future<Concept> update(String id, ConceptDraft draft);

  Future<void> setArchived(String id, {required bool archived});

  /// Permanently deletes the concept. Only call on an explicit user request.
  Future<void> delete(String id);
}

class ConceptNotFoundException implements Exception {
  const ConceptNotFoundException(this.id);

  final String id;

  @override
  String toString() => 'ConceptNotFoundException($id)';
}
