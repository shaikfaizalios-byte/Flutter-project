import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/app_features.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/localization/content_language.dart';
import '../../../core/network/api_client.dart';
import '../domain/ladder_models.dart';

/// Challenge Ladder on the server: AI and web search stay there. Throws `AppFailure`s.
abstract interface class LadderRepository {
  Future<LadderOverview> overview(String examCode);

  /// Plans round 1 (no AI yet).
  Future<LadderRound> start({
    required String examCode,
    required String topicId,
    required ContentLanguage language,
  });

  /// "Test me more": plans the next round.
  Future<LadderRound> nextRound(String sessionId);

  /// Writes and checks one question; the paper examples and web excerpts go to the AI provider.
  Future<LadderStep> generate(String sessionId, int round, int step);

  Future<LadderStep> answer(
    String sessionId,
    int round,
    int step, {
    int? selectedIndex,
    String? typedAnswer,
    Map<String, dynamic>? response,
    int? timeSpentMs,
  });
}

class RemoteLadderRepository implements LadderRepository {
  const RemoteLadderRepository(this._dio, {this.newFormats = false});

  final Dio _dio;

  /// This build can show formats beyond one correct option.
  final bool newFormats;
  static const _base = '/api/v1/ladder';

  /// One question means a few AI calls, far over the usual wait.
  static final _aiOptions = Options(receiveTimeout: const Duration(minutes: 2));

  @override
  Future<LadderOverview> overview(String examCode) => _guard(() async {
    final response = await _dio.get<Map<String, dynamic>>(
      '$_base/overview',
      queryParameters: {'exam': examCode},
    );
    return LadderOverview.fromJson(response.data!);
  });

  @override
  Future<LadderRound> start({
    required String examCode,
    required String topicId,
    required ContentLanguage language,
  }) => _guard(() async {
    final response = await _dio.post<Map<String, dynamic>>(
      '$_base/sessions',
      data: {
        'exam_code': examCode,
        'topic_id': topicId,
        'language': language.code,
        if (newFormats) 'include_new_formats': true,
      },
    );
    return LadderRound.fromJson(response.data!);
  });

  @override
  Future<LadderRound> nextRound(String sessionId) => _guard(() async {
    final response = await _dio.post<Map<String, dynamic>>('$_base/sessions/$sessionId/rounds');
    return LadderRound.fromJson(response.data!);
  });

  @override
  Future<LadderStep> generate(String sessionId, int round, int step) => _guard(() async {
    final response = await _dio.post<Map<String, dynamic>>(
      '$_base/sessions/$sessionId/rounds/$round/steps/$step/generate',
      options: _aiOptions,
    );
    return LadderStep.fromJson(response.data!);
  });

  @override
  Future<LadderStep> answer(
    String sessionId,
    int round,
    int step, {
    int? selectedIndex,
    String? typedAnswer,
    Map<String, dynamic>? response,
    int? timeSpentMs,
  }) => _guard(() async {
    final reply = await _dio.post<Map<String, dynamic>>(
      '$_base/sessions/$sessionId/rounds/$round/steps/$step/answer',
      data: {
        'selected_index': ?selectedIndex,
        'typed_answer': ?typedAnswer,
        'response': ?response,
        'time_spent_ms': ?timeSpentMs,
      },
    );
    return LadderStep.fromJson(reply.data!);
  });

  Future<T> _guard<T>(Future<T> Function() request) async {
    try {
      return await request();
    } on DioException catch (exception) {
      throw mapDioException(exception);
    }
  }
}

final ladderRepositoryProvider = Provider<LadderRepository>(
  (ref) => RemoteLadderRepository(
    ref.watch(dioProvider),
    newFormats: ref.watch(appFeaturesProvider).examProfiles,
  ),
);
