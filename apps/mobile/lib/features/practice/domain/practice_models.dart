import 'package:flutter/foundation.dart';

import '../../question_bank/domain/question.dart';

enum SessionMode {
  practice,
  mock,

  /// The starter check for a learner without papers: untimed, answers shown after submitting.
  diagnostic;

  static SessionMode fromCode(String code) => switch (code) {
    'mock' => mock,
    'diagnostic' => diagnostic,
    _ => practice,
  };

  /// Answers can change and are only marked after submitting (mocks and the starter check).
  bool get testLike => this != practice;
}

@immutable
class AnswerFeedback {
  const AnswerFeedback({
    this.correctPosition,
    this.correctTypedAnswer,
    this.correctSpec,
    this.isCorrect,
    this.explanation,
    this.explanationByAi = false,
  });

  factory AnswerFeedback.fromJson(Map<String, dynamic> json) => AnswerFeedback(
    correctPosition: json['correct_position'] as int?,
    correctTypedAnswer: json['correct_typed_answer'] as String?,
    correctSpec: json['correct_spec'] as Map<String, dynamic>?,
    isCorrect: json['is_correct'] as bool?,
    explanation: json['explanation'] as String?,
    explanationByAi: json['explanation_origin'] == 'ai',
  );

  final int? correctPosition; // null for a typed-in question
  final String? correctTypedAnswer; // the expected answer of a typed-in question
  final Map<String, dynamic>? correctSpec; // the answer of a format with its own
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
    this.shared = false,
    this.sharedSource,
    this.format = 'single_correct',
    this.formatData,
    this.response,
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
      sharedSource: source['shared_source'] as String?,
      shared: json['shared'] as bool? ?? false,
      bookmarked: json['bookmarked'] as bool,
      selectedPosition: json['selected_position'] as int?,
      answerType: json['answer_type'] as String? ?? 'choice',
      typedAnswer: json['typed_answer'] as String?,
      typedAnswerNumeric: json['typed_answer_numeric'] as bool? ?? false,
      format: json['format'] as String? ?? 'single_correct',
      formatData: (json['format_data'] as Map<String, dynamic>?)?.map(
        (key, value) => MapEntry(key, (value as List<dynamic>).cast<String>()),
      ),
      response: json['response'] as Map<String, dynamic>?,
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

  /// How it is answered (the server's question formats).
  final String format;

  /// What the format lists for the learner: match and ordering items, never the answer.
  final Map<String, List<String>>? formatData;

  /// The answer of a format that takes more than one tap.
  final Map<String, dynamic>? response;

  /// From the shared bank (a paper the PrepLoop team shared): read-only, not bookmarkable.
  final bool shared;

  /// Where the shared paper came from (shown instead of a file name).
  final String? sharedSource;

  bool get isTyped => answerType == 'typed';
  bool get takesResponse => const {'multiple_correct', 'match', 'ordering'}.contains(format);
  bool get answered => selectedPosition != null || typedAnswer != null || response != null;

