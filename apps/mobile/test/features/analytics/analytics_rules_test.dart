import 'package:flutter_test/flutter_test.dart';
import 'package:preploop/core/utils/calendar_date.dart';
import 'package:preploop/features/analytics/domain/analytics_models.dart';
import 'package:preploop/features/analytics/domain/study_plan.dart';
import 'package:preploop/features/analytics/domain/weak_topics.dart';

PracticeAnalytics practice(List<TopicStats> topics, {int answered = 0}) => PracticeAnalytics(
  timezone: 'Asia/Kolkata',
  today: CalendarDate(2026, 10, 13),
  days: 30,
  recentDays: 14,
  total: AnswerCounts(answered: answered, correct: 0),
  sessions: 1,
  topics: topics,
);

TopicStats topicStats(
  String name,
  int answered,
  int correct, {
  String subject = 'Quantitative Aptitude',
  int recentAnswered = 0,
  int recentCorrect = 0,
}) => TopicStats(
  topicId: 'id-$name',
  name: name,
  subject: subject,
  counts: AnswerCounts(
    answered: answered,
    correct: correct,
    recentAnswered: recentAnswered,
    recentCorrect: recentCorrect,
  ),
);

void main() {
  group('weak topics', () {
    test('low accuracy is weak only with enough answers', () {
      final result = assessTopics(
        practice([
          topicStats('Percentage', 10, 5), // 50 % over 10 → weak
          topicStats('Ratio', 9, 0), // 0 % but only 9 answers → not judged
          topicStats('Average', 20, 12), // 60 % → not weak (threshold is "below 60 %")
        ]),
        const RevisionStats(),
      );

      final byName = {for (final t in result) t.name: t};
      expect(byName['Percentage']!.reasons, [WeakReason.lowAccuracy]);
      expect(byName['Ratio']!.isWeak, isFalse);
      expect(byName['Ratio']!.hasEnoughData, isFalse);
      expect(byName['Average']!.isWeak, isFalse);
      expect(byName['Average']!.hasEnoughData, isTrue);
      expect(result.first.name, 'Percentage'); // weak topics first
    });

    test('often-forgotten flashcards make a topic weak (matched by name, any case)', () {
      final result = assessTopics(
        practice([topicStats('Synonyms', 4, 4, subject: 'English Language')]),
        const RevisionStats(
          byTopic: [
            TopicRecall(subject: 'english language', topic: 'SYNONYMS', reviews: 5, forgot: 2),
            TopicRecall(subject: 'History', topic: 'Mughals', reviews: 4, forgot: 4),
          ],
        ),
      );

      final synonyms = result.firstWhere((t) => t.name == 'Synonyms');
      expect(synonyms.reasons, [WeakReason.oftenForgotten]);
      expect((synonyms.reviews, synonyms.forgot, synonyms.topicId), (5, 2, 'id-Synonyms'));
      final mughals = result.firstWhere((t) => t.name == 'Mughals');
      expect(mughals.isWeak, isFalse); // 4 reviews < minimum 5
      expect(mughals.topicId, isNull); // known only from flashcards
    });

    test('weakest first: lowest accuracy, then highest forget rate', () {
      final result = assessTopics(
        practice([topicStats('A', 10, 5), topicStats('B', 10, 2), topicStats('C', 10, 9)]),
        const RevisionStats(),
      );
      expect(result.map((t) => t.name), ['B', 'A', 'C']);
    });

    test('trend needs enough recent and earlier answers', () {
      AnswerCounts c(int ra, int rc, int oa, int oc) =>
          AnswerCounts(answered: ra + oa, correct: rc + oc, recentAnswered: ra, recentCorrect: rc);
      expect(trendOf(c(5, 4, 5, 2)), Trend.improving); // 80 % vs 40 %
      expect(trendOf(c(5, 2, 5, 4)), Trend.declining);
      expect(trendOf(c(5, 3, 5, 3)), Trend.steady);
      expect(trendOf(c(4, 4, 10, 0)), isNull);
      expect(trendOf(c(10, 4, 4, 0)), isNull);
    });

    test('no data at all gives no topics (nothing invented)', () {
      expect(assessTopics(null, const RevisionStats()), isEmpty);
    });
  });

  group('study plan', () {
    final today = CalendarDate(2026, 10, 13);
    const weakA = TopicAssessment(
      subject: 'Quantitative Aptitude',
      name: 'Percentage',
      topicId: 't1',
      counts: AnswerCounts(answered: 12, correct: 5),
      reasons: [WeakReason.lowAccuracy],
    );
    const weakB = TopicAssessment(
      subject: 'English Language',
      name: 'Synonyms',
      topicId: 't2',
      counts: AnswerCounts(answered: 10, correct: 4),
      reasons: [WeakReason.lowAccuracy],
    );
    const weakC = TopicAssessment(
      subject: 'History',
      name: 'Mughals',
      topicId: 't3',
      counts: AnswerCounts(answered: 10, correct: 3),
      reasons: [WeakReason.lowAccuracy],
    );
    const mock = AvailableMock(
      code: 'SSC_CHSL_2026_TIER1',
      name: 'SSC CHSL 2026 Tier-I',
      minutes: 60,
    );

    test('priority: revision, weak topics (max 2), then a due mock', () {
      final plan = buildStudyPlan(
        today: today,
        dueCards: 12,
        overdueCards: 3,
        topics: [weakA, weakB, weakC],
        practiceDataAvailable: true,
        answeredTotal: 40,
        mock: mock,
      );
      expect(plan.items.map((i) => i.kind), [
        PlanItemKind.revision,
        PlanItemKind.weakTopic,
        PlanItemKind.weakTopic,
        PlanItemKind.mockTest,
      ]);
      expect(plan.items.first.minutes, 12);
      expect((plan.items.first.reason as CardsDue).overdue, 3);
      expect(plan.items[1].topicId, 't1');
      expect((plan.items.last.reason as MockDue).daysSinceLastMock, isNull);
      expect(plan.plannedMinutes, 12 + 15 + 15 + 60);
    });

    test('the daily goal limits the plan; the first item always stays', () {
      final plan = buildStudyPlan(
        today: today,
        dueCards: 40,
        overdueCards: 0,
        topics: [weakA],
        practiceDataAvailable: true,
        answeredTotal: 40,
        dailyMinutes: 30,
        mock: mock,
      );
      expect(plan.items.map((i) => i.kind), [PlanItemKind.revision]); // 40 min > 30, kept alone
      final fits = buildStudyPlan(
        today: today,
        dueCards: 5,
        overdueCards: 0,
        topics: [weakA],
        practiceDataAvailable: true,
        answeredTotal: 40,
        dailyMinutes: 30,
        mock: mock,
      );
      expect(fits.items.map((i) => i.kind), [PlanItemKind.revision, PlanItemKind.weakTopic]);
      expect(fits.plannedMinutes, 20);
    });

    test('small revision blocks take at least 5 minutes', () {
      final plan = buildStudyPlan(
        today: today,
        dueCards: 2,
        overdueCards: 0,
        topics: const [],
        practiceDataAvailable: false,
        answeredTotal: 0,
      );
      expect(plan.items.single.minutes, 5);
    });

    test('without practice data: mixed practice to find weak topics', () {
      final plan = buildStudyPlan(
        today: today,
        dueCards: 0,
        overdueCards: 0,
        topics: const [],
        practiceDataAvailable: true,
        answeredTotal: 0,
      );
      expect(plan.items.single.kind, PlanItemKind.practiceMixed);
      expect(plan.items.single.reason, isA<NoPracticeDataYet>());

      final noneWeak = buildStudyPlan(
        today: today,
        dueCards: 0,
        overdueCards: 0,
        topics: const [],
        practiceDataAvailable: true,
        answeredTotal: 50,
      );
      expect(noneWeak.items.single.reason, isA<NoWeakTopicFound>());
    });

    test('weak topics known only from flashcards are not offered as topic practice', () {
      const cardsOnly = TopicAssessment(
        subject: 'History',
        name: 'Mughals',
        reviews: 6,
        forgot: 4,
        reasons: [WeakReason.oftenForgotten],
      );
      final plan = buildStudyPlan(
        today: today,
        dueCards: 0,
        overdueCards: 0,
        topics: const [cardsOnly],
        practiceDataAvailable: true,
        answeredTotal: 30,
      );
      expect(plan.items.single.kind, PlanItemKind.practiceMixed);
    });

    test('offline: only device revision is planned', () {
      final plan = buildStudyPlan(
        today: today,
        dueCards: 3,
        overdueCards: 0,
        topics: [weakA],
        practiceDataAvailable: false,
        answeredTotal: 0,
        mock: mock,
      );
      expect(plan.items.map((i) => i.kind), [PlanItemKind.revision]);
      expect(plan.practiceDataAvailable, isFalse);
    });

    test('mock cadence: weekly within 60 days of the exam, otherwise every 14 days', () {
      StudyPlan plan({required CalendarDate lastMock, CalendarDate? exam}) => buildStudyPlan(
        today: today,
        dueCards: 0,
        overdueCards: 0,
        topics: const [],
        practiceDataAvailable: true,
        answeredTotal: 10,
        mock: mock,
        lastMockOn: lastMock,
        examDate: exam,
      );
      bool hasMock(StudyPlan p) => p.items.any((i) => i.kind == PlanItemKind.mockTest);

      final examSoon = today.addDays(30);
      expect(hasMock(plan(lastMock: today.addDays(-6), exam: examSoon)), isFalse);
      final soon = plan(lastMock: today.addDays(-7), exam: examSoon);
      expect(hasMock(soon), isTrue);
      final reason = soon.items.last.reason as MockDue;
      expect((reason.daysSinceLastMock, reason.daysToExam), (7, 30));

      expect(hasMock(plan(lastMock: today.addDays(-10))), isFalse); // no exam date
      expect(hasMock(plan(lastMock: today.addDays(-14))), isTrue);
      // A past exam date counts as no exam date.
      expect(hasMock(plan(lastMock: today.addDays(-10), exam: today.addDays(-1))), isFalse);
    });
  });
}
