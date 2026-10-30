import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../../core/errors/app_failure.dart';
import '../../concepts/domain/concept.dart';
import '../../question_bank/domain/question.dart';

/// Whether the server has AI assistance configured (keys never reach the app).
@immutable
class AiStatus {
  const AiStatus({
    required this.enabled,
    this.model,
    this.requiresPlus = false,
    this.plusActive = false,
    this.aiLeft,
  });

  static const off = AiStatus(enabled: false);

  final bool enabled;
  final String? model;

  /// The server needs PrepLoop Plus for AI requests (it decides; the app only shows it).
  final bool requiresPlus;
  final bool plusActive;

  /// AI requests left this month (null when Plus isn't required).
  final int? aiLeft;

  /// AI is on but this account needs Plus first: show the Plus prompt instead of AI actions.
  bool get needsPlus => enabled && requiresPlus && !plusActive;
}

@immutable
class GeneratedQuestions {
  const GeneratedQuestions({
    required this.created,
    required this.rejected,
    this.reasons = const [],
  });

  /// Stored as AI-generated and unverified (they need review).
  final List<BankQuestion> created;
  final int rejected;
  final List<String> reasons;
}

/// One step of AI topic suggestion for a paper (the server handles a few batches per call).
@immutable
class PaperTopicsResult {
  const PaperTopicsResult({
    required this.considered,
    required this.suggested,
    required this.noMatch,
    required this.remaining,
  });

  factory PaperTopicsResult.fromJson(Map<String, dynamic> json) => PaperTopicsResult(
    considered: json['considered'] as int,
    suggested: json['suggested'] as int,
    noMatch: json['no_match'] as int,
    remaining: json['remaining'] as int,
  );

  final int considered;

  /// Suggested topics; still need a reviewer's confirmation.
  final int suggested;
  final int noMatch;

  /// Questions not sent yet; call again while this is above zero.
  final int remaining;
}

/// A short AI answer to a search that matched no imported question. Not stored and not
/// checked by anyone: always shown labelled as AI-generated.
@immutable
class QuickAnswer {
  const QuickAnswer({required this.answer, required this.confident, required this.model});

  factory QuickAnswer.fromJson(Map<String, dynamic> json) => QuickAnswer(
    answer: json['answer'] as String,
    confident: json['confident'] as bool,
    model: json['model'] as String,
  );

  final String answer;

  /// False when the AI said it isn't sure.
  final bool confident;
  final String model;
}

/// Where a source of a [SearchAnswer] comes from.
enum SearchSourceKind { page, question, concept }

/// One piece of the learner's material a [SearchAnswer] may cite.
@immutable
class SearchAnswerSource {
  const SearchAnswerSource({
    required this.key,
    required this.kind,
    required this.label,
    required this.snippet,
    required this.verified,
    required this.cited,
    this.documentId,
    this.pageNumber,
    this.questionId,
    this.conceptId,
  });

  factory SearchAnswerSource.fromJson(Map<String, dynamic> json) => SearchAnswerSource(
    key: json['key'] as String,
    kind: SearchSourceKind.values.byName(json['kind'] as String),
    label: json['label'] as String,
    snippet: json['snippet'] as String,
    verified: json['verified'] as bool,
    cited: json['cited'] as bool,
    documentId: json['document_id'] as String?,
    pageNumber: json['page_number'] as int?,
    questionId: json['question_id'] as String?,
    conceptId: json['concept_id'] as String?,
  );

  /// "S1", "S2", ... as used in the answer's [S#] markers.
  final String key;
  final SearchSourceKind kind;
  final String label;
  final String snippet;

  /// Checked by a reviewer (questions) or the learner's own notes; page text is not.
  final bool verified;

  /// The answer uses this source.
  final bool cited;
  final String? documentId;
  final int? pageNumber;
  final String? questionId;
  final String? conceptId;
}

