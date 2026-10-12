import 'package:flutter/foundation.dart';

enum ContentLanguage {
  english('en'),
  hindi('hi');

  const ContentLanguage(this.code);

  final String code;

  static ContentLanguage fromCode(String code) =>
      values.firstWhere((l) => l.code == code, orElse: () => ContentLanguage.english);
}

@immutable
class Concept {
  const Concept({
    required this.id,
    required this.examCode,
    required this.title,
    required this.notes,
    required this.subject,
    required this.topic,
    required this.subtopic,
    required this.language,
    required this.tags,
    required this.sourceReference,
    required this.archivedAt,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String examCode;
  final String title;
  final String notes;
  final String subject;
  final String topic;
  final String? subtopic;
  final ContentLanguage language;
  final List<String> tags;
  final String? sourceReference;
  final DateTime? archivedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool get isArchived => archivedAt != null;
}

/// User input for a new concept. Call [normalized] before saving.
@immutable
class ConceptDraft {
  const ConceptDraft({
    required this.examCode,
    required this.title,
    required this.subject,
    required this.topic,
    required this.language,
    this.notes = '',
    this.subtopic,
    this.tags = const [],
    this.sourceReference,
  });

  final String examCode;
  final String title;
  final String notes;
  final String subject;
  final String topic;
  final String? subtopic;
  final ContentLanguage language;
  final List<String> tags;
  final String? sourceReference;

  /// Trims text, turns blank optionals into null, lower-cases and de-duplicates tags.
  /// Mirrors the backend's normalisation so local and server data agree.
  ConceptDraft normalized() {
    String? blankToNull(String? v) => (v == null || v.trim().isEmpty) ? null : v.trim();
    return ConceptDraft(
      examCode: examCode,
      title: title.trim(),
      notes: notes,
      subject: subject.trim(),
      topic: topic.trim(),
      subtopic: blankToNull(subtopic),
      language: language,
      tags: normalizeTags(tags),
      sourceReference: blankToNull(sourceReference),
    );
  }
}

/// Trims, lower-cases and de-duplicates tags, dropping empty ones (order kept).
List<String> normalizeTags(Iterable<String> tags) {
  final seen = <String>{};
  return [
    for (final tag in tags.map((t) => t.trim().toLowerCase()))
      if (tag.isNotEmpty && seen.add(tag)) tag,
  ];
}

enum FieldError { required, tooLong, tooMany }

/// Validation rules shared by the form and the repository (same limits as the API).
abstract final class ConceptRules {
  static const titleMax = 200;
  static const labelMax = 100;
  static const tagMax = 50;
  static const tagsMax = 20;
  static const sourceReferenceMax = 500;
  static const notesMax = 20000;

  static FieldError? requiredText(String? value, int max) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return FieldError.required;
    if (v.length > max) return FieldError.tooLong;
    return null;
  }

  static FieldError? optionalText(String? value, int max) =>
      (value?.trim().length ?? 0) > max ? FieldError.tooLong : null;

  static FieldError? tags(List<String> tags) {
    if (tags.length > tagsMax) return FieldError.tooMany;
    if (tags.any((t) => t.length > tagMax)) return FieldError.tooLong;
    return null;
  }

  /// All errors for a draft, keyed by field name. Empty when valid.
  static Map<String, FieldError> validate(ConceptDraft d) => {
    'title': ?requiredText(d.title, titleMax),
    'subject': ?requiredText(d.subject, labelMax),
    'topic': ?requiredText(d.topic, labelMax),
    'subtopic': ?optionalText(d.subtopic, labelMax),
    'sourceReference': ?optionalText(d.sourceReference, sourceReferenceMax),
    if (d.notes.length > notesMax) 'notes': FieldError.tooLong,
    'tags': ?tags(d.tags),
  };
}

class InvalidConceptException implements Exception {
  const InvalidConceptException(this.errors);

  final Map<String, FieldError> errors;

  @override
  String toString() => 'InvalidConceptException($errors)';
}
