import 'package:flutter/foundation.dart';

/// Published shifts per year.
@immutable
class RadarYear {
  const RadarYear(this.year, this.shifts);

  factory RadarYear.fromJson(Map<String, dynamic> json) =>
      RadarYear(json['year'] as int, json['shifts'] as int);

  final int year;
  final int shifts;
}

@immutable
class RadarCounts {
  const RadarCounts({required this.shifts, required this.questions, this.years = const []});

  factory RadarCounts.fromJson(Map<String, dynamic> json) => RadarCounts(
    shifts: json['shifts'] as int,
    questions: json['questions'] as int,
    years: [
      for (final y in json['years'] as List<dynamic>) RadarYear.fromJson(y as Map<String, dynamic>),
    ],
  );

  final int shifts;
  final int questions;
  final List<RadarYear> years;
}

@immutable
class RadarPattern {
  const RadarPattern({required this.patternId, required this.name, required this.counts});

  factory RadarPattern.fromJson(Map<String, dynamic> json) => RadarPattern(
    patternId: json['pattern_id'] as String,
    name: json['name'] as String,
    counts: RadarCounts.fromJson(json['counts'] as Map<String, dynamic>),
  );

  final String patternId;
  final String name;
  final RadarCounts counts;
}

@immutable
class RadarTopic {
  const RadarTopic({
    required this.topicId,
    required this.subject,
    required this.name,
    required this.counts,
    this.patterns = const [],
  });

  factory RadarTopic.fromJson(Map<String, dynamic> json) => RadarTopic(
    topicId: json['topic_id'] as String,
    subject: json['subject'] as String,
    name: json['name'] as String,
    counts: RadarCounts.fromJson(json['counts'] as Map<String, dynamic>),
    patterns: [
      for (final p in json['patterns'] as List<dynamic>)
        RadarPattern.fromJson(p as Map<String, dynamic>),
    ],
  );

  final String topicId;
  final String subject;
  final String name;
  final RadarCounts counts;
  final List<RadarPattern> patterns;
}

/// What the shared numbers rest on: shifts that at least [minAccounts] learners agreed on.
@immutable
class RadarBasis {
  const RadarBasis({
    required this.shifts,
    required this.minAccounts,
    this.years = const [],
    this.withheld = 0,
  });

  factory RadarBasis.fromJson(Map<String, dynamic> json) => RadarBasis(
    shifts: json['shifts'] as int,
    years: [for (final y in json['years'] as List<dynamic>) y as int],
    minAccounts: json['min_accounts'] as int,
    withheld: json['withheld'] as int,
  );

  final int shifts;
  final List<int> years;
  final int minAccounts;

  /// Counts not shown because the learners' numbers did not agree.
  final int withheld;
}

@immutable
class RadarReport {
  const RadarReport({required this.basis, this.topics = const []});

  factory RadarReport.fromJson(Map<String, dynamic> json) => RadarReport(
    basis: RadarBasis.fromJson(json['basis'] as Map<String, dynamic>),
    topics: [
      for (final t in json['topics'] as List<dynamic>)
        RadarTopic.fromJson(t as Map<String, dynamic>),
    ],
  );

  final RadarBasis basis;
  final List<RadarTopic> topics;
}

@immutable
class RadarSettings {
  const RadarSettings({
    required this.share,
    required this.eligiblePapers,
    required this.minAccounts,
  });

  factory RadarSettings.fromJson(Map<String, dynamic> json) => RadarSettings(
    share: json['share'] as bool,
    eligiblePapers: json['eligible_papers'] as int,
    minAccounts: json['min_accounts'] as int,
  );

  final bool share;

  /// This account's papers that can join (confirmed date and shift, classified questions).
  final int eligiblePapers;
  final int minAccounts;
}