/// An AI answer written only from the learner's own material (RAG), with its sources.
/// [found] is false when the material doesn't answer the search ([answer] is then null).
@immutable
class SearchAnswer {
  const SearchAnswer({
    required this.found,
    required this.confident,
    required this.sources,
    this.answer,
    this.simple,
    this.model,
  });

  factory SearchAnswer.fromJson(Map<String, dynamic> json) => SearchAnswer(
    found: json['found'] as bool,
    answer: json['answer'] as String?,
    simple: json['simple'] as String?,
    confident: json['confident'] as bool,
    sources: [
      for (final s in json['sources'] as List<dynamic>)
        SearchAnswerSource.fromJson(s as Map<String, dynamic>),
    ],
    model: json['model'] as String?,
  );

  static const notFound = SearchAnswer(found: false, confident: true, sources: []);

  final bool found;

  /// What the material says, with [S#] markers.
  final String? answer;

  /// The same answer in simple words (AI; may use general knowledge, never cites).
  final String? simple;
  final bool confident;
  final List<SearchAnswerSource> sources;

  /// Null when no AI call was needed (nothing in the material matched).
  final String? model;

  List<SearchAnswerSource> get cited => [
    for (final s in sources)
      if (s.cited) s,
  ];
}

/// The topic a lesson or knowledge check is about: a syllabus topic or one the learner typed.
@immutable
class TopicChoice {
  const TopicChoice({required this.topic, this.subject});

  final String topic;
  final String? subject;

  @override
  bool operator ==(Object other) =>
      other is TopicChoice && other.topic == topic && other.subject == subject;

  @override
  int get hashCode => Object.hash(topic, subject);
}

/// A short AI lesson for a learner new to a topic. Not stored and not checked by anyone:
/// always shown labelled as AI-generated.
@immutable
class TopicLesson {
  const TopicLesson({
    required this.topic,
    required this.overview,
    required this.keyPoints,
    required this.commonMistakes,
    required this.confident,
    required this.model,
    this.subject,
    this.exampleQuestion,
    this.exampleAnswer,
  });

  factory TopicLesson.fromJson(Map<String, dynamic> json) => TopicLesson(
    topic: json['topic'] as String,
    subject: json['subject'] as String?,
    overview: json['overview'] as String,
    keyPoints: (json['key_points'] as List<dynamic>).cast<String>(),
    exampleQuestion: json['example_question'] as String?,
    exampleAnswer: json['example_answer'] as String?,
    commonMistakes: (json['common_mistakes'] as List<dynamic>).cast<String>(),
    confident: json['confident'] as bool,
    model: json['model'] as String,
  );

  final String topic;
  final String? subject;
  final String overview;
  final List<String> keyPoints;

  /// One worked example; both null when the topic has no sensible one.
  final String? exampleQuestion;
  final String? exampleAnswer;
  final List<String> commonMistakes;

  /// False when the AI said it isn't sure.
  final bool confident;
  final String model;
}

/// One AI question of a knowledge check (marked on the device, never stored).
@immutable
class QuizQuestion {
  const QuizQuestion({
    required this.stem,
    required this.options,
    required this.correctOption,
    required this.explanation,
  });

  factory QuizQuestion.fromJson(Map<String, dynamic> json) => QuizQuestion(
    stem: json['stem'] as String,
    options: (json['options'] as List<dynamic>).cast<String>(),
    correctOption: json['correct_option'] as int,
    explanation: json['explanation'] as String,
  );

  final String stem;
  final List<String> options;

  /// 1-based, as the server sends it.
  final int correctOption;
  final String explanation;
}

/// AI questions to check a topic the learner says they know. They never count as practice
/// or progress (they aren't reviewed).
@immutable
class TopicQuiz {
  const TopicQuiz({
    required this.topic,
    required this.questions,
    required this.model,
    this.subject,
  });

  factory TopicQuiz.fromJson(Map<String, dynamic> json) => TopicQuiz(
    topic: json['topic'] as String,
    subject: json['subject'] as String?,
    questions: [
      for (final q in json['questions'] as List<dynamic>)
        QuizQuestion.fromJson(q as Map<String, dynamic>),
    ],
    model: json['model'] as String,
  );

