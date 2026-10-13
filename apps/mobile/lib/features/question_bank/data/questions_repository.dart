import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/network/api_client.dart';
import '../domain/question.dart';

/// Server-backed question bank. Methods throw `AppFailure`s.
abstract interface class QuestionsRepository {
  Future<(List<BankQuestion> items, int total)> list(QuestionQuery query);
  Future<BankQuestion> get(String id);
  Future<BankQuestion> update(String id, QuestionEdit edit);
  Future<List<TopicRef>> topics();
  Future<ParseSummary> parseSummary(String documentId);
  Future<ParseSummary> resegment(String documentId);

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
  Future<List<TopicRef>> topics() => _guard(() async {
    final response = await _dio.get<List<dynamic>>('/api/v1/topics');
    return [for (final t in response.data!) TopicRef.fromJson(t as Map<String, dynamic>)];
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