  SessionItemView copyWith({
    int? Function()? selectedPosition,
    String? Function()? typedAnswer,
    Map<String, dynamic>? Function()? response,
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
    shared: shared,
    sharedSource: sharedSource,
    format: format,
    formatData: formatData,
    response: response != null ? response() : this.response,
    feedback: feedback != null ? feedback() : this.feedback,
  );
}

/// The correct answer of a format with its own, in words. Null for the others.
String? correctAnswerText(SessionItemView item, AnswerFeedback feedback) {
  final spec = feedback.correctSpec;
  if (spec == null) return null;
  switch (item.format) {
    case 'multiple_correct':
      final positions = (spec['correct_positions'] as List<dynamic>).cast<int>();
      return [
        for (final p in positions)
          item.options.where((o) => o.position == p).firstOrNull?.label ?? '$p',
      ].join(', ');
    case 'numeric':
      if (spec['value'] case final Object value) {
        final tolerance = spec['tolerance'];
        return tolerance == null ? '$value' : '$value ± $tolerance';
      }
      return '${spec['min']} – ${spec['max']}';
    case 'fill_blank':
      return (spec['accepted'] as List<dynamic>).join(' / ');
    case 'match':
      final left = item.formatData?['left'] ?? const [];
      final right = item.formatData?['right'] ?? const [];
      return [
        for (final pair in spec['pairs'] as List<dynamic>)
          '${left[(pair as List<dynamic>)[0] as int]} → ${right[pair[1] as int]}',
      ].join(', ');
    case 'ordering':
      final items = item.formatData?['items'] ?? const [];
      return [for (final i in spec['order'] as List<dynamic>) items[i as int]].join(', ');
  }
  return null;
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
/// One timed section of a sectionally timed mock (positions 1-based, inclusive).
@immutable
class TimedSectionView {
  const TimedSectionView({
    required this.name,
    required this.firstPosition,
    required this.lastPosition,
    required this.minutes,
  });

  factory TimedSectionView.fromJson(Map<String, dynamic> json) => TimedSectionView(
    name: json['name'] as String,
    firstPosition: json['first_position'] as int,
    lastPosition: json['last_position'] as int,
    minutes: json['minutes'] as int,
  );

  final String name;
  final int firstPosition;
  final int lastPosition;
  final int minutes;

  bool contains(int position) => position >= firstPosition && position <= lastPosition;
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
    this.offline = false,
    this.sections = const [],
    this.currentSection,
    this.sectionDeadlineAt,
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
    sections: [
      for (final s in json['sections'] as List<dynamic>? ?? const [])
        TimedSectionView.fromJson(s as Map<String, dynamic>),
    ],
    currentSection: json['current_section'] as int?,
    sectionDeadlineAt: json['section_deadline_at'] == null
        ? null
        : DateTime.parse(json['section_deadline_at'] as String),
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

  /// Done on this device without a connection; uploaded (and marked again by the server)
  /// when back online.
  final bool offline;

  /// Sectionally timed mock: sections are taken in order, each with its own
  /// timer from the verified format. Empty for everything else.
  final List<TimedSectionView> sections;

  /// Index of the open section (equals [sections] length once all are closed).
  final int? currentSection;

  /// When the open section closes (server time).
  final DateTime? sectionDeadlineAt;

  bool get sectional => sections.isNotEmpty;

  TimedSectionView? get openSection {
    final index = currentSection;
    return index != null && index < sections.length ? sections[index] : null;
  }

  /// Whether the question at [position] can be shown and answered now.
  bool isOpen(int position) => !sectional || (openSection?.contains(position) ?? false);

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
    offline: offline,
    sections: sections,
    currentSection: currentSection,
    sectionDeadlineAt: sectionDeadlineAt,
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
    this.examCode,
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
    examCode: json['exam_code'] as String?,
  );

  final String id;
  final SessionMode mode;
  final bool submitted;
  final String? formatName;
  final DateTime startedAt;
  final int itemCount;

  /// The exam practised (null for older mixed sessions).
  final String? examCode;
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
    this.formatComplete = true,
    this.sectionCountsIndicative = false,
  });

  factory MockTestView.fromJson(Map<String, dynamic> json) => MockTestView(
    code: json['exam_format_code'] as String,
    examCode: json['exam_code'] as String?,
    name: json['name'] as String,
    available: json['available'] as bool,
    totalQuestions: json['total_questions'] as int,
    durationMinutes: json['duration_minutes'] as int?,
    negativeMarks: (json['negative_marks_per_wrong'] as num?)?.toDouble(),
    formatComplete: (json['format_problems'] as List<dynamic>? ?? const []).isEmpty,
    sectionCountsIndicative: json['section_counts_indicative'] as bool? ?? false,
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

  /// The exam the format belongs to.
  final String? examCode;
  final String name;
  final bool available;
  final int totalQuestions;
  final int? durationMinutes;
  final double? negativeMarks;

  /// False when the format does not state every fact a mock needs (marks, negative marking,
  /// duration). The server then refuses to start it; nothing is filled in with a default.
  final bool formatComplete;
  final List<SectionAvailabilityView> sections;

  /// The official notice gives its section-wise question counts as only indicative: the mock
  /// uses them, real papers may vary (shown on the mock).
  final bool sectionCountsIndicative;
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
    this.includeShared = true,
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

  /// Verified questions from the shared bank (labelled in the session).
  final bool includeShared;
  final int count;

  Map<String, Object> toJson() => {
    'exam_code': ?examCode,
    'subject': ?subject,
    'topic_id': ?topicId,
    'pattern_id': ?patternId,
    'include_unverified': includeUnverified,
    'include_ai': includeAi,
    'include_shared': includeShared,
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
    this.response,
  }) : queued = false;

  const AnswerOutcome.queued()
    : feedback = null,
      applied = false,
      selectedPosition = null,
      typedAnswer = null,
      response = null,
      queued = true;

  final Map<String, dynamic>? response;
  final bool queued;
  final bool applied;
  final int? selectedPosition;
  final String? typedAnswer;
  final AnswerFeedback? feedback;
}
