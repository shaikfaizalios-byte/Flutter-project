import 'package:dio/dio.dart';

import '../../../core/errors/app_failure.dart';
import '../domain/analytics_models.dart';
import '../domain/weak_topics.dart';

/// Practice statistics from the server (attempts are recorded there).
class AnalyticsRepository {
  AnalyticsRepository(this._dio);

  final Dio _dio;

  /// Answers on topics that mean the same across [exams], combined and per exam.
  Future<List<CanonicalTopic>> canonical(List<String> exams) async {
    try {
      final response = await _dio.get<List<dynamic>>(
        '/api/v1/analytics/canonical',
        queryParameters: {'exam': exams},
        options: Options(listFormat: ListFormat.multi),
      );
      return [
        for (final topic in response.data!) CanonicalTopic.fromJson(topic as Map<String, dynamic>),
      ];
    } on DioException catch (e) {
      throw mapDioException(e);
    }
  }

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
