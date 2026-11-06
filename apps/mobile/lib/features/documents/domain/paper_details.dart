import 'package:flutter/foundation.dart';

/// What a reviewer records about a paper. Blank fields are cleared.
@immutable
class PaperDetails {
  const PaperDetails({required this.stage, required this.sessionLabel, required this.setCode});

  final String stage;
  final String sessionLabel;
  final String setCode;

  Map<String, Object?> toJson() {
    String? value(String text) => text.trim().isEmpty ? null : text.trim();
    return {
      'stage': value(stage),
      'session_label': value(sessionLabel),
      'set_code': value(setCode),
    };
  }
}

/// One of the learner's papers that looks like another set of this one. Only a suggestion.
@immutable
class OtherSet {
  const OtherSet({required this.documentId, required this.filename, required this.sharedShare});

  factory OtherSet.fromJson(Map<String, dynamic> json) => OtherSet(
    documentId: json['document_id'] as String,
    filename: json['filename'] as String,
    sharedShare: (json['shared_share'] as num).toDouble(),
  );

  final String documentId;
  final String filename;
  final double sharedShare;
}

/// What a separate answer key did.
@immutable
class AnswerKeyResult {
  const AnswerKeyResult({
    required this.applied,
    required this.agreed,
    required this.conflicts,
    required this.unmatched,
    required this.ambiguous,
    required this.withoutAnswer,
    required this.problems,
  });

  factory AnswerKeyResult.fromJson(Map<String, dynamic> json) => AnswerKeyResult(
    applied: json['applied'] as int,
    agreed: json['agreed'] as int,
    conflicts: json['conflicts'] as int,
    unmatched: (json['unmatched'] as List<dynamic>).cast<int>(),
    ambiguous: json['ambiguous'] as bool,
    withoutAnswer: json['without_answer'] as int,
    problems: (json['problems'] as List<dynamic>).cast<String>(),
  );

  final int applied;
  final int agreed;
  final int conflicts;
  final List<int> unmatched;
  final bool ambiguous;
  final int withoutAnswer;
  final List<String> problems;
}
