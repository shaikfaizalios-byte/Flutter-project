import 'package:dio/dio.dart';

import '../../../core/errors/app_failure.dart';
import '../domain/analytics_models.dart';
import '../domain/weak_topics.dart';

/// Practice statistics from the server (attempts are recorded there).
class AnalyticsRepository {
  AnalyticsRepository(this._dio);

  final Dio _dio;

  /// Counts per subject, topic and local day in [timezone] (an IANA name), plus mock
  /// results, for [examCode] only when given. Throws [AppFailure].
  Future<PracticeAnalytics> overview({required String timezone, String? examCode}) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/api/v1/analytics/overview',
        queryParameters: {
          'timezone': timezone,
          'days': AnalyticsRules.windowDays,
          'recent_days': AnalyticsRules.recentDays,
          'exam': ?examCode,
        },
      );
      return PracticeAnalytics.fromJson(response.data!);
    } on DioException catch (e) {
      throw mapDioException(e);
    }
  }
}
