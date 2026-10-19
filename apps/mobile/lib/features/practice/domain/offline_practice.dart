import 'dart:math';

import 'package:flutter/foundation.dart';

import '../../question_bank/domain/question.dart';
import 'practice_models.dart';

/// Offline practice: sessions built on the device from the saved offline pack, marked on the
/// device for instant feedback, and uploaded later. The server checks every answer again on
/// upload, so device marking is only ever a preview. Mock tests are never offline (their
/// timer must come from the server).
abstract final class OfflineRules {
  /// Questions saved on the device (newest first on the server).
  static const packSize = 500;
}

/// Same rule as the server (`app/domain/typed_answers.py`): two numbers match by value
/// (2.5 = 2.50, never rounded; "1,000" = 1000); anything else must match ignoring spaces and
/// case.
bool typedAnswerMatches(String expected, String given) {
  final a = _number(expected);
  final b = _number(given);
  if (a != null && b != null) return a == b;
  return _flat(expected) == _flat(given);
}

String _flat(String value) =>
    value.replaceAll('−', '-').replaceAll(RegExp(r'\s'), '').toLowerCase();

final _numberPattern = RegExp(r'^[+-]?(?:\d+(?:\.\d*)?|\.\d+)$');
final _groupedPattern = RegExp(r'^[+-]?\d{1,3}(?:,\d{3})+(?:\.\d+)?$');

/// A canonical decimal string ("-0012.500" -> "-12.5"), or null when not a number.
String? _number(String value) {
  var text = value.replaceAll('−', '-').replaceAll(RegExp(r'\s'), '');
  if (_groupedPattern.hasMatch(text)) text = text.replaceAll(',', '');
  if (!_numberPattern.hasMatch(text)) return null;
  var negative = false;
  if (text.startsWith('+') || text.startsWith('-')) {
    negative = text.startsWith('-');
    text = text.substring(1);
  }
  final parts = text.split('.');
  final whole = parts[0].replaceFirst(RegExp(r'^0+'), '');
  final fraction = parts.length > 1 ? parts[1].replaceFirst(RegExp(r'0+$'), '') : '';
  if (whole.isEmpty && fraction.isEmpty) return '0';
  final integer = whole.isEmpty ? '0' : whole;
  final body = fraction.isEmpty ? integer : '$integer.$fraction';
  return negative && body != '0' ? '-$body' : body;
}

/// One saved question (the server's offline-pack JSON, answer included).
@immutable
class OfflineQuestion {
  const OfflineQuestion(this.json);

  final Map<String, dynamic> json;

  String get id => json['id'] as String;
  String get examCode => json['exam_code'] as String;
  String? get subject => json['subject'] as String?;
  String? get topicId => json['topic_id'] as String?;
  String? get patternId => json['pattern_id'] as String?;
  bool get isTyped => json['answer_type'] == 'typed';
  int? get correctPosition => json['correct_position'] as int?;
  String? get typedAnswer => json['typed_answer'] as String?;

  bool matches(PracticeRequest request) =>
      (request.examCode == null || examCode == request.examCode) &&
      (request.subject == null || subject == request.subject) &&
      (request.topicId == null || topicId == request.topicId) &&
      (request.patternId == null || patternId == request.patternId) &&
      (request.includeShared || json['shared'] != true);
}

/// Picks up to `request.count` saved questions for [request], at random.
List<OfflineQuestion> pickOffline(
  Iterable<OfflineQuestion> saved,
  PracticeRequest request, {
  Random? random,
}) {
  final pool = saved.where((q) => q.matches(request)).toList()..shuffle(random ?? Random());
  return pool.take(request.count).toList();
}

@immutable
class OfflineAnswer {
  const OfflineAnswer({this.selected, this.typed, required this.answeredAt, this.timeSpentMs});

  factory OfflineAnswer.fromJson(Map<String, dynamic> json) => OfflineAnswer(
    selected: json['selected'] as int?,
    typed: json['typed'] as String?,
    answeredAt: DateTime.parse(json['answered_at'] as String),
    timeSpentMs: json['time_spent_ms'] as int?,
  );

  final int? selected;
  final String? typed;
  final DateTime answeredAt;
  final int? timeSpentMs;

  Map<String, Object?> toJson() => {
    'selected': selected,
    'typed': typed,
    'answered_at': answeredAt.toUtc().toIso8601String(),
    'time_spent_ms': timeSpentMs,
  };
}

/// A practice session done on the device. Answers are final once given (as online).
@immutable
class OfflineSession {
  const OfflineSession({
    required this.id,
    required this.startedAt,
    required this.questions,
    this.examCode,
    this.finishedAt,
    this.answers = const {},
  });

  factory OfflineSession.fromJson(Map<String, dynamic> json) => OfflineSession(
    id: json['id'] as String,
    examCode: json['exam_code'] as String?,
    startedAt: DateTime.parse(json['started_at'] as String),
    finishedAt: json['finished_at'] == null ? null : DateTime.parse(json['finished_at'] as String),
    questions: [
      for (final q in json['questions'] as List<dynamic>)
        OfflineQuestion(q as Map<String, dynamic>),
    ],
    answers: {
      for (final MapEntry(:key, :value) in (json['answers'] as Map<String, dynamic>).entries)
        int.parse(key): OfflineAnswer.fromJson(value as Map<String, dynamic>),
    },
  );

  final String id;
  final String? examCode;
  final DateTime startedAt;
  final DateTime? finishedAt;
  final List<OfflineQuestion> questions;

