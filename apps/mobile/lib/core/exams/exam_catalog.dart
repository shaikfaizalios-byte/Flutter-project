import 'package:flutter/foundation.dart';

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

  Map<String, Object?> toJson() => {
    'code': code,
    'name': name,
    'short_name': shortName,
    'category': category,
    'featured': featured,
    'custom': custom,
  };
}

/// Shown before the catalog has been loaded from the server for the first time.
const builtInExams = <ExamOption>[
  ExamOption(
    code: 'SSC_CGL',
    shortName: 'SSC CGL',
    name: 'SSC Combined Graduate Level',
    category: 'Staff Selection',
    featured: true,
  ),
  ExamOption(
    code: 'SSC_CHSL',
    shortName: 'SSC CHSL',
    name: 'SSC Combined Higher Secondary Level',
    category: 'Staff Selection',
    featured: true,
  ),
];

/// Display name for [code] in [exams]; the code itself if unknown (e.g. not loaded yet).
String examShortNameIn(List<ExamOption> exams, String code) =>
    exams.where((e) => e.code == code).firstOrNull?.shortName ?? code;
