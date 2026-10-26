import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:preploop/core/database/app_database.dart';
import 'package:preploop/core/utils/calendar_date.dart';
import 'package:preploop/features/analytics/domain/analytics_models.dart';
import 'package:preploop/features/analytics/presentation/progress_screen.dart';
import 'package:preploop/features/practice/domain/practice_models.dart';
import 'package:preploop/features/question_bank/domain/question.dart';
import 'package:preploop/features/revision/data/revision_repository.dart';
import 'package:preploop/features/revision/domain/revision_schedule.dart';
import 'package:preploop/features/study_plan/domain/study_profile.dart';

import '../../helpers/pump_app.dart';

final today = CalendarDate(2026, 10, 12);

PracticeAnalytics sampleStats() => PracticeAnalytics(
  timezone: 'Asia/Kolkata',
  today: today,
  days: 30,
  recentDays: 14,
  total: const AnswerCounts(answered: 40, correct: 26),
  sessions: 5,
  subjects: const [
    SubjectStats(name: 'Quantitative Aptitude', counts: AnswerCounts(answered: 32, correct: 20)),
    SubjectStats(name: 'English Language', counts: AnswerCounts(answered: 8, correct: 6)),
  ],
  topics: const [
    TopicStats(
      topicId: 't-pct',
      name: 'Percentage',
      subject: 'Quantitative Aptitude',
      counts: AnswerCounts(answered: 20, correct: 8, recentAnswered: 10, recentCorrect: 6),
    ),
    TopicStats(
      topicId: 't-avg',
      name: 'Average',
      subject: 'Quantitative Aptitude',
      counts: AnswerCounts(answered: 12, correct: 12),
    ),
    TopicStats(
      topicId: 't-syn',
      name: 'Synonyms',
      subject: 'English Language',
      counts: AnswerCounts(answered: 8, correct: 6),
    ),
  ],
  daily: [DailyStats(date: today, answered: 12, correct: 9)],
  mocks: [
    MockResultView(
      sessionId: 'm1',
      name: 'SSC CHSL 2026 Tier-I',
      localDate: today.addDays(-3),
      score: 101.5,
      maxScore: 200,
      markingNote: 'Wrong answer: -0.50',
      timeUp: true,
    ),
  ],
);

const chslMock = MockTestView(
  code: 'SSC_CHSL_2026_TIER1',
  examCode: 'SSC_CHSL',
  name: 'SSC CHSL 2026 Tier-I',
  available: true,
  totalQuestions: 100,
  durationMinutes: 60,
  sections: [],
);

Future<void> openProgress(WidgetTester tester) async {
  await tester.tap(
    find.descendant(of: find.byType(NavigationBar), matching: find.text('Progress')),
  );
  await tester.pumpAndSettle();
}

/// Scrolls the Progress screen (the dashboard stays mounted in the tab stack and shows
/// some of the same texts) until [finder] inside it is visible.
Future<void> scrollProgress(WidgetTester tester, Finder finder) async {
  final inProgress = find.descendant(of: find.byType(ProgressScreen), matching: finder);
  final list = find
      .descendant(of: find.byType(ProgressScreen), matching: find.byType(Scrollable))
      .first;
  for (var i = 0; i < 20 && inProgress.evaluate().isEmpty; i++) {
    await tester.drag(list, const Offset(0, -200));
    await tester.pumpAndSettle();
  }
  expect(inProgress, findsOneWidget);
}

/// Adds a question card and reviews it [forgot] times "Forgot" and [good] times "Good".
Future<void> seedReviews(WidgetTester tester, AppDatabase db, {int forgot = 0, int good = 0}) =>
    seed(tester, () async {
      final repo = RevisionRepository(db, clock: () => testNow);
      await repo.addQuestions([
        bankQuestion(
          status: VerificationStatus.verified,
          topic: const TopicRef(id: 't-syn', subject: 'English Language', name: 'Synonyms'),
          section: 'English Language',
        ),
      ]);
      final id = (await db.select(db.revisionCards).getSingle()).id;
      for (var i = 0; i < forgot; i++) {
        await repo.review(id, RecallRating.again);
      }
      for (var i = 0; i < good; i++) {
        await repo.review(id, RecallRating.good);
      }
    });

