import 'package:flutter/foundation.dart';

/// A node of a syllabus tree, at any depth.
@immutable
class SyllabusNode {
  const SyllabusNode({required this.name, this.levelLabel, this.children = const []});

  factory SyllabusNode.fromJson(Map<String, dynamic> json) => SyllabusNode(
    name: json['name'] as String,
    levelLabel: json['level_label'] as String?,
    children: [
      for (final c in json['children'] as List<dynamic>)
        SyllabusNode.fromJson(c as Map<String, dynamic>),
    ],
  );

  final String name;
  final String? levelLabel;
  final List<SyllabusNode> children;

  Map<String, Object?> toJson() => {
    'name': name,
    if (levelLabel != null) 'level_label': levelLabel,
    if (children.isNotEmpty) 'children': [for (final c in children) c.toJson()],
  };
}

/// One version of an exam's syllabus. A null [effectiveYear] means no year was recorded.
@immutable
class SyllabusVersion {
  const SyllabusVersion({
    required this.id,
    required this.name,
    required this.own,
    required this.inForce,
    required this.tree,
    this.effectiveYear,
    this.sourceTitle,
  });

  factory SyllabusVersion.fromJson(Map<String, dynamic> json) => SyllabusVersion(
    id: json['id'] as String,
    name: json['name'] as String,
    own: json['own'] as bool,
    inForce: json['in_force'] as bool,
    effectiveYear: json['effective_year'] as int?,
    sourceTitle: json['source_title'] as String?,
    tree: [
      for (final n in json['tree'] as List<dynamic>)
        SyllabusNode.fromJson(n as Map<String, dynamic>),
    ],
  );

  final String id;
  final String name;
  final bool own;
  final bool inForce;
  final int? effectiveYear;
  final String? sourceTitle;
  final List<SyllabusNode> tree;
}

/// Answers on one canonical topic, per exam and all together.
@immutable
class CanonicalStats {
  const CanonicalStats({
    required this.name,
    required this.answered,
    required this.correct,
    required this.exams,
  });

  factory CanonicalStats.fromJson(Map<String, dynamic> json) => CanonicalStats(
    name: json['name'] as String,
    answered: json['answered'] as int,
    correct: json['correct'] as int,
    exams: [
      for (final e in json['exams'] as List<dynamic>)
        (
          code: (e as Map<String, dynamic>)['exam_code'] as String,
          answered: e['answered'] as int,
          correct: e['correct'] as int,
        ),
    ],
  );

  final String name;
  final int answered;
  final int correct;
  final List<({String code, int answered, int correct})> exams;
}

class _Building {
  _Building(this.name);

  final String name;
  final children = <_Building>[];

  SyllabusNode build() => SyllabusNode(name: name, children: [for (final c in children) c.build()]);
}

/// Reads an outline: one item per line, each [indent] spaces deeper than the one above it
/// puts it underneath. A jump of several levels counts as one.
List<SyllabusNode> parseOutline(String text, {int indent = 2}) {
  final roots = <_Building>[];
  final path = <({int level, _Building node})>[];
  for (final line in text.split('\n')) {
    final name = line.trim();
    if (name.isEmpty) continue;
    final level = (line.length - line.trimLeft().length) ~/ indent;
    while (path.isNotEmpty && path.last.level >= level) {
      path.removeLast();
    }
    final node = _Building(name);
    (path.isEmpty ? roots : path.last.node.children).add(node);
    path.add((level: level, node: node));
  }
  return [for (final r in roots) r.build()];
}
