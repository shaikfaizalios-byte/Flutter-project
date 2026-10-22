import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/exams/exam_catalog.dart';
import '../../../core/network/api_client.dart';
import '../domain/exam_topics.dart';
import '../../concepts/domain/concept.dart';
import '../../documents/domain/imported_document.dart';

/// Exams (catalog + the learner's own) and their topics. Throws `AppFailure`s.
abstract interface class ExamsRepository {
  Future<List<ExamOption>> exams();

  Future<ExamOption> createExam(String name);

  Future<ExamOption> renameExam(String code, String name);

  Future<void> deleteExam(String code);

  Future<List<ExamTopic>> topics(String examCode);

  Future<ExamTopic> createTopic(String examCode, NewTopic topic);

  /// Saves several topics at once (duplicates are skipped by the server).
  /// Saves several topics; with [syllabusName] (a PDF's file name or "typed"), they are
  /// grouped under one syllabus import that can be removed as a whole.
  Future<List<ExamTopic>> createTopics(
    String examCode,
    List<NewTopic> topics, {
    String? syllabusName,
    SyllabusKind? syllabusKind,
  });

  /// The learner's syllabus imports for an exam, newest first.
  Future<List<SyllabusImport>> syllabusImports(String examCode);

  /// Removes a syllabus import and all its topics; returns how many topics were removed.
  Future<int> deleteSyllabusImport(String importId);

  Future<ExamTopic> updateTopic(String topicId, {String? subject, String? name});

  Future<void> deleteTopic(String topicId);

  /// AI-proposed topics from the learner's imported questions (only when AI is on).
  Future<TopicDraft> draftTopics(String examCode);

  /// Marks a topic as revised (or not) for the learner.
  Future<ExamTopic> setCompleted(String topicId, {required bool completed});

  /// Removes several of the learner's own topics; returns how many were removed.
  Future<int> deleteTopics(List<String> topicIds);

  /// Reads subjects and topics from a typed or pasted syllabus (nothing is saved).
  Future<SyllabusDraft> readSyllabusText(String examCode, String text);

  /// Reads subjects and topics from a syllabus PDF (nothing is saved).
  Future<SyllabusDraft> readSyllabus(
    String examCode,
    UploadSource source, {
    required ContentLanguage language,
  });
}

class RemoteExamsRepository implements ExamsRepository {
  const RemoteExamsRepository(this._dio);

  final Dio _dio;
  static const _base = '/api/v1';

  @override
  Future<List<ExamOption>> exams() => _guard(() async {
    final response = await _dio.get<List<dynamic>>('$_base/me/exams');
    return [for (final e in response.data!) ExamOption.fromJson(e as Map<String, dynamic>)];
  });

  @override
  Future<ExamOption> createExam(String name) => _guard(() async {
    final response = await _dio.post<Map<String, dynamic>>('$_base/me/exams', data: {'name': name});
    return ExamOption.fromJson(response.data!);
  });

  @override
  Future<ExamOption> renameExam(String code, String name) => _guard(() async {
    final response = await _dio.patch<Map<String, dynamic>>(
      '$_base/me/exams/$code',
      data: {'name': name},
    );
    return ExamOption.fromJson(response.data!);
  });

  @override
  Future<void> deleteExam(String code) => _guard(() => _dio.delete<void>('$_base/me/exams/$code'));

  @override
  Future<List<ExamTopic>> topics(String examCode) => _guard(() async {
    final response = await _dio.get<List<dynamic>>('$_base/exams/$examCode/topics');
    return [for (final t in response.data!) ExamTopic.fromJson(t as Map<String, dynamic>)];
  });

  @override
  Future<ExamTopic> createTopic(String examCode, NewTopic topic) => _guard(() async {
    final response = await _dio.post<Map<String, dynamic>>(
      '$_base/topics',
      data: topic.toJson(examCode),
    );
    return ExamTopic.fromJson(response.data!);
  });

