import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/localization/content_language.dart';
import '../../../core/network/api_client.dart';

/// Where a snapped question was found in the learner's own material.
enum SnapMatchKind { page, question, concept }

@immutable
class SnapMatch {
  const SnapMatch({
    required this.kind,
    required this.label,
    required this.snippet,
    this.verified = false,
    this.questionId,
    this.conceptId,
  });

  factory SnapMatch.fromJson(Map<String, dynamic> json) => SnapMatch(
    kind: switch (json['kind']) {
      'question' => SnapMatchKind.question,
      'concept' => SnapMatchKind.concept,
      _ => SnapMatchKind.page,
    },
    label: json['label'] as String,
    snippet: json['snippet'] as String,
    verified: json['verified'] as bool? ?? false,
    questionId: json['question_id'] as String?,
    conceptId: json['concept_id'] as String?,
  );

  final SnapMatchKind kind;
  final String label;
  final String snippet;

  /// A reviewer checked it (questions); page text is as read.
  final bool verified;
  final String? questionId;
  final String? conceptId;
}

/// What the server read from the photo, and where it was found. Nothing is stored.
@immutable
class SnapReading {
  const SnapReading({required this.text, required this.lowConfidence, required this.matches});

  factory SnapReading.fromJson(Map<String, dynamic> json) => SnapReading(
    text: json['text'] as String,
    lowConfidence: json['low_confidence'] as bool? ?? false,
    matches: [
      for (final m in json['matches'] as List<dynamic>)
        SnapMatch.fromJson(m as Map<String, dynamic>),
    ],
  );

  final String text;

  /// The reading is unsure: the learner should check the text.
  final bool lowConfidence;
  final List<SnapMatch> matches;
}

/// Snap a question on the server (OCR and search stay there). Throws `AppFailure`s.
abstract interface class SnapRepository {
  Future<SnapReading> readPhoto({
    required String examCode,
    required String name,
    required List<int> bytes,
    required ContentLanguage language,
  });

  /// Searches again with text the learner corrected.
  Future<List<SnapMatch>> match({required String examCode, required String text});
}

class RemoteSnapRepository implements SnapRepository {
  const RemoteSnapRepository(this._dio);

  final Dio _dio;
  static const _base = '/api/v1/search';

  /// OCR of a photo can take a while on the server.
  static final _readOptions = Options(receiveTimeout: const Duration(minutes: 2));

  @override
  Future<SnapReading> readPhoto({
    required String examCode,
    required String name,
    required List<int> bytes,
    required ContentLanguage language,
  }) => _guard(() async {
    final reply = await _dio.post<Map<String, dynamic>>(
      '$_base/photo',
      data: FormData.fromMap({
        'photo': MultipartFile.fromBytes(bytes, filename: name),
        'exam_code': examCode,
        'language': language.code,
      }),
      options: _readOptions,
    );
    return SnapReading.fromJson(reply.data!);
  });

  @override
  Future<List<SnapMatch>> match({required String examCode, required String text}) =>
      _guard(() async {
        final reply = await _dio.post<List<dynamic>>(
          '$_base/match',
          data: {'exam_code': examCode, 'text': text},
        );
        return [for (final m in reply.data!) SnapMatch.fromJson(m as Map<String, dynamic>)];
      });

  Future<T> _guard<T>(Future<T> Function() request) async {
    try {
      return await request();
    } on DioException catch (exception) {
      throw mapDioException(exception);
    }
  }
}

final snapRepositoryProvider = Provider<SnapRepository>(
  (ref) => RemoteSnapRepository(ref.watch(dioProvider)),
);