  /// By position (1-based).
  final Map<int, OfflineAnswer> answers;

  bool get finished => finishedAt != null;

  Map<String, Object?> toJson() => {
    'id': id,
    'exam_code': examCode,
    'started_at': startedAt.toUtc().toIso8601String(),
    'finished_at': finishedAt?.toUtc().toIso8601String(),
    'questions': [for (final q in questions) q.json],
    'answers': {for (final e in answers.entries) '${e.key}': e.value.toJson()},
  };

  OfflineSession withAnswer(int position, OfflineAnswer answer) => OfflineSession(
    id: id,
    examCode: examCode,
    startedAt: startedAt,
    finishedAt: finishedAt,
    questions: questions,
    answers: {...answers, position: answer},
  );

  OfflineSession finish(DateTime at) => OfflineSession(
    id: id,
    examCode: examCode,
    startedAt: startedAt,
    finishedAt: at,
    questions: questions,
    answers: answers,
  );

  /// Device marking (a preview: the server marks again on upload). Null = not answered.
  bool? isCorrect(int position) {
    final answer = answers[position];
    if (answer == null) return null;
    final q = questions[position - 1];
    if (q.isTyped) {
      return answer.typed != null &&
          q.typedAnswer != null &&
          typedAnswerMatches(q.typedAnswer!, answer.typed!);
    }
    return answer.selected != null && answer.selected == q.correctPosition;
  }

  AnswerFeedback feedback(int position) {
    final q = questions[position - 1];
    return AnswerFeedback(
      correctPosition: q.correctPosition,
      correctTypedAnswer: q.typedAnswer,
      isCorrect: isCorrect(position),
      explanation: q.json['explanation'] as String?,
    );
  }

  /// The upload body for `POST /api/v1/practice/offline-sessions`.
  Map<String, Object?> uploadJson() => {
    'client_id': id,
    'exam_code': ?examCode,
    'started_at': startedAt.toUtc().toIso8601String(),
    'finished_at': (finishedAt ?? startedAt).toUtc().toIso8601String(),
    'items': [
      for (final (i, q) in questions.indexed)
        {
          'question_id': q.id,
          if (answers[i + 1]?.selected != null) 'selected_position': answers[i + 1]!.selected,
          if (answers[i + 1]?.typed != null) 'typed_answer': answers[i + 1]!.typed,
          if (answers[i + 1] != null)
            'answered_at': answers[i + 1]!.answeredAt.toUtc().toIso8601String(),
          if (answers[i + 1]?.timeSpentMs != null) 'time_spent_ms': answers[i + 1]!.timeSpentMs,
        },
    ],
  };

  PracticeSessionView toView(DateTime now) {
    final items = <SessionItemView>[
      for (final (i, q) in questions.indexed)
        SessionItemView(
          position: i + 1,
          questionId: q.id,
          section: q.json['section'] as String?,
          stem: q.json['stem'] as String,
          options: [
            for (final o in q.json['options'] as List<dynamic>)
              QuestionOption.fromJson(o as Map<String, dynamic>),
          ],
          passage: q.json['passage'] == null
              ? null
              : Passage.fromJson(q.json['passage'] as Map<String, dynamic>),
          origin: QuestionOrigin.source,
          verified: true,
          sourceFilename: q.json['document_filename'] as String?,
          sourcePage: q.json['page'] as int?,
          sourceNumber: q.json['question_number'] as int?,
          bookmarked: false,
          shared: q.json['shared'] == true,
          sharedSource: q.json['shared_source'] as String?,
          answerType: q.isTyped ? 'typed' : 'choice',
          typedAnswerNumeric: q.json['typed_answer_numeric'] == true,
          selectedPosition: answers[i + 1]?.selected,
          typedAnswer: answers[i + 1]?.typed,
          feedback: answers.containsKey(i + 1) || finished ? feedback(i + 1) : null,
        ),
    ];
    return PracticeSessionView(
      id: id,
      mode: SessionMode.practice,
      submitted: finished,
      startedAt: startedAt,
      serverNow: now,
      items: items,
      offline: true,
      result: finished ? _result() : null,
    );
  }

  SessionResultView _result() {
    final n = questions.length;
    var correct = 0;
    var wrong = 0;
    final bySection = <String, (int, int, int)>{};
    for (var p = 1; p <= n; p++) {
      final ok = isCorrect(p);
      final section = questions[p - 1].json['section'] as String? ?? '';
      final (c, w, u) = bySection[section] ?? (0, 0, 0);
      bySection[section] = switch (ok) {
        true => (c + 1, w, u),
        false => (c, w + 1, u),
        null => (c, w, u + 1),
      };
      if (ok == true) correct++;
      if (ok == false) wrong++;
    }
    TallyView tally(String name, int c, int w, int u) => TallyView(
      name: name,
      correct: c,
      wrong: w,
      unattempted: u,
      score: c.toDouble(),
      maxScore: (c + w + u).toDouble(),
      accuracy: c + w == 0 ? null : c / (c + w),
      explanation: '',
    );
    return SessionResultView(
      total: tally('', correct, wrong, n - correct - wrong),
      timeTakenSeconds: (finishedAt ?? startedAt).difference(startedAt).inSeconds,
      markingNote: '',
      sections: [
        for (final MapEntry(key: name, value: (c, w, u)) in bySection.entries)
          if (name.isNotEmpty) tally(name, c, w, u),
      ],
      topics: const [],
    );
  }
}