void main() {
  testAppWidgets('progress is an honest empty state without any data', (tester, db) async {
    final analytics = FakeAnalyticsRepository();
    await pumpPrepLoopApp(tester, db, analytics: analytics);
    await openProgress(tester);

    expect(find.text('No progress data yet'), findsOneWidget);
    expect(analytics.requestedTimezones.last, 'Asia/Kolkata');
  });

  testAppWidgets('progress shows recorded answers, subjects, topics and mocks', (tester, db) async {
    await pumpPrepLoopApp(tester, db, analytics: FakeAnalyticsRepository(data: sampleStats()));
    await openProgress(tester);

    expect(find.text('40 practice answers'), findsOneWidget);
    expect(find.text('65% correct'), findsOneWidget);
    expect(find.text('5 sessions'), findsOneWidget);
    expect(find.text('63% correct over 32 answers'), findsOneWidget);
    expect(find.text('Not enough answers yet (8 of 10)'), findsOneWidget);
    await scrollProgress(tester, find.text('Percentage · Quantitative Aptitude'));
    await scrollProgress(tester, find.text('Percentage · Quantitative Aptitude'));
    expect(find.text('Weak'), findsOneWidget);
    expect(find.text('40% correct over 20 answers · Improving'), findsOneWidget);
    expect(find.textContaining('1 more topic needs more data'), findsOneWidget);

    await scrollProgress(tester, find.text('101.50 / 200.00'));
    expect(find.textContaining('Submitted when time ran out'), findsOneWidget);
    await scrollProgress(
      tester,
      find.textContaining('A topic is weak when it is below 60% correct'),
    );
  });

  testAppWidgets('flashcard forgetting counts towards weak topics', (tester, db) async {
    await seedReviews(tester, db, forgot: 3, good: 2);
    await pumpPrepLoopApp(tester, db, analytics: FakeAnalyticsRepository(data: sampleStats()));
    await openProgress(tester);

    await scrollProgress(tester, find.text('Synonyms · English Language'));
    expect(
      find.text('75% correct over 8 answers · forgotten in 3 of 5 flashcard reviews'),
      findsOneWidget,
    );
    await scrollProgress(tester, find.text('5 reviews, forgotten 3 times in the last 30 days'));
  });

  testAppWidgets('offline: progress explains, revision still shows', (tester, db) async {
    await seedReviews(tester, db, good: 1);
    final analytics = FakeAnalyticsRepository()..offline = true;
    await pumpPrepLoopApp(tester, db, analytics: analytics);
    await openProgress(tester);

    expect(find.textContaining('Practice statistics could not be loaded'), findsOneWidget);
    await scrollProgress(tester, find.text('1 reviews, forgotten 0 times in the last 30 days'));
  });

  testAppWidgets('dashboard: weak topics with their evidence', (tester, db) async {
    await pumpPrepLoopApp(tester, db, analytics: FakeAnalyticsRepository(data: sampleStats()));

    await scrollTo(tester, find.text('Percentage · Quantitative Aptitude'));
    expect(find.text('40% correct over 20 answers'), findsOneWidget);
    expect(find.text('Average · Quantitative Aptitude'), findsNothing); // 100 %: not weak
    await tester.tap(find.text('See progress'));
    await tester.pumpAndSettle();
    expect(find.text('Practice overview'), findsOneWidget);
  });

  testAppWidgets('dashboard: enough data and nothing weak says so', (tester, db) async {
    final stats = sampleStats();
    await pumpPrepLoopApp(
      tester,
      db,
      analytics: FakeAnalyticsRepository(
        data: PracticeAnalytics(
          timezone: stats.timezone,
          today: stats.today,
          days: 30,
          recentDays: 14,
          total: const AnswerCounts(answered: 12, correct: 12),
          sessions: 1,
          topics: [stats.topics[1]],
        ),
      ),
    );

    await scrollTo(tester, find.textContaining('No weak topics'));
    expect(find.textContaining('at 60% correct or better'), findsOneWidget);
  });

  testAppWidgets('plan: weak topic practice starts a 10-question topic session', (
    tester,
    db,
  ) async {
    final practice = FakePracticeRepository(serverNow: () => testNow);
    await pumpPrepLoopApp(
      tester,
      db,
      practice: practice,
      analytics: FakeAnalyticsRepository(data: sampleStats()),
    );

    await scrollTo(tester, find.text('Practise Percentage')); // below the momentum card
    expect(find.text('Practise Percentage'), findsOneWidget);
    expect(find.textContaining('40% correct over 20 answers · below 60%'), findsOneWidget);
    await tester.tap(
      find.descendant(
        of: find.ancestor(of: find.text('Practise Percentage'), matching: find.byType(Row)).first,
        matching: find.text('Start'),
      ),
    );
    await tester.pumpAndSettle();

    final request = practice.practiceRequests.single;
    expect((request.topicId, request.count), ('t-pct', 10));
    expect(find.text('Question 1 of 2'), findsOneWidget);
  });

  testAppWidgets('plan: fits the daily goal and suggests a due mock before the exam', (
    tester,
    db,
  ) async {
    final practice = FakePracticeRepository(serverNow: () => testNow)..mocks = [chslMock];
    await pumpPrepLoopApp(
      tester,
      db,
      practice: practice,
      studyProfile: StudyProfile(
        examCodes: const ['SSC_CHSL'],
        dailyStudyMinutes: 120,
        targetExamDate: today.addDays(30),
        onboardingCompletedAt: DateTime.utc(2026, 10, 1),
      ),
      analytics: FakeAnalyticsRepository(data: sampleStats()),
    );

    // Weak topic (15) + mock (60) fit in 120 minutes; the last mock was 3 days ago, so the
    // weekly mock is not due yet.
    // The weekly review prompt (real activity this week) sits above the plan.
    await scrollTo(tester, find.text('Practise Percentage'));
    expect(find.textContaining('Take a mock test'), findsNothing);
    await scrollTo(tester, find.text('About 15 min planned for your 120-minute daily goal.'));
  });

  testAppWidgets('plan: suggests the first mock test with its reason', (tester, db) async {
    final practice = FakePracticeRepository(serverNow: () => testNow)..mocks = [chslMock];
    await pumpPrepLoopApp(
      tester,
      db,
      practice: practice,
      studyProfile: StudyProfile(
        examCodes: const ['SSC_CHSL'],
        targetExamDate: today.addDays(30),
        onboardingCompletedAt: DateTime.utc(2026, 10, 1),
      ),
    );

    await scrollTo(
      tester,
      find.text('Take a mock test: SSC CHSL 2026 Tier-I'),
    ); // below the momentum card
    expect(find.text('Take a mock test: SSC CHSL 2026 Tier-I'), findsOneWidget);
    expect(
      find.textContaining('You have not taken a mock test yet. Exam in 30 days.'),
      findsOneWidget,
    );
    expect(find.text('Practise mixed questions'), findsOneWidget);
    expect(find.textContaining('Set a daily study goal'), findsOneWidget);
  });

  testAppWidgets('plan offline: revision only, and it says why', (tester, db) async {
    final analytics = FakeAnalyticsRepository()..offline = true;
    await pumpPrepLoopApp(tester, db, analytics: analytics);

    await scrollTo(
      tester,
      find.textContaining('Practice suggestions need a connection'),
    ); // below the momentum card
    expect(find.textContaining('Practice suggestions need a connection'), findsOneWidget);
    expect(find.text('Practise mixed questions'), findsNothing);
    expect(find.text('Nothing planned for today: no flashcards are due.'), findsOneWidget);
  });

  testAppWidgets('progress is localised in Hindi', (tester, db) async {
    await pumpPrepLoopApp(
      tester,
      db,
      deviceLocale: const Locale('hi'),
      analytics: FakeAnalyticsRepository(data: sampleStats()),
    );
    await scrollTo(tester, find.text('Percentage का अभ्यास करें')); // below the momentum card
    expect(find.text('Percentage का अभ्यास करें'), findsOneWidget);
    await tester.tap(
      find.descendant(of: find.byType(NavigationBar), matching: find.text('प्रगति')),
    );
    await tester.pumpAndSettle();

    expect(find.text('अभ्यास का सारांश'), findsOneWidget);
    expect(find.text('40 अभ्यास उत्तर'), findsOneWidget);
  });
}
