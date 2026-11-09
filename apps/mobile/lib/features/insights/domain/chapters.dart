import 'package:flutter/foundation.dart';

@immutable
class YearWeight {
  const YearWeight({required this.year, required this.questions, required this.shifts});

  factory YearWeight.fromJson(Map<String, dynamic> json) => YearWeight(
    year: json['year'] as int,
    questions: json['questions'] as int,
    shifts: json['shifts'] as int,
  );

  final int year;
  final int questions;
  final int shifts;
}

@immutable
class SessionWeight {
  const SessionWeight({required this.session, required this.questions, required this.shifts});

  factory SessionWeight.fromJson(Map<String, dynamic> json) => SessionWeight(
    session: json['session'] as String,
    questions: json['questions'] as int,
    shifts: json['shifts'] as int,
  );

  final String session;
  final int questions;
  final int shifts;
}

@immutable
class TopicWeight {
  const TopicWeight({required this.name, required this.questions, required this.shifts});

  factory TopicWeight.fromJson(Map<String, dynamic> json) => TopicWeight(
    name: json['name'] as String,
    questions: json['questions'] as int,
    shifts: json['shifts'] as int,
  );

  final String name;
  final int questions;
  final int shifts;
}

@immutable
class ChapterWeight {
  const ChapterWeight({
    required this.subject,
    required this.name,
    required this.questions,
    required this.shifts,
    this.years = const [],
    this.sessions = const [],
    this.topics = const [],
  });

  factory ChapterWeight.fromJson(Map<String, dynamic> json) => ChapterWeight(
    subject: json['subject'] as String,
    name: json['name'] as String,
    questions: json['questions'] as int,
    shifts: json['shifts'] as int,
    years: _years(json['years']),
    sessions: _sessions(json['sessions']),
    topics: [
      for (final t in json['topics'] as List<dynamic>)
        TopicWeight.fromJson(t as Map<String, dynamic>),
    ],
  );

  final String subject;
  final String name;
  final int questions;
  final int shifts;
  final List<YearWeight> years;
  final List<SessionWeight> sessions;
  final List<TopicWeight> topics;
}

List<YearWeight> _years(Object? json) => [
  for (final y in json! as List<dynamic>) YearWeight.fromJson(y as Map<String, dynamic>),
];

List<SessionWeight> _sessions(Object? json) => [
  for (final s in json! as List<dynamic>) SessionWeight.fromJson(s as Map<String, dynamic>),
];

/// What was counted: every shift, and the reviewed questions in them.
@immutable
class ShiftBasis {
  const ShiftBasis({
    required this.shifts,
    required this.questions,
    required this.unreviewed,
    this.years = const [],
    this.sessions = const [],
  });

  factory ShiftBasis.fromJson(Map<String, dynamic> json) => ShiftBasis(
    shifts: json['shifts'] as int,
    questions: json['questions'] as int,
    unreviewed: json['unreviewed'] as int,
    years: _years(json['years']),
    sessions: _sessions(json['sessions']),
  );

  final int shifts;
  final int questions;
  final int unreviewed;
  final List<YearWeight> years;
  final List<SessionWeight> sessions;

  YearWeight? year(int year) => years.where((y) => y.year == year).firstOrNull;

  SessionWeight? session(String name) => sessions.where((s) => s.session == name).firstOrNull;
}

@immutable
class ChapterReport {
  const ChapterReport({required this.basis, this.chapters = const []});

  factory ChapterReport.fromJson(Map<String, dynamic> json) => ChapterReport(
    basis: ShiftBasis.fromJson(json['basis'] as Map<String, dynamic>),
    chapters: [
      for (final c in json['chapters'] as List<dynamic>)
        ChapterWeight.fromJson(c as Map<String, dynamic>),
    ],
  );

  final ShiftBasis basis;
  final List<ChapterWeight> chapters;
}

/// A chapter's share of a year's reviewed questions, as a whole percent. Null without any.
int? weightPercent(int questions, int ofQuestions) =>
    ofQuestions == 0 ? null : (questions * 100 / ofQuestions).round();

@immutable
class ExamChapter {
  const ExamChapter({
    required this.examCode,
    required this.questions,
    required this.shifts,
    required this.totalShifts,
  });

  factory ExamChapter.fromJson(Map<String, dynamic> json) => ExamChapter(
    examCode: json['exam_code'] as String,
    questions: json['questions'] as int,
    shifts: json['shifts'] as int,
    totalShifts: json['total_shifts'] as int,
  );

  final String examCode;
  final int questions;
  final int shifts;
  final int totalShifts;
}

/// A chapter reviewers linked across exams.
@immutable
class SharedChapter {
  const SharedChapter({required this.subject, required this.name, required this.exams});

  factory SharedChapter.fromJson(Map<String, dynamic> json) => SharedChapter(
    subject: json['subject'] as String,
    name: json['name'] as String,
    exams: [
      for (final e in json['exams'] as List<dynamic>)
        ExamChapter.fromJson(e as Map<String, dynamic>),
    ],
  );

  final String subject;
  final String name;
  final List<ExamChapter> exams;
}

@immutable
class ConceptHintQuestion {
  const ConceptHintQuestion({required this.questionId, this.year, this.number, this.excerpt});

  factory ConceptHintQuestion.fromJson(Map<String, dynamic> json) => ConceptHintQuestion(
    questionId: json['question_id'] as String,
    year: json['year'] as int?,
    number: json['number'] as int?,
    excerpt: json['excerpt'] as String?,
  );

  final String questionId;
  final int? year;
  final int? number;
  final String? excerpt;
}

/// Questions an AI read as testing one concept. A hint, outside every reviewed count.
@immutable
class ConceptHint {
  const ConceptHint({
    required this.topicName,
    required this.label,
    required this.shifts,
    required this.questions,
  });

  factory ConceptHint.fromJson(Map<String, dynamic> json) => ConceptHint(
    topicName: json['topic_name'] as String,
    label: json['label'] as String,
    shifts: json['shifts'] as int,
    questions: [
      for (final q in json['questions'] as List<dynamic>)
        ConceptHintQuestion.fromJson(q as Map<String, dynamic>),
    ],
  );

  final String topicName;
  final String label;
  final int shifts;
  final List<ConceptHintQuestion> questions;
}
