import 'package:flutter/foundation.dart';

import '../../../core/utils/calendar_date.dart';
import '../../analytics/domain/analytics_models.dart';
import '../../analytics/domain/weak_topics.dart';
import 'mastery.dart';

/// How much of one subject's syllabus the learner has worked on.
@immutable
class SubjectCoverage {
  const SubjectCoverage({
    required this.name,
    required this.topics,
    required this.practised,
    required this.strong,
  });

  final String name;
  final int topics;

  /// Topics with any practice, flashcard review or "revised" mark (not "not started").
  final int practised;

  /// Topics that are strong or mastered (see [MasteryRules]).
  final int strong;
}

/// Readiness = syllabus coverage plus the evidence behind it. Deliberately no score, grade or
/// pass probability: PrepLoop has no data that could support one (docs/analytics.md).
@immutable
class Readiness {
  const Readiness({
    required this.subjects,
    this.recentAnswers,
    this.recentCorrect = 0,
    this.mocksInWindow,
    this.latestMock,
    this.daysToExam,
  });

  final List<SubjectCoverage> subjects;

  /// Practice answers in the last [AnalyticsRules.recentDays] days; null when practice data
  /// could not be loaded (offline), never a made-up 0.
  final int? recentAnswers;
  final int recentCorrect;

  /// Mock tests submitted in the last [AnalyticsRules.windowDays] days; null offline.
  final int? mocksInWindow;
  final MockResultView? latestMock;

  /// Days until the exam date the learner set; null without one (or once it has passed).
  final int? daysToExam;

  int get topics => subjects.fold(0, (sum, s) => sum + s.topics);
  int get practised => subjects.fold(0, (sum, s) => sum + s.practised);
  int get strong => subjects.fold(0, (sum, s) => sum + s.strong);

  /// The learner has syllabus topics for this exam (coverage can be shown).
  bool get hasSyllabus => topics > 0;
}

/// Builds readiness from the syllabus topics' mastery ([subjects]: syllabus topics only, so
/// the learner's own extra concept topics don't inflate coverage) and practice statistics.
Readiness buildReadiness({
  required List<SubjectMastery> subjects,
  required CalendarDate today,
  PracticeAnalytics? practice,
  CalendarDate? examDate,
}) {
  final recentFrom = today.addDays(-(AnalyticsRules.recentDays - 1));
  final windowFrom = today.addDays(-(AnalyticsRules.windowDays - 1));
  final recent = practice?.daily.where((d) => d.date.compareTo(recentFrom) >= 0);
  final daysToExam = examDate == null ? null : today.daysUntil(examDate);
  return Readiness(
    subjects: [
      for (final s in subjects)
        if (s.topics.isNotEmpty)
          SubjectCoverage(
            name: s.name,
            topics: s.topics.length,
            practised: s.topics.where((t) => t.level != MasteryLevel.notStarted).length,
            strong: s.strongOrBetter,
          ),
    ],
    recentAnswers: recent?.fold<int>(0, (sum, d) => sum + d.answered),
    recentCorrect: recent?.fold<int>(0, (sum, d) => sum + d.correct) ?? 0,
    mocksInWindow: practice?.mocks.where((m) => m.localDate.compareTo(windowFrom) >= 0).length,
    latestMock: practice?.mocks.firstOrNull,
    daysToExam: daysToExam != null && daysToExam >= 0 ? daysToExam : null,
  );
}
