import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'exam_data.g.dart';

/// What sets an exam apart. The values come from the server's exam data, never from code.
@immutable
class ExamProfile {
  const ExamProfile({
    required this.kind,
    required this.optionsPerQuestion,
    required this.repeatShare,
    required this.minPapers,
    required this.reliablePapers,
    required this.countingUnit,
  });

  factory ExamProfile.fromJson(Map<String, dynamic> json) => ExamProfile(
    kind: json['kind'] as String,
    optionsPerQuestion: json['options_per_question'] as int?,
    repeatShare: (json['repeat_share'] as num).toDouble(),
    minPapers: json['min_papers'] as int,
    reliablePapers: json['reliable_papers'] as int,
    countingUnit: json['counting_unit'] as String,
  );

  final String kind;

  /// Null when it differs from paper to paper.
  final int? optionsPerQuestion;
  final double repeatShare;
  final int minPapers;
  final int reliablePapers;
  final String countingUnit;

  Map<String, Object?> toJson() => {
    'kind': kind,
    'options_per_question': optionsPerQuestion,
    'repeat_share': repeatShare,
    'min_papers': minPapers,
    'reliable_papers': reliablePapers,
    'counting_unit': countingUnit,
  };
}

/// An exam the learner can prepare for: from the server's catalog, or one they created.
@immutable
class ExamOption {
  const ExamOption({
    required this.code,
    required this.shortName,
    String? name,
    this.category,
    this.featured = false,
    this.custom = false,
    this._profile,
  }) : name = name ?? shortName;

  factory ExamOption.fromJson(Map<String, dynamic> json) {
    final name = json['name'] as String;
    final short = json['short_name'] as String? ?? '';
    return ExamOption(
      code: json['code'] as String,
      name: name,
      shortName: short.isEmpty ? name : short,
      category: json['category'] as String?,
      featured: json['featured'] as bool? ?? false,
      custom: json['custom'] as bool? ?? false,
      profile: switch (json['profile']) {
        final Map<String, dynamic> profile => ExamProfile.fromJson(profile),
        _ => null, // cached before exams had profiles
      },
    );
  }

  /// Matches the backend `exams.code` (own exams: `MY_...`).
  final String code;

  /// Display name (proper noun; not translated).
  final String shortName;
  final String name;

  /// Catalog grouping, e.g. "Banking"; null for own exams.
  final String? category;
  final bool featured;

  /// Created by the learner (private to them).
  final bool custom;

  final ExamProfile? _profile;
  ExamProfile get profile => _profile ?? defaultExamProfile;

  Map<String, Object?> toJson() => {
    'code': code,
    'name': name,
    'short_name': shortName,
    'category': category,
    'featured': featured,
    'custom': custom,
    'profile': profile.toJson(),
  };
}

final Map<String, dynamic> _examData = jsonDecode(examDataJson) as Map<String, dynamic>;

/// What an exam uses until its own profile says otherwise.
final defaultExamProfile = ExamProfile.fromJson(_examData['defaults'] as Map<String, dynamic>);

/// Shown before the catalog has been loaded from the server for the first time.
final builtInExams = <ExamOption>[
  for (final exam in _examData['exams'] as List<dynamic>)
    ExamOption.fromJson(exam as Map<String, dynamic>),
];

/// Display name for [code] in [exams]; the code itself if unknown (e.g. not loaded yet).
String examShortNameIn(List<ExamOption> exams, String code) =>
    exams.where((e) => e.code == code).firstOrNull?.shortName ?? code;
