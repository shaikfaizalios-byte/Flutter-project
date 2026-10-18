import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/network/api_client.dart';
import '../domain/radar.dart';
import '../domain/repeats.dart';

/// Server-computed repetition reports. Throws `AppFailure`s.
abstract interface class InsightsRepository {
  /// Over the learner's own papers.
  Future<RepeatsReport> repeats({String? examCode});

  /// Pooled over learners who share their counts (the Repeat Radar).
  Future<RadarReport> radar({String? examCode});

  Future<RadarSettings> radarSettings();

  Future<RadarSettings> setRadarShare({required bool share});
}

class RemoteInsightsRepository implements InsightsRepository {
  const RemoteInsightsRepository(this._dio);

  final Dio _dio;

  @override
  Future<RepeatsReport> repeats({String? examCode}) => _guard(() async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/api/v1/insights/repeats',
      queryParameters: {'exam': ?examCode},
    );
    return RepeatsReport.fromJson(response.data!);
  });

  @override
  Future<RadarReport> radar({String? examCode}) => _guard(() async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/api/v1/radar',
      queryParameters: {'exam': ?examCode},
    );
    return RadarReport.fromJson(response.data!);
  });

  @override
  Future<RadarSettings> radarSettings() => _guard(() async {
    final response = await _dio.get<Map<String, dynamic>>('/api/v1/radar/settings');
    return RadarSettings.fromJson(response.data!);
  });

  @override
  Future<RadarSettings> setRadarShare({required bool share}) => _guard(() async {
    final response = await _dio.put<Map<String, dynamic>>(
      '/api/v1/radar/settings',
      data: {'share': share},
    );
    return RadarSettings.fromJson(response.data!);
  });

  static Future<T> _guard<T>(Future<T> Function() call) async {
    try {
      return await call();
    } on DioException catch (e) {
      throw mapDioException(e);
    }
  }
}

final insightsRepositoryProvider = Provider<InsightsRepository>(
  (ref) => RemoteInsightsRepository(ref.watch(dioProvider)),
);

Duration? _noRetry(int retryCount, Object error) => null;

/// The report for one exam (null = all exams). Errors are shown, not retried silently.
final repeatsProvider = FutureProvider.autoDispose.family<RepeatsReport, String?>(
  (ref, examCode) => ref.watch(insightsRepositoryProvider).repeats(examCode: examCode),
  retry: _noRetry,
);

final radarProvider = FutureProvider.autoDispose.family<RadarReport, String?>(
  (ref, examCode) => ref.watch(insightsRepositoryProvider).radar(examCode: examCode),
  retry: _noRetry,
);

final radarSettingsProvider = FutureProvider.autoDispose<RadarSettings>(
  (ref) => ref.watch(insightsRepositoryProvider).radarSettings(),
  retry: _noRetry,
);
