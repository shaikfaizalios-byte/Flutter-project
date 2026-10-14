import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/application/auth_controller.dart';
import '../config/app_config.dart';
import 'auth_interceptor.dart';

/// A Dio for the PrepLoop API with the shared options (no interceptors).
Dio buildApiDio(AppConfig config) => Dio(
  BaseOptions(
    baseUrl: config.apiBaseUrl,
    connectTimeout: const Duration(seconds: 10),
    sendTimeout: const Duration(seconds: 20),
    receiveTimeout: const Duration(seconds: 20),
    headers: {'Accept': 'application/json'},
    responseType: ResponseType.json,
  ),
);

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
