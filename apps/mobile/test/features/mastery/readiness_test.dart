import 'package:flutter_test/flutter_test.dart';
import 'package:preploop/core/utils/calendar_date.dart';
import 'package:preploop/features/analytics/domain/analytics_models.dart';
import 'package:preploop/features/exams/domain/exam_topics.dart';
import 'package:preploop/features/mastery/domain/mastery.dart';
import 'package:preploop/features/mastery/domain/readiness.dart';

import '../../helpers/pump_app.dart';
import '../analytics/progress_flow_test.dart' show openProgress, sampleStats, scrollProgress;

final today = CalendarDate(2026, 10, 12);

ExamTopic syllabusTopic(String id, String subject, String name) =>
    ExamTopic(id: id, subject: subject, name: name, own: true);

void main() {
  test('readiness counts syllabus coverage and recent evidence, with no score', () {
    final practice = sampleStats(); // Percentage 20 answers at 40 %, Average 12 at 100 %
    final readiness = buildReadiness(
      subjects: examMastery(
        topics: [
          syllabusTopic('t-pct', 'Quantitative Aptitude', 'Percentage'),
          syllabusTopic('t-avg', 'Quantitative Aptitude', 'Average'),
          syllabusTopic('t-alg', 'Quantitative Aptitude', 'Algebra'),
          syllabusTopic('t-syn', 'English Language', 'Synonyms'),
        ],
        practice: practice,
      ),
      today: today,
      practice: PracticeAnalytics(
        timezone: practice.timezone,
        today: today,
        days: 30,
        recentDays: 14,
        total: practice.total,
        sessions: practice.sessions,
        daily: [
          DailyStats(date: today, answered: 12, correct: 9),
          DailyStats(date: today.addDays(-13), answered: 8, correct: 3),
          DailyStats(date: today.addDays(-14), answered: 50, correct: 50), // outside 14 days
        ],
        mocks: [
          MockResultView(sessionId: 'm2', localDate: today.addDays(-3), score: 90, maxScore: 200),
          MockResultView(sessionId: 'm1', localDate: today.addDays(-40), score: 60, maxScore: 200),
        ],
      ),
      examDate: today.addDays(45),
    );

    expect((readiness.topics, readiness.practised, readiness.strong), (4, 3, 1));
    final quant = readiness.subjects.first;
    expect(
      (quant.name, quant.topics, quant.practised, quant.strong),
      ('Quantitative Aptitude', 3, 2, 1),
    );
    expect((readiness.recentAnswers, readiness.recentCorrect), (20, 12));
    expect(readiness.mocksInWindow, 1); // the 40-day-old mock is outside the window
    expect(readiness.latestMock!.sessionId, 'm2');
    expect(readiness.daysToExam, 45);
  });

  test('offline and without a syllabus nothing is made up', () {
    final readiness = buildReadiness(
      subjects: const [],
      today: today,
      examDate: today.addDays(-1), // passed
    );
    expect(readiness.hasSyllabus, isFalse);
    expect(readiness.recentAnswers, isNull);
    expect(readiness.mocksInWindow, isNull);
    expect(readiness.daysToExam, isNull);
  });

  testAppWidgets('Progress shows readiness evidence and says it is not a prediction', (
    tester,
    db,
  ) async {
    await pumpPrepLoopApp(tester, db, analytics: FakeAnalyticsRepository(data: sampleStats()));
    await openProgress(tester);

    expect(find.text('Readiness'), findsOneWidget);
    expect(find.textContaining('Add your syllabus topics'), findsOneWidget);
    expect(find.text('12 answers in the last 14 days, 75% correct'), findsOneWidget);
    expect(
      find.textContaining('1 mock test in the last 30 days; latest: 101.5 of 200'),
      findsOneWidget,
    );
    await scrollProgress(tester, find.textContaining('It is not a prediction of your result.'));
  });
}
