import 'package:flutter/foundation.dart';

/// A topic that applies to an exam: shared taxonomy (read-only) or the learner's own.
@immutable
class ExamTopic {
  const ExamTopic({
    required this.id,
    required this.subject,
    required this.name,
    required this.own,
    this.keywords = const [],
    this.completed = false,
  });

  factory ExamTopic.fromJson(Map<String, dynamic> json) => ExamTopic(
    id: json['id'] as String,
    subject: json['subject'] as String,
    name: json['name'] as String,
    own: json['own'] as bool,
    keywords: [for (final k in json['keywords'] as List<dynamic>) k as String],
    completed: json['completed'] as bool? ?? false,
  );

  final String id;
  final String subject;
  final String name;
  final bool own;
  final List<String> keywords;

  /// The learner marked this topic as revised.
  final bool completed;

  ExamTopic copyWith({bool? completed}) => ExamTopic(
    id: id,
    subject: subject,
    name: name,
    own: own,
    keywords: keywords,
    completed: completed ?? this.completed,
  );
}

/// Subjects and topics read from a syllabus PDF. Nothing is saved until the learner keeps
/// topics from it.
@immutable
class SyllabusDraft {
  const SyllabusDraft({
    required this.pages,
    required this.readBy,
    required this.unreadablePages,
    required this.topics,
    this.truncated = false,
  });

  factory SyllabusDraft.fromJson(Map<String, dynamic> json) => SyllabusDraft(
    pages: json['pages'] as int,
    readBy: json['read_by'] as String,
    unreadablePages: json['unreadable_pages'] as int,
    truncated: json['truncated'] as bool? ?? false,
    topics: [
      for (final s in json['subjects'] as List<dynamic>)
        for (final t in (s as Map<String, dynamic>)['topics'] as List<dynamic>)
          NewTopic(subject: s['name'] as String, name: t as String),
    ],
  );

  final int pages;

  /// "text" (the PDF's own text), "ocr" (read from page images), "mixed" or "none".
  final String readBy;

  /// Pages that couldn't be read reliably (scan quality).
  final int unreadablePages;
  final List<NewTopic> topics;

  /// The PDF listed more topics than one draft holds.
  final bool truncated;
}

/// A topic to create: typed by the learner, or kept from an AI draft.
@immutable
class NewTopic {
  const NewTopic({required this.subject, required this.name, this.keywords = const []});

  final String subject;
  final String name;
  final List<String> keywords;

  Map<String, Object> toJson(String examCode) => {
    'exam_code': examCode,
    'subject': subject,
    'name': name,
    'keywords': keywords,
  };
}

/// An AI-proposed topic list. Nothing is saved until the learner keeps topics from it.
@immutable
class TopicDraft {
  const TopicDraft({required this.model, required this.questionsConsidered, required this.topics});

  factory TopicDraft.fromJson(Map<String, dynamic> json) => TopicDraft(
    model: json['model'] as String,
    questionsConsidered: json['questions_considered'] as int,
    topics: [
      for (final s in json['subjects'] as List<dynamic>)
        for (final t in (s as Map<String, dynamic>)['topics'] as List<dynamic>)
          NewTopic(
            subject: s['name'] as String,
            name: (t as Map<String, dynamic>)['name'] as String,
            keywords: [for (final k in t['keywords'] as List<dynamic>) k as String],
          ),
    ],
  );

  final String model;
  final int questionsConsidered;
  final List<NewTopic> topics;
}
