import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/network/api_client.dart';
import '../domain/repeats.dart';

/// Server-computed repetition report over the learner's own papers. Throws `AppFailure`s.
abstract interface class InsightsRepository {
  Future<RepeatsReport> repeats({String? examCode});
}

class RemoteInsightsRepository implements InsightsRepository {
  const RemoteInsightsRepository(this._dio);

  final Dio _dio;

  @override
  Future<RepeatsReport> repeats({String? examCode}) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/api/v1/insights/repeats',
        queryParameters: {'exam': ?examCode},
      );
      return RepeatsReport.fromJson(response.data!);
    } on DioException catch (e) {
      throw mapDioException(e);
    }
  }
}

final insightsRepositoryProvider = Provider<InsightsRepository>(
  (ref) => RemoteInsightsRepository(ref.watch(dioProvider)),
);

/// The report for one exam (null = all exams). Errors are shown, not retried silently.
final repeatsProvider = FutureProvider.autoDispose.family<RepeatsReport, String?>(
  (ref, examCode) => ref.watch(insightsRepositoryProvider).repeats(examCode: examCode),
  retry: (_, _) => null,
);
