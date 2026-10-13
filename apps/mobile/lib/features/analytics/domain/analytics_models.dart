import 'package:flutter/foundation.dart';

import '../../../core/utils/calendar_date.dart';

/// Attempted answers and correct ones, overall and in the recent window.
@immutable
class AnswerCounts {
  const AnswerCounts({
    required this.answered,
    required this.correct,
    this.recentAnswered = 0,
    this.recentCorrect = 0,
  });

  factory AnswerCounts.fromJson(Map<String, dynamic> json) => AnswerCounts(
    answered: json['answered'] as int,
    correct: json['correct'] as int,
    recentAnswered: json['recent_answered'] as int? ?? 0,
    recentCorrect: json['recent_correct'] as int? ?? 0,
  );

  final int answered;
  final int correct;
  final int recentAnswered;
  final int recentCorrect;

  /// Null when nothing was answered (never a made-up 0 %).
  double? get accuracy => answered == 0 ? null : correct / answered;

  int get olderAnswered => answered - recentAnswered;
  int get olderCorrect => correct - recentCorrect;
}

@immutable
class SubjectStats {
  const SubjectStats({required this.name, required this.counts});

  final String name;
  final AnswerCounts counts;
}

@immutable
class TopicStats {
  const TopicStats({
    required this.topicId,
    required this.name,
    required this.subject,
    required this.counts,
  });

  final String topicId;
  final String name;
  final String subject;
  final AnswerCounts counts;
}

@immutable
class DailyStats {
  const DailyStats({required this.date, required this.answered, required this.correct});

  final CalendarDate date;
  final int answered;
  final int correct;
}

@immutable
class MockResultView {
  const MockResultView({
    required this.sessionId,
    required this.localDate,
    required this.score,
    required this.maxScore,
    this.name,
    this.markingNote,
    this.timeUp = false,
  });

  final String sessionId;
  final String? name;
  final CalendarDate localDate;
  final double score;
  final double maxScore;
  final String? markingNote;

  /// Submitted automatically when time ran out.
  final bool timeUp;
}

/// Server answer statistics (`GET /analytics/overview`).
@immutable
class PracticeAnalytics {
  const PracticeAnalytics({
    required this.timezone,
    required this.today,
    required this.days,
    required this.recentDays,
    required this.total,
    required this.sessions,
    this.subjects = const [],
    this.topics = const [],
    this.daily = const [],
    this.mocks = const [],
  });

  factory PracticeAnalytics.fromJson(Map<String, dynamic> json) {
    List<Map<String, dynamic>> list(String key) =>
        (json[key] as List<dynamic>).cast<Map<String, dynamic>>();
    CalendarDate date(Object? value) => CalendarDate.tryParse(value as String?)!;
    return PracticeAnalytics(
      timezone: json['timezone'] as String,
      today: date(json['today']),
      days: json['days'] as int,
      recentDays: json['recent_days'] as int,
      total: AnswerCounts(answered: json['answered'] as int, correct: json['correct'] as int),
      sessions: json['sessions'] as int,
      subjects: [
        for (final s in list('subjects'))
          SubjectStats(name: s['name'] as String, counts: AnswerCounts.fromJson(s)),
      ],
      topics: [
        for (final t in list('topics'))
          TopicStats(
            topicId: t['topic_id'] as String,
            name: t['name'] as String,
            subject: t['subject'] as String,
            counts: AnswerCounts.fromJson(t),
          ),
      ],
      daily: [
        for (final d in list('daily'))
          DailyStats(
            date: date(d['date']),
            answered: d['answered'] as int,
            correct: d['correct'] as int,
          ),
      ],
      mocks: [
        for (final m in list('mocks'))
          MockResultView(
            sessionId: m['session_id'] as String,
            name: m['name'] as String?,
            localDate: date(m['local_date']),
            score: (m['score'] as num).toDouble(),
            maxScore: (m['max_score'] as num).toDouble(),
            markingNote: m['marking_note'] as String?,
            timeUp: m['submit_reason'] == 'time_up',
          ),
      ],
    );
  }

  final String timezone;
  final CalendarDate today;
  final int days;
  final int recentDays;
  final AnswerCounts total;
  final int sessions;
  final List<SubjectStats> subjects;
  final List<TopicStats> topics;
  final List<DailyStats> daily;
  final List<MockResultView> mocks;
}

/// Flashcard reviews for one subject/topic (device data).
@immutable
class TopicRecall {
  const TopicRecall({
    required this.subject,
    required this.topic,
    required this.reviews,
    required this.forgot,
  });

  final String subject;
  final String topic;
  final int reviews;
  final int forgot;

  double? get forgetRate => reviews == 0 ? null : forgot / reviews;
}

/// Flashcard review activity in the analysis window (device data).
@immutable
class RevisionStats {
  const RevisionStats({
    this.reviews = 0,
    this.forgot = 0,
    this.byTopic = const [],
    this.daily = const {},
  });

  final int reviews;
  final int forgot;
  final List<TopicRecall> byTopic;

  /// Reviews per local calendar day.
  final Map<CalendarDate, int> daily;
}
