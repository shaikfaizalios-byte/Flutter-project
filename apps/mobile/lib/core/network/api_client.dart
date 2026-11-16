import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/application/auth_controller.dart';
import '../config/app_config.dart';
import 'auth_interceptor.dart';

/// A Dio for the PrepLoop API with the shared options (no auth interceptor).
Dio buildApiDio(AppConfig config, {bool isWeb = kIsWeb}) => Dio(
  BaseOptions(
    baseUrl: config.apiBaseUrl,
    connectTimeout: const Duration(seconds: 10),
    sendTimeout: const Duration(seconds: 20),
    receiveTimeout: const Duration(seconds: 20),
    headers: {'Accept': 'application/json'},
    responseType: ResponseType.json,
  ),
)..interceptors.add(BrowserWaitInterceptor(isWeb: isWeb));

/// In a browser the connect limit runs until the answer starts arriving (a page can't see the
/// connection open), so a request the server works on for longer than it, such as writing an AI
/// question, was cut off as "offline". There the connect limit also covers the wait for the
/// answer. Native apps are unchanged.
class BrowserWaitInterceptor extends Interceptor {
  const BrowserWaitInterceptor({required this.isWeb});

  final bool isWeb;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    if (isWeb) options.connectTimeout = browserConnectTimeout(options);
    handler.next(options);
  }
}

/// The connect limit plus the time the answer may take; null (no limit) when either is unset.
Duration? browserConnectTimeout(RequestOptions options) {
  final connect = options.connectTimeout;
  final receive = options.receiveTimeout;
  if (connect == null || connect == Duration.zero) return connect;
  if (receive == null || receive == Duration.zero) return Duration.zero;
  return connect + receive;
}

/// Plain client for cacheable figure links: no access token, so a CDN can cache the answer.
final mediaDioProvider = Provider<Dio>((ref) {
  final dio = buildApiDio(ref.watch(appConfigProvider));
  ref.onDispose(dio.close);
  return dio;
});

/// Shared HTTP client for the PrepLoop API. Adds the access token to every request and,
/// when the server answers 401, refreshes the tokens once and retries.
final dioProvider = Provider<Dio>((ref) {
  final dio = buildApiDio(ref.watch(appConfigProvider));
  dio.interceptors.add(
    AuthInterceptor(
      dio,
      accessToken: () => ref.read(authControllerProvider).session?.accessToken,
      refresh: () => ref.read(authControllerProvider.notifier).refreshAccessToken(),
    ),
  );
  ref.onDispose(dio.close);
  return dio;
});
