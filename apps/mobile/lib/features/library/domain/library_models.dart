import 'package:flutter/foundation.dart';

/// What the learner is looking for in the library. A record, so equal searches share a result.
typedef LibraryQuery = ({
  String exam,
  String text,
  String? unit,
  String? topicId,
  String? patternId,
  String? format,
  int? year,
  String? difficulty,
});

@immutable
class LibraryHit {
  const LibraryHit({
    required this.questionId,
    required this.stem,
    required this.format,
    required this.source,
    required this.difficulty,
    required this.pictured,
    this.year,
    this.subject,
    this.topic,
    this.percentRight,
  });

  factory LibraryHit.fromJson(Map<String, dynamic> json) => LibraryHit(
    questionId: json['question_id'] as String,
    stem: json['stem'] as String,
    format: json['format'] as String,
    source: json['source_type'] as String,
    difficulty: json['difficulty'] as String,
    pictured: json['pictured'] as bool,
    year: json['exam_year'] as int?,
    subject: json['subject'] as String?,
    topic: json['topic'] as String?,
    percentRight: json['percent_right'] as int?,
  );

  final String questionId;
  final String stem;
  final String format;

  /// `official_pyq`, `original_expert` or `original_ai_verified`.
  final String source;
  final String difficulty;

  /// Printed as a picture: the question has to be opened to be seen.
  final bool pictured;
  final int? year;
  final String? subject;
  final String? topic;

  /// From real attempts only; null until there are enough.
  final int? percentRight;
}

@immutable
class LibraryPage {
  const LibraryPage({required this.items, required this.total});

  factory LibraryPage.fromJson(Map<String, dynamic> json) => LibraryPage(
    items: [
      for (final item in json['items'] as List<dynamic>)
        LibraryHit.fromJson(item as Map<String, dynamic>),
    ],
    total: json['total'] as int,
  );

  final List<LibraryHit> items;
  final int total;
}

/// A chapter of the library that can be saved for offline practice.
@immutable
class LibraryPack {
  const LibraryPack({
    required this.key,
    required this.name,
    required this.subject,
    required this.questions,
    required this.seq,
  });

  factory LibraryPack.fromJson(Map<String, dynamic> json) => LibraryPack(
    key: json['key'] as String,
    name: json['name'] as String,
    subject: json['subject'] as String,
    questions: json['questions'] as int,
    seq: json['seq'] as int,
  );

  final String key;
  final String name;
  final String subject;
  final int questions;

  /// The newest change. A device holding this has nothing to fetch.
  final int seq;
}

enum PackState { notSaved, saved, outdated }

/// Whether a chapter needs fetching. [savedSeq] is what the device holds, null if nothing.
PackState packState(LibraryPack pack, int? savedSeq) {
  if (savedSeq == null) return PackState.notSaved;
  return pack.seq > savedSeq ? PackState.outdated : PackState.saved;
}
