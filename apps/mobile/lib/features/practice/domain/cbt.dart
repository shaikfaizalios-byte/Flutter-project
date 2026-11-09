import 'package:flutter/foundation.dart';

import 'practice_models.dart';

/// A computer-based mock's rules, read from the official instructions and kept with the attempt.
@immutable
class CbtRules {
  const CbtRules({required this.reference, this.basis});

  factory CbtRules.fromJson(Map<String, dynamic> json) =>
      CbtRules(reference: json['reference'] as String, basis: json['basis'] as String?);

  final String reference;

  /// Says so when the rules are another exam's, used for practice.
  final String? basis;
}

/// The palette's five states, as the official instructions list them.
enum CbtStatus { notVisited, notAnswered, answered, marked, answeredMarked }

CbtStatus cbtStatus(SessionItemView item, {bool current = false}) {
  if (item.marked) return item.answered ? CbtStatus.answeredMarked : CbtStatus.marked;
  if (item.answered) return CbtStatus.answered;
  return item.visited || current ? CbtStatus.notAnswered : CbtStatus.notVisited;
}

/// Where each section starts, in paper order.
List<({String name, int first})> cbtSections(List<SessionItemView> items) {
  final found = <({String name, int first})>[];
  for (final (index, item) in items.indexed) {
    final name = item.section ?? '';
    if (found.isEmpty || found.last.name != name) found.add((name: name, first: index));
  }
  return found;
}

/// How many questions of a section are in each state.
Map<CbtStatus, int> cbtCounts(Iterable<SessionItemView> items, int? currentPosition) {
  final counts = {for (final status in CbtStatus.values) status: 0};
  for (final item in items) {
    final status = cbtStatus(item, current: item.position == currentPosition);
    counts[status] = counts[status]! + 1;
  }
  return counts;
}

/// An answer on the screen, not saved until the learner says so.
@immutable
class CbtDraft {
  const CbtDraft({this.selected, this.typed, this.response});

  factory CbtDraft.of(SessionItemView item) =>
      CbtDraft(selected: item.selectedPosition, typed: item.typedAnswer, response: item.response);

  final int? selected;
  final String? typed;
  final Map<String, dynamic>? response;
}

@immutable
class QuestionAnalysis {
  const QuestionAnalysis({
    required this.position,
    required this.status,
    required this.marks,
    this.section,
    this.topic,
    this.timeMs,
    this.marked = false,
  });

  factory QuestionAnalysis.fromJson(Map<String, dynamic> json) => QuestionAnalysis(
    position: json['position'] as int,
    status: json['status'] as String,
    marks: (json['marks'] as num).toDouble(),
    section: json['section'] as String?,
    topic: json['topic'] as String?,
    timeMs: json['time_ms'] as int?,
    marked: json['marked'] as bool? ?? false,
  );

  final int position;

  /// `correct`, `wrong`, `unattempted` or `dropped`.
  final String status;
  final double marks;
  final String? section;
  final String? topic;
  final int? timeMs;
  final bool marked;
}

@immutable
class ChapterAccuracy {
  const ChapterAccuracy({
    required this.subject,
    required this.name,
    required this.correct,
    required this.wrong,
    required this.unattempted,
    required this.timeMs,
  });

  factory ChapterAccuracy.fromJson(Map<String, dynamic> json) => ChapterAccuracy(
    subject: json['subject'] as String,
    name: json['name'] as String,
    correct: json['correct'] as int,
    wrong: json['wrong'] as int,
    unattempted: json['unattempted'] as int,
    timeMs: json['time_ms'] as int,
  );

  final String subject;
  final String name;
  final int correct;
  final int wrong;
  final int unattempted;
  final int timeMs;

  /// Right answers among those attempted, as a whole percent. Null when none was.
  int? get accuracy {
    final attempted = correct + wrong;
    return attempted == 0 ? null : (correct * 100 / attempted).round();
  }
}

@immutable
class MockHistoryRow {
  const MockHistoryRow({
    required this.score,
    required this.maxScore,
    required this.current,
    this.submittedAt,
  });

  factory MockHistoryRow.fromJson(Map<String, dynamic> json) => MockHistoryRow(
    score: (json['score'] as num).toDouble(),
    maxScore: (json['max_score'] as num).toDouble(),
    current: json['current'] as bool,
    submittedAt: json['submitted_at'] == null
        ? null
        : DateTime.parse(json['submitted_at'] as String),
  );

  final double score;
  final double maxScore;
  final bool current;
  final DateTime? submittedAt;
}

/// After a mock. A percentile comes only from real attempts; there are no ranks.
@immutable
class MockAnalysis {
  const MockAnalysis({
    this.questions = const [],
    this.chapters = const [],
    this.history = const [],
    this.percent,
    this.accounts,
  });

  factory MockAnalysis.fromJson(Map<String, dynamic> json) {
    final percentile = json['percentile'] as Map<String, dynamic>?;
    return MockAnalysis(
      questions: [
        for (final q in json['questions'] as List<dynamic>)
          QuestionAnalysis.fromJson(q as Map<String, dynamic>),
      ],
      chapters: [
        for (final c in json['chapters'] as List<dynamic>)
          ChapterAccuracy.fromJson(c as Map<String, dynamic>),
      ],
      history: [
        for (final h in json['history'] as List<dynamic>)
          MockHistoryRow.fromJson(h as Map<String, dynamic>),
      ],
      percent: percentile?['percent'] as int?,
      accounts: percentile?['accounts'] as int?,
    );
  }

  final List<QuestionAnalysis> questions;
  final List<ChapterAccuracy> chapters;
  final List<MockHistoryRow> history;
  final int? percent;
  final int? accounts;
}
