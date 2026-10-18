import 'package:flutter/foundation.dart';

import '../../question_bank/domain/question.dart';

enum SessionMode {
  practice,
  mock;

  static SessionMode fromCode(String code) => code == 'mock' ? mock : practice;
}

@immutable
class AnswerFeedback {
  const AnswerFeedback({
    this.correctPosition,
    this.correctTypedAnswer,
    this.isCorrect,
    this.explanation,
    this.explanationByAi = false,
  });

  factory AnswerFeedback.fromJson(Map<String, dynamic> json) => AnswerFeedback(
    correctPosition: json['correct_position'] as int?,
    correctTypedAnswer: json['correct_typed_answer'] as String?,
    isCorrect: json['is_correct'] as bool?,
    explanation: json['explanation'] as String?,
    explanationByAi: json['explanation_origin'] == 'ai',
  );

  final int? correctPosition; // null for a typed-in question
  final String? correctTypedAnswer; // the expected answer of a typed-in question
  final bool? isCorrect; // null = not attempted
  final String? explanation;

  /// The explanation is AI-generated (labelled in the UI).
  final bool explanationByAi;
}

@immutable
class SessionItemView {
  const SessionItemView({
    required this.position,
    required this.options,
    required this.verified,
    required this.bookmarked,
    this.figures = const [],
    this.questionId,
    this.section,
    this.stem,
    this.passage,
    this.origin,
    this.sourceFilename,
    this.sourcePage,
    this.sourceNumber,
    this.selectedPosition,
    this.feedback,
    this.answerType = 'choice',
    this.typedAnswer,
    this.typedAnswerNumeric = false,
  });

  factory SessionItemView.fromJson(Map<String, dynamic> json) {
    final source = json['source'] as Map<String, dynamic>;
    return SessionItemView(
      position: json['position'] as int,
      questionId: json['question_id'] as String?,
      section: json['section'] as String?,
      stem: json['stem'] as String?,
      options: [
        for (final o in json['options'] as List<dynamic>)
          QuestionOption.fromJson(o as Map<String, dynamic>),
      ],
      figures: figuresFromJson(json['figures']),
      passage: json['passage'] == null
          ? null
          : Passage.fromJson(json['passage'] as Map<String, dynamic>),
      origin: json['origin'] == null ? null : QuestionOrigin.fromCode(json['origin'] as String),
      verified: json['verified'] as bool,
      sourceFilename: source['document_filename'] as String?,
      sourcePage: source['page'] as int?,
      sourceNumber: source['question_number'] as int?,
      bookmarked: json['bookmarked'] as bool,
      selectedPosition: json['selected_position'] as int?,
      answerType: json['answer_type'] as String? ?? 'choice',
      typedAnswer: json['typed_answer'] as String?,
      typedAnswerNumeric: json['typed_answer_numeric'] as bool? ?? false,
      feedback: json['feedback'] == null
          ? null
          : AnswerFeedback.fromJson(json['feedback'] as Map<String, dynamic>),
    );
  }

  final int position;
  final String? questionId;
  final String? section;

  /// Null when the question was deleted after the session started.
  final String? stem;
  final List<QuestionOption> options;

  /// Figures cropped from the source paper (fetched by [questionId] and figure id).
  final List<QuestionFigure> figures;
  final Passage? passage;
  final QuestionOrigin? origin;
  final bool verified;
  final String? sourceFilename;
  final int? sourcePage;
  final int? sourceNumber;
  final bool bookmarked;
  final int? selectedPosition;
  final AnswerFeedback? feedback;

  /// "choice" or "typed" (type the answer in, e.g. CAT TITA questions).
  final String answerType;

  /// What the learner typed (typed-in questions).
  final String? typedAnswer;

  /// The expected answer is a number: show a number keyboard.
  final bool typedAnswerNumeric;

  bool get isTyped => answerType == 'typed';
  bool get answered => selectedPosition != null || typedAnswer != null;

