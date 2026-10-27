import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/network/api_client.dart';
import '../domain/radar.dart';
import '../domain/repeats.dart';

/// Server-computed repetition reports. Throws `AppFailure`s.
abstract interface class InsightsRepository {
  /// Over the learner's own papers.
  /// [scope]: "mine" (your papers), "shared" (the shared bank) or "all".
  Future<RepeatsReport> repeats({String? examCode, String scope = 'mine'});

  /// Pooled over learners who share their counts (the Repeat Radar).
  Future<RadarReport> radar({String? examCode});

  /// Starter papers per exam (the shared bank's papers and verified questions).
  Future<List<SharedBankExam>> sharedBank();

  Future<RadarSettings> radarSettings();

  Future<RadarSettings> setRadarShare({required bool share});
}

class RemoteInsightsRepository implements InsightsRepository {
  const RemoteInsightsRepository(this._dio);

  final Dio _dio;

  @override
  Future<RepeatsReport> repeats({String? examCode, String scope = 'mine'}) => _guard(() async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/api/v1/insights/repeats',
      queryParameters: {'exam': ?examCode, 'scope': scope},
    );
    return RepeatsReport.fromJson(response.data!);
  });

  @override
  Future<List<SharedBankExam>> sharedBank() => _guard(() async {
    final response = await _dio.get<List<dynamic>>('/api/v1/insights/shared-bank');
    return [for (final e in response.data!) SharedBankExam.fromJson(e as Map<String, dynamic>)];
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
typedef RepeatsQuery = ({String? examCode, String scope});

final repeatsProvider = FutureProvider.autoDispose.family<RepeatsReport, RepeatsQuery>(
  (ref, query) =>
      ref.watch(insightsRepositoryProvider).repeats(examCode: query.examCode, scope: query.scope),
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

/// Starter papers by exam code (empty offline or when nothing is shared).
final sharedBankProvider = FutureProvider.autoDispose<Map<String, SharedBankExam>>((ref) async {
  try {
    return {
      for (final e in await ref.watch(insightsRepositoryProvider).sharedBank()) e.examCode: e,
    };
  } on AppFailure {
    return const {};
  }
}, retry: _noRetry);
