import 'package:flutter/foundation.dart';

import '../../analytics/domain/analytics_models.dart';
import '../../analytics/domain/weak_topics.dart';
import '../../exams/domain/exam_topics.dart';

/// Thresholds for a topic's mastery level. Named here and shown in the UI, so learners know
/// what each level is based on. Product choices, not validated research (like
/// [AnalyticsRules], whose window and weak thresholds they reuse).
abstract final class MasteryRules {
  /// Practice answers (in the analysis window) before accuracy decides the level.
  static const minAnswers = AnalyticsRules.minAnswers;

  /// From this accuracy (with enough answers) a topic is strong.
  static const strongAccuracy = AnalyticsRules.weakAccuracy;

  /// Answers and accuracy needed for "mastered" (plus marking the topic as revised).
  static const masteredAnswers = 25;
  static const masteredAccuracy = 0.85;
}

/// From nothing done yet to mastered. Ordered: later levels are further along.
enum MasteryLevel { notStarted, learning, practising, strong, mastered }

/// One topic's level with the evidence behind it.
@immutable
class TopicMastery {
  const TopicMastery({
    required this.subject,
    required this.name,
    required this.level,
    this.topicId,
    this.counts = const AnswerCounts(answered: 0, correct: 0),
    this.reviews = 0,
    this.forgot = 0,
    this.revised = false,
  });

  final String subject;
  final String name;

  /// Server topic id (to practise it); null for topics known only from concepts.
  final String? topicId;
  final MasteryLevel level;
  final AnswerCounts counts;
  final int reviews;
  final int forgot;

  /// The learner marked the topic as revised (topics screen).
  final bool revised;

  /// Practice answers still needed before accuracy is judged.
  int get answersToJudge =>
      counts.answered >= MasteryRules.minAnswers ? 0 : MasteryRules.minAnswers - counts.answered;
}

/// The level from practice answers, flashcard recall and the "revised" mark:
/// - not started: nothing answered or reviewed, not marked revised;
/// - learning: fewer than [MasteryRules.minAnswers] answers;
/// - practising: enough answers but accuracy below [MasteryRules.strongAccuracy], or the
///   topic's flashcards are often forgotten (see [AnalyticsRules]);
/// - strong: enough answers at or above [MasteryRules.strongAccuracy];
/// - mastered: [MasteryRules.masteredAnswers]+ answers at [MasteryRules.masteredAccuracy]+,
///   not often forgotten, and marked revised.
MasteryLevel masteryLevel({
  required AnswerCounts counts,
  int reviews = 0,
  int forgot = 0,
  bool revised = false,
}) {
  if (counts.answered == 0 && reviews == 0 && !revised) return MasteryLevel.notStarted;
  if (counts.answered < MasteryRules.minAnswers) return MasteryLevel.learning;
  final accuracy = counts.accuracy!;
  final oftenForgotten =
      reviews >= AnalyticsRules.minReviews && forgot / reviews >= AnalyticsRules.weakForgetRate;
  if (accuracy < MasteryRules.strongAccuracy || oftenForgotten) return MasteryLevel.practising;
  if (counts.answered >= MasteryRules.masteredAnswers &&
      accuracy >= MasteryRules.masteredAccuracy &&
      revised) {
    return MasteryLevel.mastered;
  }
  return MasteryLevel.strong;
}

/// A subject's topics with their levels (syllabus order).
@immutable
class SubjectMastery {
  const SubjectMastery({required this.name, required this.topics});

  final String name;
  final List<TopicMastery> topics;

  /// Topics at each level (index = [MasteryLevel.index]).
  List<int> get levelCounts {
    final counts = List.filled(MasteryLevel.values.length, 0);
    for (final t in topics) {
      counts[t.level.index]++;
    }
    return counts;
  }

  /// Topics that are strong or mastered.
  int get strongOrBetter => topics.where((t) => t.level.index >= MasteryLevel.strong.index).length;
}

String _key(String subject, String name) =>
    '${subject.trim().toLowerCase()}\u001f${name.trim().toLowerCase()}';

/// Levels for an exam's syllabus [topics], plus topics known only from the learner's own
/// concepts ([conceptTopics]: subject → topics). Practice statistics are matched by topic id,
/// else by subject and name (ignoring case); flashcard recall by subject and name. Subjects
/// keep the order in which they first appear.
List<SubjectMastery> examMastery({
  required List<ExamTopic> topics,
  PracticeAnalytics? practice,
  RevisionStats revision = const RevisionStats(),
  Map<String, List<String>> conceptTopics = const {},
}) {
  final byId = {for (final t in practice?.topics ?? const <TopicStats>[]) t.topicId: t};
  final byName = {
    for (final t in practice?.topics ?? const <TopicStats>[]) _key(t.subject, t.name): t,
  };
  final recall = {for (final r in revision.byTopic) _key(r.subject, r.topic): r};
  final subjects = <String, (String, List<TopicMastery>)>{};
  final seen = <String>{};

  void add({required String subject, required String name, String? topicId, bool revised = false}) {
    final key = _key(subject, name);
    if (!seen.add(key)) return;
    final stats = byId[topicId] ?? byName[key];
    final cards = recall[key];
    final counts = stats?.counts ?? const AnswerCounts(answered: 0, correct: 0);
    final mastery = TopicMastery(
      subject: subject,
      name: name,
      topicId: topicId ?? stats?.topicId,
      counts: counts,
      reviews: cards?.reviews ?? 0,
      forgot: cards?.forgot ?? 0,
      revised: revised,
      level: masteryLevel(
        counts: counts,
        reviews: cards?.reviews ?? 0,
        forgot: cards?.forgot ?? 0,
        revised: revised,
      ),
    );
    subjects.putIfAbsent(subject.trim().toLowerCase(), () => (subject.trim(), [])).$2.add(mastery);
  }

  for (final t in topics) {
    add(subject: t.subject, name: t.name, topicId: t.id, revised: t.completed);
  }
  for (final entry in conceptTopics.entries) {
    for (final name in entry.value) {
      add(subject: entry.key, name: name);
    }
  }
  return [for (final (name, list) in subjects.values) SubjectMastery(name: name, topics: list)];
}
