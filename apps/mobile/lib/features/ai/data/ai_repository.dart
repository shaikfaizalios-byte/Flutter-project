import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../../core/errors/app_failure.dart';
import '../../concepts/domain/concept.dart';
import '../../question_bank/domain/question.dart';

/// Whether the server has AI assistance configured (keys never reach the app).
@immutable
class AiStatus {
  const AiStatus({required this.enabled, this.model});

  static const off = AiStatus(enabled: false);

  final bool enabled;
  final String? model;
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

  /// Asks the AI for topics of the paper's questions that have none (one step).
  Future<PaperTopicsResult> suggestPaperTopics(String documentId);

  Future<BankQuestion> report(String questionId, ReportReason reason, {String note = ''});

  /// Sends the search text to the AI provider (only after the learner switched this on).
  Future<QuickAnswer> quickAnswer(String text, {String? examCode});
}

class RemoteAiRepository implements AiRepository {
  RemoteAiRepository(this._dio);

  final Dio _dio;
  static const _base = '/api/v1';

  @override
  Future<AiStatus> status() => _guard(() async {
    final data = (await _dio.get<Map<String, dynamic>>('$_base/ai/status')).data!;
    return AiStatus(enabled: data['enabled'] as bool, model: data['model'] as String?);
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

  static Future<T> _guard<T>(Future<T> Function() call) async {
    try {
      return await call();
    } on DioException catch (e) {
      throw mapDioException(e);
    }
  }
}
