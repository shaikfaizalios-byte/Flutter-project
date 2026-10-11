import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/network/api_client.dart';
import '../domain/server_health.dart';

class ServerStatusRepository {
  const ServerStatusRepository(this._dio);

  final Dio _dio;

  /// Calls `GET /api/v1/health`. Throws an [AppFailure] on any error.
  Future<ServerHealth> fetchHealth() async {
    try {
      final response = await _dio.get<Map<String, dynamic>>('/api/v1/health');
      final data = response.data;
      if (data == null || data['status'] != 'ok') {
        throw ServerFailure(statusCode: response.statusCode, code: 'unexpected_body');
      }
      return ServerHealth(
        version: data['version'] as String? ?? '?',
        environment: data['environment'] as String? ?? '?',
      );
    } on DioException catch (e) {
      throw mapDioException(e);
    }
  }
}

final serverStatusRepositoryProvider = Provider<ServerStatusRepository>(
  (ref) => ServerStatusRepository(ref.watch(dioProvider)),
);

/// Fetched when the settings screen is shown; refresh with `ref.invalidate`.
/// Automatic retries are disabled so the UI shows the real state promptly.
final serverHealthProvider = FutureProvider.autoDispose<ServerHealth>(
  (ref) => ref.watch(serverStatusRepositoryProvider).fetchHealth(),
  retry: (retryCount, error) => null,
);
