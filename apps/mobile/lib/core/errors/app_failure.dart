import 'package:dio/dio.dart';

/// Failures surfaced to the presentation layer. Repositories convert
/// transport exceptions into these so widgets never handle Dio types.
sealed class AppFailure implements Exception {
  const AppFailure();
}

/// The device could not reach the server (offline, DNS, refused connection).
class NetworkFailure extends AppFailure {
  const NetworkFailure();
}

class TimeoutFailure extends AppFailure {
  const TimeoutFailure();
}

class CancelledFailure extends AppFailure {
  const CancelledFailure();
}

/// The server responded with an error. Fields come from the backend's
/// `{"error": {"code", "message", "request_id"}}` envelope when present.
class ServerFailure extends AppFailure {
  const ServerFailure({required this.statusCode, this.code, this.message, this.requestId});

  final int? statusCode;
  final String? code;
  final String? message;
  final String? requestId;
}

class UnexpectedFailure extends AppFailure {
  const UnexpectedFailure(this.error);

  final Object error;
}

AppFailure mapDioException(DioException exception) {
  switch (exception.type) {
    case DioExceptionType.connectionTimeout:
    case DioExceptionType.sendTimeout:
    case DioExceptionType.receiveTimeout:
    case DioExceptionType.transformTimeout:
      return const TimeoutFailure();
    case DioExceptionType.connectionError:
      return const NetworkFailure();
    case DioExceptionType.cancel:
      return const CancelledFailure();
    case DioExceptionType.badResponse:
      final response = exception.response;
      final data = response?.data;
      final error = data is Map && data['error'] is Map ? data['error'] as Map : null;
      return ServerFailure(
        statusCode: response?.statusCode,
        code: error?['code'] as String?,
        message: error?['message'] as String?,
        requestId: error?['request_id'] as String?,
      );
    case DioExceptionType.badCertificate:
    case DioExceptionType.unknown:
      return UnexpectedFailure(exception.error ?? exception);
  }
}
