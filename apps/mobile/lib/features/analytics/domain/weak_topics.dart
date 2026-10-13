import 'package:flutter/foundation.dart';

import 'analytics_models.dart';

/// Thresholds for calling a topic weak. Named here and shown in the UI so learners know
/// what a judgement is based on (see docs/analytics.md).
abstract final class AnalyticsRules {
  /// Practice answers needed in a topic before its accuracy is judged.
  static const minAnswers = 10;

  /// Below this accuracy (with enough answers) a topic is weak.
  static const weakAccuracy = 0.60;

  /// Flashcard reviews needed in a topic before its forget rate is judged.
  static const minReviews = 5;

  /// At or above this share of "Forgot" ratings (with enough reviews) a topic is weak.
  static const weakForgetRate = 0.40;

  /// Answers needed both in the recent window and before it to show a trend.
  static const minTrendAnswers = 5;

  /// Accuracy change (percentage points / 100) that counts as improving or declining.
  static const trendDelta = 0.10;

  /// Days of history analysed.
  static const windowDays = 30;

  /// Recent window for trends.
  static const recentDays = 14;
}

enum Trend { improving, steady, declining }

enum WeakReason { lowAccuracy, oftenForgotten }

/// A topic with its evidence. [reasons] is empty for topics that are not weak.
@immutable
class TopicAssessment {
  const TopicAssessment({
    required this.subject,
    required this.name,
    required this.reasons,
    this.topicId,
    this.counts = const AnswerCounts(answered: 0, correct: 0),
    this.reviews = 0,
    this.forgot = 0,
    this.trend,
  });

  final String subject;
  final String name;

  /// Server topic id (needed to start topic practice); null for topics known only
  /// from the learner's own concept cards.
  final String? topicId;
  final AnswerCounts counts;
  final int reviews;
  final int forgot;
  final Trend? trend;
  final List<WeakReason> reasons;

  bool get isWeak => reasons.isNotEmpty;

  /// Enough evidence for at least one judgement.
  bool get hasEnoughData =>
      counts.answered >= AnalyticsRules.minAnswers || reviews >= AnalyticsRules.minReviews;

  double? get forgetRate => reviews == 0 ? null : forgot / reviews;
}

/// Trend from recent vs earlier answers, or null without enough of both.
Trend? trendOf(AnswerCounts c) {
  if (c.recentAnswered < AnalyticsRules.minTrendAnswers ||
      c.olderAnswered < AnalyticsRules.minTrendAnswers) {
    return null;
  }
  final delta = c.recentCorrect / c.recentAnswered - c.olderCorrect / c.olderAnswered;
  if (delta >= AnalyticsRules.trendDelta) return Trend.improving;
  if (delta <= -AnalyticsRules.trendDelta) return Trend.declining;
  return Trend.steady;
}

/// Combines practice accuracy (server) and flashcard recall (device) per topic.
/// Topics are matched by subject and name, ignoring case. Weak topics come first, the
/// weakest (lowest accuracy, then highest forget rate) at the top.
List<TopicAssessment> assessTopics(PracticeAnalytics? practice, RevisionStats revision) {
  String key(String subject, String name) =>
      '${subject.trim().toLowerCase()}\u001f${name.trim().toLowerCase()}';
  final recall = {for (final r in revision.byTopic) key(r.subject, r.topic): r};
  final seen = <String>{};
  final result = <TopicAssessment>[];

  TopicAssessment assess({
    required String subject,
    required String name,
    String? topicId,
    AnswerCounts counts = const AnswerCounts(answered: 0, correct: 0),
    TopicRecall? cards,
  }) {
    final reviews = cards?.reviews ?? 0;
    final forgot = cards?.forgot ?? 0;
    final accuracy = counts.accuracy;
    return TopicAssessment(
      subject: subject,
      name: name,
      topicId: topicId,
      counts: counts,
      reviews: reviews,
      forgot: forgot,
      trend: trendOf(counts),
      reasons: [
        if (counts.answered >= AnalyticsRules.minAnswers &&
            accuracy != null &&
            accuracy < AnalyticsRules.weakAccuracy)
          WeakReason.lowAccuracy,
        if (reviews >= AnalyticsRules.minReviews &&
            forgot / reviews >= AnalyticsRules.weakForgetRate)
          WeakReason.oftenForgotten,
      ],
    );
  }

  for (final topic in practice?.topics ?? const <TopicStats>[]) {
    final k = key(topic.subject, topic.name);
    seen.add(k);
    result.add(
      assess(
        subject: topic.subject,
        name: topic.name,
        topicId: topic.topicId,
        counts: topic.counts,
        cards: recall[k],
      ),
    );
  }
  for (final cards in revision.byTopic) {
    final k = key(cards.subject, cards.topic);
    if (seen.add(k)) result.add(assess(subject: cards.subject, name: cards.topic, cards: cards));
  }

  int severity(TopicAssessment a, TopicAssessment b) {
    if (a.isWeak != b.isWeak) return a.isWeak ? -1 : 1;
    final accuracy = (a.counts.accuracy ?? 2).compareTo(b.counts.accuracy ?? 2);
    if (accuracy != 0) return accuracy;
    final forget = (b.forgetRate ?? -1).compareTo(a.forgetRate ?? -1);
    if (forget != 0) return forget;
    return '${a.subject}${a.name}'.toLowerCase().compareTo('${b.subject}${b.name}'.toLowerCase());
  }

  return result..sort(severity);
}
