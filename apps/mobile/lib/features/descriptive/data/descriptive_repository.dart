import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/localization/content_language.dart';
import '../../../core/network/api_client.dart';
import '../domain/descriptive_models.dart';

/// Written practice on the server: AI stays there. Throws `AppFailure`s.
abstract interface class DescriptiveRepository {
  Future<DescriptiveOverview> overview(String examCode);

  /// Plans the steps (no AI yet): AI-written levels, or real questions from the learner's papers.
  Future<DescriptiveSession> start({
    required String examCode,
    required String topicId,
    required ContentLanguage language,
    bool fromPapers = false,
  });

  /// Writes and checks one level's question and rubric.
  Future<DescriptiveStep> generate(String sessionId, int step);

  /// Marks an answer; the text goes to the AI service.
  Future<DescriptiveStep> answer(
    String sessionId,
    int step, {
    required String text,
    required bool fromPhoto,
  });

  /// Reads handwriting from a photo for correcting. The photo goes to the AI service and is not
  /// stored.
  Future<PhotoReading> readPhoto(String name, List<int> bytes);
}

class RemoteDescriptiveRepository implements DescriptiveRepository {
  const RemoteDescriptiveRepository(this._dio);

  final Dio _dio;
  static const _base = '/api/v1/descriptive';

  /// Marking is two or three AI calls, far over the usual wait.
  static final _aiOptions = Options(receiveTimeout: const Duration(minutes: 3));

  @override
  Future<DescriptiveOverview> overview(String examCode) => _guard(() async {
    final reply = await _dio.get<Map<String, dynamic>>(
      '$_base/overview',
      queryParameters: {'exam': examCode},
    );
    return DescriptiveOverview.fromJson(reply.data!);
  });

  @override
  Future<DescriptiveSession> start({
    required String examCode,
    required String topicId,
    required ContentLanguage language,
    bool fromPapers = false,
  }) => _guard(() async {
    final reply = await _dio.post<Map<String, dynamic>>(
      '$_base/sessions',
      data: {
        'exam_code': examCode,
        'topic_id': topicId,
        'language': language.code,
        'source': fromPapers ? 'papers' : 'ai',
      },
    );
    return DescriptiveSession.fromJson(reply.data!);
  });

  @override
  Future<DescriptiveStep> generate(String sessionId, int step) => _guard(() async {
    final reply = await _dio.post<Map<String, dynamic>>(
      '$_base/sessions/$sessionId/steps/$step/generate',
      options: _aiOptions,
    );
    return DescriptiveStep.fromJson(reply.data!);
  });

  @override
  Future<DescriptiveStep> answer(
    String sessionId,
    int step, {
    required String text,
    required bool fromPhoto,
  }) => _guard(() async {
    final reply = await _dio.post<Map<String, dynamic>>(
      '$_base/sessions/$sessionId/steps/$step/answer',
      data: {'text': text, 'source': fromPhoto ? 'photo' : 'typed'},
      options: _aiOptions,
    );
    return DescriptiveStep.fromJson(reply.data!);
  });

  @override
  Future<PhotoReading> readPhoto(String name, List<int> bytes) => _guard(() async {
    final reply = await _dio.post<Map<String, dynamic>>(
      '$_base/read-photo',
      data: FormData.fromMap({'file': MultipartFile.fromBytes(bytes, filename: name)}),
      options: _aiOptions,
    );
    return PhotoReading.fromJson(reply.data!);
  });

  Future<T> _guard<T>(Future<T> Function() request) async {
    try {
      return await request();
    } on DioException catch (exception) {
      throw mapDioException(exception);
    }
  }
}

final descriptiveRepositoryProvider = Provider<DescriptiveRepository>(
  (ref) => RemoteDescriptiveRepository(ref.watch(dioProvider)),
);
