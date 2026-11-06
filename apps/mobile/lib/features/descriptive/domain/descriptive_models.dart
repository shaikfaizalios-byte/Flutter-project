import 'package:flutter/foundation.dart';

/// One rubric point with what the answer earned.
@immutable
class DescriptivePoint {
  const DescriptivePoint({
    required this.point,
    required this.marks,
    required this.awarded,
    required this.comment,
  });

  factory DescriptivePoint.fromJson(Map<String, dynamic> json) => DescriptivePoint(
    point: json['point'] as String,
    marks: (json['marks'] as num).toDouble(),
    awarded: (json['awarded'] as num).toDouble(),
    comment: json['comment'] as String,
  );

  final String point;
  final double marks;
  final double awarded;
  final String comment;
}

/// Estimated marks from AI feedback, never an official grade.
@immutable
class DescriptiveResult {
  const DescriptiveResult({
    required this.marks,
    required this.marksPossible,
    required this.points,
    required this.modelAnswer,
    this.low,
    this.high,
    this.missingPoints = const [],
    this.structure = '',
    this.relevance = '',
    this.length = '',
    this.wordCount = 0,
    this.answerText = '',
  });

  factory DescriptiveResult.fromJson(Map<String, dynamic> json) => DescriptiveResult(
    marks: (json['marks'] as num).toDouble(),
    marksPossible: (json['marks_possible'] as num).toDouble(),
    low: (json['low'] as num?)?.toDouble(),
    high: (json['high'] as num?)?.toDouble(),
    points: [
      for (final p in json['points'] as List<dynamic>)
        DescriptivePoint.fromJson(p as Map<String, dynamic>),
    ],
    missingPoints: (json['missing_points'] as List<dynamic>).cast<String>(),
    structure: json['structure'] as String,
    relevance: json['relevance'] as String,
    length: json['length'] as String,
    wordCount: json['word_count'] as int,
    answerText: json['answer_text'] as String,
    modelAnswer: json['model_answer'] as String,
  );

  final double marks;
  final double marksPossible;

  /// Set only when the markings disagreed.
  final double? low;
  final double? high;
  final List<DescriptivePoint> points;
  final List<String> missingPoints;
  final String structure;
  final String relevance;
  final String length;
  final int wordCount;
  final String answerText;
  final String modelAnswer;
}

/// One level: planned, then [ready] with its question, then marked.
@immutable
class DescriptiveStep {
  const DescriptiveStep({
    required this.step,
    required this.level,
    required this.marks,
    required this.wordLimit,
    required this.ready,
    this.stem,
    this.result,
  });

  factory DescriptiveStep.fromJson(Map<String, dynamic> json) => DescriptiveStep(
    step: json['step'] as int,
    level: json['level'] as String,
    marks: (json['marks'] as num).toDouble(),
    wordLimit: json['word_limit'] as int,
    ready: json['ready'] as bool,
    stem: json['stem'] as String?,
    result: json['result'] == null
        ? null
        : DescriptiveResult.fromJson(json['result'] as Map<String, dynamic>),
  );

  final int step;
  final String level;
  final double marks;

  /// PrepLoop's suggested length, not an exam rule.
  final int wordLimit;
  final bool ready;
  final String? stem;
  final DescriptiveResult? result;
}

@immutable
class DescriptiveSession {
  const DescriptiveSession({required this.sessionId, required this.steps});

  factory DescriptiveSession.fromJson(Map<String, dynamic> json) => DescriptiveSession(
    sessionId: json['session_id'] as String,
    steps: [
      for (final s in json['steps'] as List<dynamic>)
        DescriptiveStep.fromJson(s as Map<String, dynamic>),
    ],
  );

  final String sessionId;
  final List<DescriptiveStep> steps;

  DescriptiveSession withStep(DescriptiveStep updated) => DescriptiveSession(
    sessionId: sessionId,
    steps: [for (final s in steps) s.step == updated.step ? updated : s],
  );

  /// (marks, possible) of the marked steps.
  (double, double) get totals {
    var marks = 0.0;
    var possible = 0.0;
    for (final step in steps) {
      final result = step.result;
      if (result == null) continue;
      marks += result.marks;
      possible += result.marksPossible;
    }
    return (marks, possible);
  }
}

@immutable
class DescriptiveTopic {
  const DescriptiveTopic({required this.topicId, required this.name, required this.subject});

  factory DescriptiveTopic.fromJson(Map<String, dynamic> json) => DescriptiveTopic(
    topicId: json['topic_id'] as String,
    name: json['name'] as String,
    subject: json['subject'] as String,
  );

  final String topicId;
  final String name;
  final String subject;
}

@immutable
class DescriptiveOverview {
  const DescriptiveOverview({this.topics = const [], this.available = false});

  factory DescriptiveOverview.fromJson(Map<String, dynamic> json) => DescriptiveOverview(
    topics: [
      for (final t in json['topics'] as List<dynamic>)
        DescriptiveTopic.fromJson(t as Map<String, dynamic>),
    ],
    available: json['available'] as bool,
  );

  final List<DescriptiveTopic> topics;

  /// False for an exam with no written paper.
  final bool available;
}

/// What was read from a photo, for the learner to correct.
@immutable
class PhotoReading {
  const PhotoReading({required this.text, required this.unclear});

  factory PhotoReading.fromJson(Map<String, dynamic> json) =>
      PhotoReading(text: json['text'] as String, unclear: json['unclear'] as bool);

  final String text;
  final bool unclear;
}
