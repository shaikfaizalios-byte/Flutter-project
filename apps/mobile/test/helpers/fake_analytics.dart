import 'package:preploop/core/errors/app_failure.dart';
import 'package:preploop/core/utils/calendar_date.dart';
import 'package:preploop/features/analytics/data/analytics_repository.dart';
import 'package:preploop/features/analytics/domain/analytics_models.dart';

/// Empty server statistics for 12 Oct 2026 (no answers yet).
PracticeAnalytics emptyAnalytics({CalendarDate? today}) => PracticeAnalytics(
  timezone: 'Asia/Kolkata',
  today: today ?? CalendarDate(2026, 10, 12),
  days: 30,
  recentDays: 14,
  total: const AnswerCounts(answered: 0, correct: 0),
  sessions: 0,
);

/// Stand-in for the analytics API. Set [offline] to simulate no connection.
class FakeAnalyticsRepository implements AnalyticsRepository {
  FakeAnalyticsRepository({PracticeAnalytics? data}) : data = data ?? emptyAnalytics();

  PracticeAnalytics data;
  bool offline = false;
  final requestedTimezones = <String>[];
  final requestedExams = <String?>[];

  @override
  Future<PracticeAnalytics> overview({required String timezone, String? examCode}) async {
    requestedTimezones.add(timezone);
    requestedExams.add(examCode);
    if (offline) throw const NetworkFailure();
    return data;
  }
}