  SessionItemView copyWith({
    int? Function()? selectedPosition,
    String? Function()? typedAnswer,
    AnswerFeedback? Function()? feedback,
    bool? bookmarked,
  }) => SessionItemView(
    position: position,
    questionId: questionId,
    section: section,
    stem: stem,
    options: options,
    figures: figures,
    passage: passage,
    origin: origin,
    verified: verified,
    sourceFilename: sourceFilename,
    sourcePage: sourcePage,
    sourceNumber: sourceNumber,
    bookmarked: bookmarked ?? this.bookmarked,
    selectedPosition: selectedPosition != null ? selectedPosition() : this.selectedPosition,
    typedAnswer: typedAnswer != null ? typedAnswer() : this.typedAnswer,
    answerType: answerType,
    typedAnswerNumeric: typedAnswerNumeric,
    feedback: feedback != null ? feedback() : this.feedback,
  );
}

@immutable
class TallyView {
  const TallyView({
    required this.name,
    required this.correct,
    required this.wrong,
    required this.unattempted,
    required this.score,
    required this.maxScore,
    required this.explanation,
    this.accuracy,
  });

  factory TallyView.fromJson(Map<String, dynamic> json, {String? name}) => TallyView(
    name: name ?? json['name'] as String? ?? '',
    correct: json['correct'] as int,
    wrong: json['wrong'] as int,
    unattempted: json['unattempted'] as int,
    score: (json['score'] as num).toDouble(),
    maxScore: (json['max_score'] as num).toDouble(),
    accuracy: (json['accuracy'] as num?)?.toDouble(),
    explanation: json['explanation'] as String,
  );

  final String name;
  final int correct;
  final int wrong;
  final int unattempted;
  final double score;
  final double maxScore;
  final double? accuracy;

  /// Server-generated, e.g. "Correct 18 × 2.00 = 36.00; Wrong 4 × −0.50 = −2.00; ...".
  final String explanation;
}

@immutable
class SessionResultView {
  const SessionResultView({
    required this.total,
    required this.timeTakenSeconds,
    required this.markingNote,
    required this.sections,
    required this.topics,
  });

  factory SessionResultView.fromJson(Map<String, dynamic> json) => SessionResultView(
    total: TallyView.fromJson(json, name: ''),
    timeTakenSeconds: json['time_taken_seconds'] as int,
    markingNote: json['marking_note'] as String,
    sections: [
      for (final s in json['sections'] as List<dynamic>)
        TallyView.fromJson(s as Map<String, dynamic>),
    ],
    topics: [
      for (final t in json['topics'] as List<dynamic>)
        TallyView.fromJson(t as Map<String, dynamic>),
    ],
  );

  final TallyView total;
  final int timeTakenSeconds;
  final String markingNote;
  final List<TallyView> sections;
  final List<TallyView> topics;
}

@immutable
class PracticeSessionView {
  const PracticeSessionView({
    required this.id,
    required this.mode,
    required this.submitted,
    required this.startedAt,
    required this.serverNow,
    required this.items,
    this.formatName,
    this.deadlineAt,
    this.submitReason,
    this.result,
  });

  factory PracticeSessionView.fromJson(Map<String, dynamic> json) => PracticeSessionView(
    id: json['id'] as String,
    mode: SessionMode.fromCode(json['mode'] as String),
    submitted: json['status'] == 'submitted',
    formatName: (json['exam_format'] as Map<String, dynamic>?)?['name'] as String?,
    startedAt: DateTime.parse(json['started_at'] as String),
    deadlineAt: json['deadline_at'] == null ? null : DateTime.parse(json['deadline_at'] as String),
    serverNow: DateTime.parse(json['server_now'] as String),
    submitReason: json['submit_reason'] as String?,
    items: [
      for (final i in json['items'] as List<dynamic>)
        SessionItemView.fromJson(i as Map<String, dynamic>),
    ],
    result: json['result'] == null
        ? null
        : SessionResultView.fromJson(json['result'] as Map<String, dynamic>),
  );

  final String id;
  final SessionMode mode;
  final bool submitted;
  final String? formatName;
  final DateTime startedAt;

  /// Server-fixed deadline (mock tests). The app never computes its own.
  final DateTime? deadlineAt;
  final DateTime serverNow;
  final String? submitReason;
  final List<SessionItemView> items;
  final SessionResultView? result;

  int get answeredCount => items.where((i) => i.answered).length;

