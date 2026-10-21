import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/network/api_client.dart';

/// What a suggestion asks for.
enum SuggestionKind {
  add,
  remove,
  change,
  other;

  static SuggestionKind fromCode(String code) =>
      SuggestionKind.values.asNameMap()[code] ?? SuggestionKind.other;
}

/// Limits shared with the server (`app/schemas/feedback.py`).
abstract final class SuggestionRules {
  static const minLength = 10;
  static const maxLength = 2000;
}

@immutable
class Suggestion {
  const Suggestion({
    required this.id,
    required this.kind,
    required this.text,
    required this.status,
    required this.createdAt,
  });

  factory Suggestion.fromJson(Map<String, dynamic> json) => Suggestion(
    id: json['id'] as String,
    kind: SuggestionKind.fromCode(json['kind'] as String),
    text: json['text'] as String,
    status: json['status'] as String,
    createdAt: DateTime.parse(json['created_at'] as String),
  );

  final String id;
  final SuggestionKind kind;
  final String text;

  /// `new`, `read`, `planned`, `done` or `declined` (set by the PrepLoop team).
  final String status;
  final DateTime createdAt;
}

abstract interface class FeedbackRepository {
  Future<Suggestion> suggest(SuggestionKind kind, String text);

  Future<List<Suggestion>> mine();
}

class RemoteFeedbackRepository implements FeedbackRepository {
  RemoteFeedbackRepository(this._dio);

  final Dio _dio;

  static const _path = '/api/v1/suggestions';

  @override
  Future<Suggestion> suggest(SuggestionKind kind, String text) => _guard(() async {
    final response = await _dio.post<Map<String, dynamic>>(
      _path,
      data: {'kind': kind.name, 'text': text.trim()},
    );
    return Suggestion.fromJson(response.data!);
  });

  @override
  Future<List<Suggestion>> mine() => _guard(() async {
    final response = await _dio.get<List<dynamic>>(_path);
    return [for (final s in response.data!) Suggestion.fromJson(s as Map<String, dynamic>)];
  });

  static Future<T> _guard<T>(Future<T> Function() call) async {
    try {
      return await call();
    } on DioException catch (e) {
      throw mapDioException(e);
    }
  }
}

final feedbackRepositoryProvider = Provider<FeedbackRepository>(
  (ref) => RemoteFeedbackRepository(ref.watch(dioProvider)),
);

/// The learner's earlier suggestions (errors are shown, not retried silently).
final mySuggestionsProvider = FutureProvider.autoDispose<List<Suggestion>>(
  (ref) => ref.watch(feedbackRepositoryProvider).mine(),
  retry: (_, _) => null,
);
