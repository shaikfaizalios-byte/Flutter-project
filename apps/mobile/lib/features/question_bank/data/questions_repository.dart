import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/network/api_client.dart';
import '../../../core/utils/calendar_date.dart';
import '../domain/question.dart';

/// Server-backed question bank. Methods throw `AppFailure`s.
abstract interface class QuestionsRepository {
  Future<(List<BankQuestion> items, int total)> list(QuestionQuery query);
  Future<BankQuestion> get(String id);
  Future<BankQuestion> update(String id, QuestionEdit edit);

  /// Topics the learner can use (for one exam when given).
  Future<List<TopicRef>> topics({String? examCode});

  /// Named question types (patterns) of every topic.
  Future<List<PatternRef>> patterns();
  Future<ParseSummary> parseSummary(String documentId);
  Future<ParseSummary> resegment(String documentId);

  /// Accepts every suggested topic and pattern of the paper's questions; returns how many.
  Future<({int topics, int patterns})> acceptSuggestedTopics(String documentId);

  /// Verifies every question of the paper that needs no review (answer known, no open issue).
  Future<({int verified, int left})> verifyClean(String documentId);

  /// Confirms when the paper was held (all null = date unknown).
  Future<void> setPaperDate(String documentId, {int? year, CalendarDate? date, int? shift});

  /// PNG bytes of a figure cropped from the question's source PDF.
  Future<Uint8List> figure(String questionId, String figureId);

  /// Extracted text of one source page (1-based), for side-by-side review.
  Future<String> pageText(String documentId, int page);
}

class RemoteQuestionsRepository implements QuestionsRepository {
  const RemoteQuestionsRepository(this._dio);

  final Dio _dio;

  @override
  Future<(List<BankQuestion>, int)> list(QuestionQuery query) => _guard(() async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/api/v1/questions',
      queryParameters: query.toParams(),
    );
    final data = response.data!;
    return (
      [
        for (final item in data['items'] as List<dynamic>)
          BankQuestion.fromJson(item as Map<String, dynamic>),
      ],
      data['total'] as int,
    );
  });

  @override
  Future<BankQuestion> get(String id) => _guard(() async {
    final response = await _dio.get<Map<String, dynamic>>('/api/v1/questions/$id');
    return BankQuestion.fromJson(response.data!);
  });

  @override
  Future<BankQuestion> update(String id, QuestionEdit edit) => _guard(() async {
    final response = await _dio.patch<Map<String, dynamic>>(
      '/api/v1/questions/$id',
      data: edit.toJson(),
    );
    return BankQuestion.fromJson(response.data!);
  });

  @override
  Future<List<TopicRef>> topics({String? examCode}) => _guard(() async {
    final response = await _dio.get<List<dynamic>>(
      '/api/v1/topics',
      queryParameters: {'exam': ?examCode},
    );
    return [for (final t in response.data!) TopicRef.fromJson(t as Map<String, dynamic>)];
  });

  @override
  Future<List<PatternRef>> patterns() => _guard(() async {
    final response = await _dio.get<List<dynamic>>('/api/v1/patterns');
    return [for (final p in response.data!) PatternRef.fromJson(p as Map<String, dynamic>)];
  });

  @override
  Future<ParseSummary> parseSummary(String documentId) => _guard(() async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/api/v1/documents/$documentId/parse-summary',
    );
    return ParseSummary.fromJson(response.data!);
  });

  @override
  Future<ParseSummary> resegment(String documentId) => _guard(() async {
    final response = await _dio.post<Map<String, dynamic>>('/api/v1/documents/$documentId/segment');
    return ParseSummary.fromJson(response.data!);
  });

  @override
  Future<({int topics, int patterns})> acceptSuggestedTopics(String documentId) => _guard(() async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/api/v1/documents/$documentId/topics/accept',
    );
    final data = response.data!;
    return (topics: data['accepted'] as int, patterns: data['patterns_accepted'] as int? ?? 0);
  });

  @override
  Future<({int verified, int left})> verifyClean(String documentId) => _guard(() async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/api/v1/documents/$documentId/questions/verify-clean',
    );
    final data = response.data!;
    return (verified: data['verified'] as int, left: data['left_for_review'] as int);
  });

  @override
  Future<void> setPaperDate(String documentId, {int? year, CalendarDate? date, int? shift}) =>
      _guard(() async {
        await _dio.put<Map<String, dynamic>>(
          '/api/v1/documents/$documentId/paper-date',
          data: {'exam_year': year, 'exam_date': date?.toIsoString(), 'exam_shift': shift},
        );
      });

  @override
  Future<Uint8List> figure(String questionId, String figureId) => _guard(() async {
    final response = await _dio.get<List<int>>(
      '/api/v1/questions/$questionId/figures/$figureId',
      options: Options(responseType: ResponseType.bytes),
    );
    return Uint8List.fromList(response.data!);
  });

  @override
  Future<String> pageText(String documentId, int page) => _guard(() async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/api/v1/documents/$documentId/pages',
      queryParameters: {'offset': page - 1, 'limit': 1},
    );
    final items = response.data!['items'] as List<dynamic>;
    return items.isEmpty ? '' : (items.first as Map<String, dynamic>)['text'] as String;
  });

  static Future<T> _guard<T>(Future<T> Function() call) async {
    try {
      return await call();
    } on DioException catch (e) {
      throw mapDioException(e);
    }
  }
}

final questionsRepositoryProvider = Provider<QuestionsRepository>(
  (ref) => RemoteQuestionsRepository(ref.watch(dioProvider)),
);
