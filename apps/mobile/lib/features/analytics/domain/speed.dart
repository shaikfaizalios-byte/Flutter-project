import 'package:flutter/foundation.dart';

/// Seconds per question: from the exam's verified format, or the learner's own when it has none.
@immutable
class SpeedTarget {
  const SpeedTarget({
    required this.fromFormat,
    this.formatName,
    this.seconds,
    this.bySection = const {},
  });

  factory SpeedTarget.fromJson(Map<String, dynamic> json) => SpeedTarget(
    fromFormat: json['source'] == 'format',
    formatName: json['format_name'] as String?,
    seconds: (json['seconds'] as num?)?.toDouble(),
    bySection: {
      for (final MapEntry(:key, :value)
          in (json['by_section'] as Map<String, dynamic>? ?? const {}).entries)
        key: (value as num).toDouble(),
    },
  );

  final bool fromFormat;
  final String? formatName;
  final double? seconds;
  final Map<String, double> bySection;
}

/// Raw counts for one question type (model), from `/analytics/speed`.
@immutable
class TypeSpeed {
  const TypeSpeed({
    required this.patternId,
    required this.name,
    required this.answered,
    required this.correct,
    this.topic,
    this.subject,
    this.timedAnswered = 0,
    this.timeSpentMs = 0,
    this.slowCorrect = 0,
    this.targetSeconds,
  });

  factory TypeSpeed.fromJson(Map<String, dynamic> json) => TypeSpeed(
    patternId: json['pattern_id'] as String,
    name: json['name'] as String,
    topic: json['topic'] as String?,
    subject: json['subject'] as String?,
    answered: json['answered'] as int,
    correct: json['correct'] as int,
    timedAnswered: json['timed_answered'] as int? ?? 0,
    timeSpentMs: json['time_spent_ms'] as int? ?? 0,
    slowCorrect: json['slow_correct'] as int? ?? 0,
    targetSeconds: (json['target_seconds'] as num?)?.toDouble(),
  );

  final String patternId;
  final String name;
  final String? topic;
  final String? subject;
  final int answered;
  final int correct;
  final int timedAnswered;
  final int timeSpentMs;

  /// Right answers that took more than the slow factor times the target.
  final int slowCorrect;
  final double? targetSeconds;

  double? get accuracy => answered == 0 ? null : correct / answered;

  /// Average seconds per timed answer; null without any.
  double? get secondsPerAnswer => timedAnswered == 0 ? null : timeSpentMs / timedAnswered / 1000;
}

@immutable
class SpeedReport {
  const SpeedReport({required this.slowFactor, this.target, this.types = const []});

  factory SpeedReport.fromJson(Map<String, dynamic> json) => SpeedReport(
    target: json['target'] == null
        ? null
        : SpeedTarget.fromJson(json['target'] as Map<String, dynamic>),
    slowFactor: (json['slow_factor'] as num).toDouble(),
    types: [
      for (final t in json['types'] as List<dynamic>) TypeSpeed.fromJson(t as Map<String, dynamic>),
    ],
  );

  final SpeedTarget? target;
  final double slowFactor;
  final List<TypeSpeed> types;

  /// The timer for a drill of [type]: its own target, else the paper's; null without one.
  int? drillSeconds(TypeSpeed type) {
    final seconds = type.targetSeconds ?? target?.seconds;
    return seconds?.round().clamp(5, 600);
  }
}

/// Questions in one timed drill.
const drillQuestions = 10;
