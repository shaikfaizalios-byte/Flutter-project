import 'package:flutter_test/flutter_test.dart';
import 'package:preploop/features/analytics/domain/analytics_models.dart';
import 'package:preploop/features/exams/domain/exam_topics.dart';
import 'package:preploop/features/mastery/domain/mastery.dart';

import '../../helpers/fake_analytics.dart';

AnswerCounts answers(int answered, int correct) =>
    AnswerCounts(answered: answered, correct: correct);

void main() {
  group('masteryLevel', () {
    test('nothing done is not started; a revised mark alone is learning', () {
      expect(masteryLevel(counts: answers(0, 0)), MasteryLevel.notStarted);
      expect(masteryLevel(counts: answers(0, 0), revised: true), MasteryLevel.learning);
      expect(masteryLevel(counts: answers(0, 0), reviews: 2), MasteryLevel.learning);
    });

    test('under the minimum answers stays learning, however accurate', () {
      expect(masteryLevel(counts: answers(9, 9)), MasteryLevel.learning);
    });

    test('enough answers: accuracy decides practising or strong', () {
      expect(masteryLevel(counts: answers(10, 5)), MasteryLevel.practising);
      expect(masteryLevel(counts: answers(10, 6)), MasteryLevel.strong);
    });

    test('often forgotten flashcards keep a topic practising', () {
      expect(masteryLevel(counts: answers(20, 18), reviews: 5, forgot: 2), MasteryLevel.practising);
    });

    test('mastered needs answers, accuracy and the revised mark', () {
      expect(masteryLevel(counts: answers(25, 22), revised: true), MasteryLevel.mastered);
      expect(masteryLevel(counts: answers(25, 22)), MasteryLevel.strong);
      expect(masteryLevel(counts: answers(24, 24), revised: true), MasteryLevel.strong);
      expect(masteryLevel(counts: answers(25, 21), revised: true), MasteryLevel.strong);
    });
  });

  test('examMastery groups the syllabus by subject and matches statistics', () {
    const topics = [
      ExamTopic(id: 't1', subject: 'General Awareness', name: 'History', own: true),
      ExamTopic(id: 't2', subject: 'General Engineering', name: 'Thermodynamics', own: true),
      ExamTopic(id: 't3', subject: 'General Awareness', name: 'Polity', own: true, completed: true),
    ];
    final practice = PracticeAnalytics(
      timezone: 'Asia/Kolkata',
      today: emptyAnalytics().today,
      days: 30,
      recentDays: 14,
      total: answers(40, 30),
      sessions: 3,
      topics: [
        TopicStats(topicId: 't1', name: 'History', subject: 'X', counts: answers(12, 11)),
        // Matched by name when the id differs.
        TopicStats(
          topicId: 'other',
          name: 'thermodynamics',
          subject: 'general engineering',
          counts: answers(10, 3),
        ),
      ],
    );

    final result = examMastery(
      topics: topics,
      practice: practice,
      conceptTopics: const {
        'General Awareness': ['History', 'Economy'],
        'Reasoning': ['Analogy'],
      },
    );

    expect(
      [for (final s in result) s.name],
      ['General Awareness', 'General Engineering', 'Reasoning'],
    );
    final awareness = result.first;
    expect(
      [for (final t in awareness.topics) (t.name, t.level)],
      [
        ('History', MasteryLevel.strong),
        ('Polity', MasteryLevel.learning), // revised, no answers yet
        ('Economy', MasteryLevel.notStarted), // from a concept only
      ],
    );
    expect(awareness.strongOrBetter, 1);
    expect(awareness.levelCounts, [1, 1, 0, 1, 0]);
    expect(result[1].topics.single.level, MasteryLevel.practising);
    expect(result[1].topics.single.topicId, 't2');
    expect(result[2].topics.single.topicId, isNull);
  });
}