  @override
  Future<List<ExamTopic>> createTopics(
    String examCode,
    List<NewTopic> topics, {
    String? syllabusName,
    SyllabusKind? syllabusKind,
  }) => _guard(() async {
    final response = await _dio.post<List<dynamic>>(
      '$_base/topics/bulk',
      data: {
        'exam_code': examCode,
        'topics': [for (final t in topics) t.toJson(examCode)],
        if (syllabusName != null && syllabusKind != null)
          'source': {'name': syllabusName, 'kind': syllabusKind.name},
      },
    );
    return [for (final t in response.data!) ExamTopic.fromJson(t as Map<String, dynamic>)];
  });

  @override
  Future<List<SyllabusImport>> syllabusImports(String examCode) => _guard(() async {
    final response = await _dio.get<List<dynamic>>('$_base/exams/$examCode/syllabus-imports');
    return [for (final s in response.data!) SyllabusImport.fromJson(s as Map<String, dynamic>)];
  });

  @override
  Future<int> deleteSyllabusImport(String importId) => _guard(() async {
    final response = await _dio.delete<Map<String, dynamic>>('$_base/syllabus-imports/$importId');
    return response.data!['deleted'] as int;
  });

  @override
  Future<ExamTopic> updateTopic(String topicId, {String? subject, String? name}) =>
      _guard(() async {
        final response = await _dio.patch<Map<String, dynamic>>(
          '$_base/topics/$topicId',
          data: {'subject': ?subject, 'name': ?name},
        );
        return ExamTopic.fromJson(response.data!);
      });

  @override
  Future<void> deleteTopic(String topicId) =>
      _guard(() => _dio.delete<void>('$_base/topics/$topicId'));

  @override
  Future<TopicDraft> draftTopics(String examCode) => _guard(() async {
    final response = await _dio.post<Map<String, dynamic>>('$_base/ai/exams/$examCode/topic-draft');
    return TopicDraft.fromJson(response.data!);
  });

  @override
  Future<int> deleteTopics(List<String> topicIds) => _guard(() async {
    final response = await _dio.post<Map<String, dynamic>>(
      '$_base/topics/bulk-delete',
      data: {'topic_ids': topicIds},
    );
    return response.data!['deleted'] as int;
  });

  @override
  Future<SyllabusDraft> readSyllabusText(String examCode, String text) => _guard(() async {
    final response = await _dio.post<Map<String, dynamic>>(
      '$_base/exams/$examCode/syllabus/text',
      data: {'text': text},
    );
    return SyllabusDraft.fromJson(response.data!);
  });

  @override
  Future<ExamTopic> setCompleted(String topicId, {required bool completed}) => _guard(() async {
    final response = await _dio.put<Map<String, dynamic>>(
      '$_base/topics/$topicId/completion',
      data: {'completed': completed},
    );
    return ExamTopic.fromJson(response.data!);
  });

  @override
  Future<SyllabusDraft> readSyllabus(
    String examCode,
    UploadSource source, {
    required ContentLanguage language,
  }) => _guard(() async {
    final form = FormData.fromMap({
      'language': language.code,
      'file': MultipartFile.fromStream(
        source.open,
        source.length,
        filename: source.name,
        contentType: DioMediaType('application', 'pdf'),
      ),
    });
    final response = await _dio.post<Map<String, dynamic>>(
      '$_base/exams/$examCode/syllabus',
      data: form,
      // A scanned syllabus is read page by page (OCR) while the request waits.
      options: Options(
        sendTimeout: const Duration(minutes: 2),
        receiveTimeout: const Duration(minutes: 3),
      ),
    );
    return SyllabusDraft.fromJson(response.data!);
  });

  static Future<T> _guard<T>(Future<T> Function() call) async {
    try {
      return await call();
    } on DioException catch (e) {
      throw mapDioException(e);
    }
  }
}

final examsRepositoryProvider = Provider<ExamsRepository>(
  (ref) => RemoteExamsRepository(ref.watch(dioProvider)),
);