  final String topic;
  final String? subject;
  final List<QuizQuestion> questions;
  final String model;
}

enum ReportReason {
  wrongAnswer('wrong_answer'),
  unclear('unclear'),
  incorrectContent('incorrect_content'),
  other('other');

  const ReportReason(this.code);

  final String code;
}

/// AI assistance and learner reports. Every AI result is labelled and reviewed.
abstract interface class AiRepository {
  Future<AiStatus> status();

  Future<AiExplanation> draftExplanation(String questionId);

  Future<AiExplanation> reviewExplanation(String id, {required bool approve, String? text});

  Future<GeneratedQuestions> generateFromQuestion(
    BankQuestion source, {
    required ContentLanguage language,
    int count = 3,
  });

  /// Sends the concept's title and notes to the AI provider (the learner is told first).
  Future<GeneratedQuestions> generateFromConcept(
    Concept concept, {
    required ContentLanguage language,
    int count = 3,
  });

  /// Returns the updated question and whether a topic was suggested.
  Future<(BankQuestion, bool)> suggestTopic(String questionId);

  /// Queues reading the paper's questions with AI (its pages go to the AI provider). The
  /// worker reads it; the paper's parse summary shows the progress.
  Future<void> readPaper(String documentId);

  /// Asks the AI for topics of the paper's questions that have none (one step).
  Future<PaperTopicsResult> suggestPaperTopics(String documentId);

  Future<BankQuestion> report(String questionId, ReportReason reason, {String note = ''});

  /// Sends the search text to the AI provider (only after the learner switched this on).
  Future<QuickAnswer> quickAnswer(String text, {String? examCode});

  /// Answers from the learner's own material (RAG): the search and the matching excerpts go
  /// to the AI provider (only after the learner switched AI answers on).
  Future<SearchAnswer> searchAnswer(String text, {required String examCode});

  /// A lesson on the topic (the topic name goes to the AI provider; nothing is stored).
  Future<TopicLesson> topicLesson(
    TopicChoice choice, {
    required String examCode,
    required ContentLanguage language,
  });

  /// Questions that check the topic (the topic name goes to the AI provider; nothing is
  /// stored).
  Future<TopicQuiz> topicQuiz(
    TopicChoice choice, {
    required String examCode,
    required ContentLanguage language,
  });
}

class RemoteAiRepository implements AiRepository {
  RemoteAiRepository(this._dio);

  final Dio _dio;
  static const _base = '/api/v1';

  @override
  Future<AiStatus> status() => _guard(() async {
    final data = (await _dio.get<Map<String, dynamic>>('$_base/ai/status')).data!;
    return AiStatus(
      enabled: data['enabled'] as bool,
      model: data['model'] as String?,
      requiresPlus: data['requires_plus'] as bool? ?? false,
      plusActive: data['plus_active'] as bool? ?? false,
      aiLeft: data['ai_left_this_month'] as int?,
    );
  });

  @override
  Future<AiExplanation> draftExplanation(String questionId) => _guard(
    () async => AiExplanation.fromJson(
      (await _dio.post<Map<String, dynamic>>('$_base/ai/questions/$questionId/explanation')).data!,
    ),
  );

  @override
  Future<AiExplanation> reviewExplanation(String id, {required bool approve, String? text}) =>
      _guard(
        () async => AiExplanation.fromJson(
          (await _dio.patch<Map<String, dynamic>>(
            '$_base/ai/explanations/$id',
            data: {'status': approve ? 'approved' : 'rejected', 'text': ?text},
          )).data!,
        ),
      );

  @override
  Future<GeneratedQuestions> generateFromQuestion(
    BankQuestion source, {
    required ContentLanguage language,
    int count = 3,
  }) => _generate({
    'exam_code': source.examCode,
    'language': language.code,
    'count': count,
    'source_question_id': source.id,
  });

