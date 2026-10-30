import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../../../core/errors/app_failure.dart';
import '../../concepts/domain/concept.dart';
import '../domain/documents_repository.dart';
import '../domain/imported_document.dart';

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
