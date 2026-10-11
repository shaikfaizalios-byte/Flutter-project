import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:preploop/core/errors/app_failure.dart';

void main() {
  final options = RequestOptions(path: '/api/v1/health');

  test('maps connection errors to NetworkFailure', () {
    final failure = mapDioException(
      DioException(requestOptions: options, type: DioExceptionType.connectionError),
    );

    expect(failure, isA<NetworkFailure>());
  });

  test('maps timeouts to TimeoutFailure', () {
    for (final type in [
      DioExceptionType.connectionTimeout,
      DioExceptionType.sendTimeout,
      DioExceptionType.receiveTimeout,
    ]) {
      expect(
        mapDioException(DioException(requestOptions: options, type: type)),
        isA<TimeoutFailure>(),
      );
    }
  });

  test('reads the backend error envelope from bad responses', () {
    final failure = mapDioException(
      DioException(
        requestOptions: options,
        type: DioExceptionType.badResponse,
        response: Response<Map<String, dynamic>>(
          requestOptions: options,
          statusCode: 404,
          data: {
            'error': {'code': 'not_found', 'message': 'Not Found', 'request_id': 'abc'},
          },
        ),
      ),
    );

    expect(failure, isA<ServerFailure>());
    final server = failure as ServerFailure;
    expect(server.statusCode, 404);
    expect(server.code, 'not_found');
    expect(server.requestId, 'abc');
  });

  test('tolerates non-JSON error bodies', () {
    final failure = mapDioException(
      DioException(
        requestOptions: options,
        type: DioExceptionType.badResponse,
        response: Response<String>(requestOptions: options, statusCode: 502, data: 'Bad Gateway'),
      ),
    );

    expect((failure as ServerFailure).statusCode, 502);
    expect(failure.code, isNull);
  });
}
