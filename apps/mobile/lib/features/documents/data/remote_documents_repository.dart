import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../../../core/errors/app_failure.dart';
import '../../concepts/domain/concept.dart';
import '../domain/documents_repository.dart';
import '../domain/imported_document.dart';
import '../domain/paper_details.dart';

class RemoteDocumentsRepository implements DocumentsRepository {
  const RemoteDocumentsRepository(this._dio);

  final Dio _dio;

  static const _path = '/api/v1/documents';

  /// Large PDFs on slow mobile networks need far longer than the default send timeout.
  static const _uploadSendTimeout = Duration(minutes: 10);

  @override
  Future<List<ImportedDocument>> list() => _guard(() async {
    final response = await _dio.get<Map<String, dynamic>>(_path, queryParameters: {'limit': 100});
    final items = (response.data?['items'] as List<dynamic>? ?? const []);
    return [for (final item in items) ImportedDocument.fromJson(item as Map<String, dynamic>)];
  });

  @override
  Future<List<ImportedDocument>> addSamples({required String examCode}) => _guard(() async {
    final response = await _dio.post<List<dynamic>>(
      '$_path/samples',
      data: {'exam_code': examCode},
    );
    return [
      for (final item in response.data ?? const <dynamic>[])
        ImportedDocument.fromJson(item as Map<String, dynamic>),
    ];
  });

  @override
  Future<ImportedDocument> upload(
    UploadSource source, {
    required String examCode,
    required ContentLanguage language,
    void Function(double progress)? onProgress,
    UploadCancellation? cancellation,
  }) => _guard(() async {
    final cancelToken = CancelToken();
    cancellation?.onCancel(cancelToken.cancel);
    final form = FormData.fromMap({
      'exam_code': examCode,
      'language': language.code,
      'file': MultipartFile.fromStream(
        source.open,
        source.length,
        filename: source.name,
        contentType: DioMediaType('application', 'pdf'),
      ),
    });
    final response = await _dio.post<Map<String, dynamic>>(
      _path,
      data: form,
      cancelToken: cancelToken,
      options: Options(sendTimeout: _uploadSendTimeout),
      onSendProgress: onProgress == null
          ? null
          : (sent, total) => onProgress(total <= 0 ? 0 : (sent / total).clamp(0, 1)),
    );
    return ImportedDocument.fromJson(response.data!);
  });

  @override
  Future<void> delete(String id) => _guard(() => _dio.delete<void>('$_path/$id'));

  @override
  Future<void> setDetails(String id, PaperDetails details) =>
      _guard(() => _dio.put<void>('$_path/$id/details', data: details.toJson()));

  @override
  Future<List<OtherSet>> duplicateSuggestions(String id) => _guard(() async {
    final response = await _dio.get<List<dynamic>>('$_path/$id/duplicate-suggestions');
    return [for (final s in response.data!) OtherSet.fromJson(s as Map<String, dynamic>)];
  });

  @override
  Future<void> markAsSetOf(String id, String otherId) =>
      _guard(() => _dio.put<void>('$_path/$id/details', data: {'duplicate_of_id': otherId}));

  @override
  Future<AnswerKeyResult> sendKeyText(String id, String text) => _guard(() async {
    final response = await _dio.post<Map<String, dynamic>>(
      '$_path/$id/answer-key/text',
      data: {'text': text},
    );
    return AnswerKeyResult.fromJson(response.data!);
  });

  @override
  Future<AnswerKeyResult> sendKeyFile(String id, UploadSource source) => _guard(() async {
    final form = FormData.fromMap({
      'file': MultipartFile.fromStream(
        source.open,
        source.length,
        filename: source.name,
        contentType: DioMediaType('application', 'pdf'),
      ),
    });
    final response = await _dio.post<Map<String, dynamic>>(
      '$_path/$id/answer-key',
      data: form,
      options: Options(sendTimeout: _uploadSendTimeout),
    );
    return AnswerKeyResult.fromJson(response.data!);
  });

  @override
  Future<Uint8List> pageImage(String id, int page) => _guard(() async {
    final response = await _dio.get<List<int>>(
      '$_path/$id/pages/$page/image',
      options: Options(responseType: ResponseType.bytes),
    );
    return Uint8List.fromList(response.data!);
  });

  static Future<T> _guard<T>(Future<T> Function() call) async {
    try {
      return await call();
    } on DioException catch (e) {
      throw mapDioException(e);
    }
  }
}
