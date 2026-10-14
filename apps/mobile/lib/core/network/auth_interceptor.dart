import 'dart:async';

import 'package:dio/dio.dart';

/// Adds `Authorization: Bearer <access token>` and handles expired tokens: on a 401 it
/// asks for a refreshed token once (concurrent requests share one refresh, because the
/// interceptor is queued) and retries the request. If refreshing fails, the 401 is passed
/// on and the app returns to sign-in.
class AuthInterceptor extends QueuedInterceptor {
  AuthInterceptor(this._dio, {required this.accessToken, required this.refresh});

  final Dio _dio;
  final String? Function() accessToken;

  /// Returns a new access token, or null if the session is over.
  final Future<String?> Function() refresh;

  static const _retried = 'auth_retried';

  /// Same options and connection adapter, no interceptors.
  late final Dio _retryClient = Dio(_dio.options)..httpClientAdapter = _dio.httpClientAdapter;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final token = accessToken();
    if (token != null && !options.headers.containsKey('Authorization')) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }

  @override
  Future<void> onError(DioException err, ErrorInterceptorHandler handler) async {
    final request = err.requestOptions;
    if (err.response?.statusCode != 401 || request.extra[_retried] == true) {
      return handler.next(err);
    }
    final sentWith = request.headers['Authorization'];
    final current = accessToken();
    // Another request may already have refreshed while this one was in flight.
    final token = current != null && 'Bearer $current' != sentWith ? current : await refresh();
    if (token == null) return handler.next(err);
    try {
      // Retry outside this queued interceptor: going through it again would wait behind
      // this very error handler (deadlock) if the retry also failed.
      final retry = await _retryClient.fetch<Object?>(
        request.copyWith(
          headers: {...request.headers, 'Authorization': 'Bearer $token'},
          extra: {...request.extra, _retried: true},
        ),
      );
      handler.resolve(retry);
    } on DioException catch (e) {
      handler.next(e);
    }
  }
}