  @override
  Future<GeneratedQuestions> generateFromConcept(
    Concept concept, {
    required ContentLanguage language,
    int count = 3,
  }) => _generate({
    'exam_code': concept.examCode,
    'language': language.code,
    'count': count,
    'concept': {
      'title': concept.title,
      'notes': concept.notes,
      'subject': concept.subject,
      'topic': concept.topic,
    },
  });

  Future<GeneratedQuestions> _generate(Map<String, Object> body) => _guard(() async {
    final data = (await _dio.post<Map<String, dynamic>>(
      '$_base/ai/questions/generate',
      data: body,
    )).data!;
    return GeneratedQuestions(
      created: [
        for (final q in data['created'] as List<dynamic>)
          BankQuestion.fromJson(q as Map<String, dynamic>),
      ],
      rejected: data['rejected'] as int,
      reasons: (data['rejection_reasons'] as List<dynamic>).cast<String>(),
    );
  });

  @override
  Future<(BankQuestion, bool)> suggestTopic(String questionId) => _guard(() async {
    final data = (await _dio.post<Map<String, dynamic>>(
      '$_base/ai/questions/$questionId/topic-suggestion',
    )).data!;
    return (
      BankQuestion.fromJson(data['question'] as Map<String, dynamic>),
      data['suggested'] as bool,
    );
  });

  @override
  Future<void> readPaper(String documentId) => _guard(() async {
    await _dio.post<Map<String, dynamic>>('$_base/ai/documents/$documentId/read');
  });

  @override
  Future<PaperTopicsResult> suggestPaperTopics(String documentId) => _guard(() async {
    final response = await _dio.post<Map<String, dynamic>>(
      '$_base/ai/documents/$documentId/topic-suggestions',
    );
    return PaperTopicsResult.fromJson(response.data!);
  });

  @override
  Future<BankQuestion> report(String questionId, ReportReason reason, {String note = ''}) => _guard(
    () async => BankQuestion.fromJson(
      (await _dio.post<Map<String, dynamic>>(
        '$_base/questions/$questionId/report',
        data: {'reason': reason.code, 'note': note},
      )).data!,
    ),
  );

  @override
  Future<QuickAnswer> quickAnswer(String text, {String? examCode}) => _guard(
    () async => QuickAnswer.fromJson(
      (await _dio.post<Map<String, dynamic>>(
        '$_base/ai/quick-answer',
        data: {'text': text, 'exam_code': ?examCode},
      )).data!,
    ),
  );

  @override
  Future<SearchAnswer> searchAnswer(String text, {required String examCode}) => _guard(
    () async => SearchAnswer.fromJson(
      (await _dio.post<Map<String, dynamic>>(
        '$_base/ai/search-answer',
        data: {'text': text, 'exam_code': examCode},
      )).data!,
    ),
  );

  @override
  Future<TopicLesson> topicLesson(
    TopicChoice choice, {
    required String examCode,
    required ContentLanguage language,
  }) => _guard(
    () async => TopicLesson.fromJson(
      (await _dio.post<Map<String, dynamic>>(
        '$_base/ai/topic-lesson',
        data: _topicBody(choice, examCode, language),
      )).data!,
    ),
  );

  @override
  Future<TopicQuiz> topicQuiz(
    TopicChoice choice, {
    required String examCode,
    required ContentLanguage language,
  }) => _guard(
    () async => TopicQuiz.fromJson(
      (await _dio.post<Map<String, dynamic>>(
        '$_base/ai/topic-quiz',
        data: _topicBody(choice, examCode, language),
      )).data!,
    ),
  );

  static Map<String, Object> _topicBody(
    TopicChoice choice,
    String examCode,
    ContentLanguage language,
  ) => {
    'exam_code': examCode,
    'topic': choice.topic,
    'subject': ?choice.subject,
    'language': language.code,
  };

  static Future<T> _guard<T>(Future<T> Function() call) async {
    try {
      return await call();
    } on DioException catch (e) {
      throw mapDioException(e);
    }
  }
}
