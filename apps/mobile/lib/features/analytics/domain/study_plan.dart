import 'package:flutter/foundation.dart';

import '../../../core/utils/calendar_date.dart';
import 'weak_topics.dart';

/// Rules for the daily plan (deterministic; no AI). See docs/analytics.md.
abstract final class PlanRules {
  /// Estimated minutes per flashcard review.
  static const minutesPerCard = 1;

  /// Minimum time block for revision.
  static const minRevisionMinutes = 5;

  /// Questions per suggested practice block, and its estimated length.
  static const practiceQuestions = 10;
  static const practiceMinutes = 15;

  /// Weak topics suggested per day at most.
  static const maxWeakTopics = 2;

  /// Suggest a mock this often (days) when the exam is within [examSoonDays], otherwise
  /// at [mockEveryDaysOtherwise].
  static const examSoonDays = 60;
  static const mockEveryDaysExamSoon = 7;
  static const mockEveryDaysOtherwise = 14;
}

enum PlanItemKind { revision, weakTopic, practiceMixed, mockTest }

/// Why an item is in the plan (rendered as a localised sentence).
sealed class PlanReason {
  const PlanReason();
}

class CardsDue extends PlanReason {
  const CardsDue(this.due, this.overdue);

  final int due;
  final int overdue;
}

class WeakTopicEvidence extends PlanReason {
  const WeakTopicEvidence(this.topic);

  final TopicAssessment topic;
}

class NoPracticeDataYet extends PlanReason {
  const NoPracticeDataYet();
}

class NoWeakTopicFound extends PlanReason {
  const NoWeakTopicFound();
}

class MockDue extends PlanReason {
  const MockDue({required this.daysSinceLastMock, required this.daysToExam});

  /// Null when no mock has been taken yet.
  final int? daysSinceLastMock;
  final int? daysToExam;
}

@immutable
class PlanItem {
  const PlanItem({
    required this.kind,
    required this.minutes,
    required this.reason,
    this.topicId,
    this.topicName,
    this.mockCode,
    this.mockName,
  });

  final PlanItemKind kind;
  final int minutes;
  final PlanReason reason;
  final String? topicId;
  final String? topicName;
  final String? mockCode;
  final String? mockName;
}

@immutable
class AvailableMock {
  const AvailableMock({required this.code, required this.name, required this.minutes});

  final String code;
  final String name;
  final int minutes;
}

@immutable
class StudyPlan {
  const StudyPlan({
    required this.items,
    required this.budgetMinutes,
    required this.practiceDataAvailable,
  });

  final List<PlanItem> items;

  /// The learner's daily goal, if set.
  final int? budgetMinutes;

  /// False when practice statistics could not be loaded (offline): the plan then
  /// contains only on-device revision.
  final bool practiceDataAvailable;

  int get plannedMinutes => items.fold(0, (sum, i) => sum + i.minutes);
}

/// Builds today's plan in priority order — due revision, weak topics (or mixed practice
/// when there is not enough data), then a mock test when one is due — and keeps items
/// that fit the daily goal (the first item always stays).
StudyPlan buildStudyPlan({
  required CalendarDate today,
  required int dueCards,
  required int overdueCards,
  required List<TopicAssessment> topics,
  required bool practiceDataAvailable,
  required int answeredTotal,
  int? dailyMinutes,
  CalendarDate? examDate,
  AvailableMock? mock,
  CalendarDate? lastMockOn,
}) {
  final candidates = <PlanItem>[];
  if (dueCards > 0) {
    candidates.add(
      PlanItem(
        kind: PlanItemKind.revision,
        minutes: dueCards * PlanRules.minutesPerCard < PlanRules.minRevisionMinutes
            ? PlanRules.minRevisionMinutes
            : dueCards * PlanRules.minutesPerCard,
        reason: CardsDue(dueCards, overdueCards),
      ),
    );
  }

  if (practiceDataAvailable) {
    final weak = topics
        .where((t) => t.isWeak && t.topicId != null)
        .take(PlanRules.maxWeakTopics)
        .toList();
    for (final topic in weak) {
      candidates.add(
        PlanItem(
          kind: PlanItemKind.weakTopic,
          minutes: PlanRules.practiceMinutes,
          reason: WeakTopicEvidence(topic),
          topicId: topic.topicId,
          topicName: topic.name,
        ),
      );
    }
    if (weak.isEmpty) {
      candidates.add(
        PlanItem(
          kind: PlanItemKind.practiceMixed,
          minutes: PlanRules.practiceMinutes,
          reason: answeredTotal == 0 ? const NoPracticeDataYet() : const NoWeakTopicFound(),
        ),
      );
    }

    final daysToExam = examDate == null ? null : today.daysUntil(examDate);
    final upcoming = daysToExam != null && daysToExam >= 0 ? daysToExam : null;
    if (mock != null) {
      final every = upcoming != null && upcoming <= PlanRules.examSoonDays
          ? PlanRules.mockEveryDaysExamSoon
          : PlanRules.mockEveryDaysOtherwise;
      final since = lastMockOn?.daysUntil(today);
      if (since == null || since >= every) {
        candidates.add(
          PlanItem(
            kind: PlanItemKind.mockTest,
            minutes: mock.minutes,
            reason: MockDue(daysSinceLastMock: since, daysToExam: upcoming),
            mockCode: mock.code,
            mockName: mock.name,
          ),
        );
      }
    }
  }

  final items = <PlanItem>[];
  var used = 0;
  for (final item in candidates) {
    if (dailyMinutes == null || items.isEmpty || used + item.minutes <= dailyMinutes) {
      items.add(item);
      used += item.minutes;
    }
  }
  return StudyPlan(
    items: items,
    budgetMinutes: dailyMinutes,
    practiceDataAvailable: practiceDataAvailable,
  );
}