  PracticeSessionView withItem(SessionItemView item) => PracticeSessionView(
    id: id,
    mode: mode,
    submitted: submitted,
    formatName: formatName,
    startedAt: startedAt,
    deadlineAt: deadlineAt,
    serverNow: serverNow,
    submitReason: submitReason,
    items: [for (final i in items) i.position == item.position ? item : i],
    result: result,
  );
}

@immutable
class SessionSummaryView {
  const SessionSummaryView({
    required this.id,
    required this.mode,
    required this.submitted,
    required this.startedAt,
    required this.itemCount,
    this.formatName,
    this.score,
    this.maxScore,
  });

  factory SessionSummaryView.fromJson(Map<String, dynamic> json) => SessionSummaryView(
    id: json['id'] as String,
    mode: SessionMode.fromCode(json['mode'] as String),
    submitted: json['status'] == 'submitted',
    formatName: json['exam_format_name'] as String?,
    startedAt: DateTime.parse(json['started_at'] as String),
    itemCount: json['item_count'] as int,
    score: (json['score'] as num?)?.toDouble(),
    maxScore: (json['max_score'] as num?)?.toDouble(),
  );

  final String id;
  final SessionMode mode;
  final bool submitted;
  final String? formatName;
  final DateTime startedAt;
  final int itemCount;
  final double? score;
  final double? maxScore;
}

@immutable
class SectionAvailabilityView {
  const SectionAvailabilityView({
    required this.subject,
    required this.needed,
    required this.available,
  });

  final String subject;
  final int needed;
  final int available;
}

@immutable
class MockTestView {
  const MockTestView({
    required this.code,
    required this.name,
    required this.available,
    required this.totalQuestions,
    required this.sections,
    this.examCode,
    this.durationMinutes,
    this.negativeMarks,
  });

  factory MockTestView.fromJson(Map<String, dynamic> json) => MockTestView(
    code: json['exam_format_code'] as String,
    examCode: json['exam_code'] as String?,
    name: json['name'] as String,
    available: json['available'] as bool,
    totalQuestions: json['total_questions'] as int,
    durationMinutes: json['duration_minutes'] as int?,
    negativeMarks: (json['negative_marks_per_wrong'] as num?)?.toDouble(),
    sections: [
      for (final s in json['sections'] as List<dynamic>)
        SectionAvailabilityView(
          subject: (s as Map<String, dynamic>)['subject'] as String,
          needed: s['needed'] as int,
          available: s['available'] as int,
        ),
    ],
  );

  final String code;

  /// The exam the format belongs to (e.g. `SSC_CHSL`).
  final String? examCode;
  final String name;
  final bool available;
  final int totalQuestions;
  final int? durationMinutes;
  final double? negativeMarks;
  final List<SectionAvailabilityView> sections;
}

/// What to practise. No filters = mixed practice.
@immutable
class PracticeRequest {
  const PracticeRequest({
    this.examCode,
    this.subject,
    this.topicId,
    this.patternId,
    this.includeUnverified = false,
    this.includeAi = false,
    this.count = 10,
  });

  final String? examCode;
  final String? subject;
  final String? topicId;

  /// Only questions of this question type (pattern).
  final String? patternId;
  final bool includeUnverified;

  /// AI-generated questions (labelled) are used only when the learner opts in.
  final bool includeAi;
  final int count;

  Map<String, Object> toJson() => {
    'exam_code': ?examCode,
    'subject': ?subject,
    'topic_id': ?topicId,
    'pattern_id': ?patternId,
    'include_unverified': includeUnverified,
    'include_ai': includeAi,
    'count': count,
  };
}

/// Result of saving an answer: confirmed by the server, or queued while offline.
@immutable
class AnswerOutcome {
  const AnswerOutcome.confirmed(
    this.feedback, {
    required this.applied,
    this.selectedPosition,
    this.typedAnswer,
  }) : queued = false;

  const AnswerOutcome.queued()
    : feedback = null,
      applied = false,
      selectedPosition = null,
      typedAnswer = null,
      queued = true;

  final bool queued;
  final bool applied;
  final int? selectedPosition;
  final String? typedAnswer;
  final AnswerFeedback? feedback;
}
