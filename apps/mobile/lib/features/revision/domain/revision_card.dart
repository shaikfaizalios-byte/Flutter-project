import 'package:flutter/foundation.dart';

import '../../../core/utils/calendar_date.dart';
import 'revision_schedule.dart';

enum CardKind {
  /// The learner's own concept notes.
  concept,

  /// A verified question from an imported paper (never AI-generated).
  question,
}

enum CardReason {
  added('added'),
  incorrectAnswer('incorrect_answer');

  const CardReason(this.code);

  final String code;

  static CardReason fromCode(String code) =>
      values.firstWhere((r) => r.code == code, orElse: () => CardReason.added);
}

/// A flashcard on the revision schedule, with its content resolved for display.
@immutable
class RevisionCard {
  const RevisionCard({
    required this.id,
    required this.kind,
    required this.front,
    required this.back,
    required this.schedule,
    required this.reason,
    required this.createdAt,
    this.conceptId,
    this.questionId,
    this.examCode,
    this.subject,
    this.topic,
    this.sourceFilename,
    this.sourcePage,
    this.lastReviewedAt,
  });

  final String id;
  final CardKind kind;

  /// Concept cards: the concept title. Question cards: the stem with its options.
  final String front;

  /// Concept cards: the notes (may be empty). Question cards: the correct option and
  /// the explanation when the paper had one.
  final String back;
  final CardSchedule schedule;
  final CardReason reason;
  final DateTime createdAt;
  final String? conceptId;
  final String? questionId;
  final String? examCode;
  final String? subject;
  final String? topic;
  final String? sourceFilename;
  final int? sourcePage;
  final DateTime? lastReviewedAt;

  CalendarDate get dueOn => schedule.dueOn;
}

/// What happened when questions were offered for revision.
@immutable
class AddQuestionsResult {
  const AddQuestionsResult({this.added = 0, this.alreadyAdded = 0, this.notEligible = 0});

  final int added;
  final int alreadyAdded;

  /// Unreviewed, AI-generated, image-dependent or unanswered questions are not turned
  /// into cards.
  final int notEligible;
}

/// Due and upcoming counts for the dashboard and the revision screen.
@immutable
class RevisionOverview {
  const RevisionOverview({
    required this.dueToday,
    required this.overdue,
    required this.total,
    required this.upcoming,
    this.nextDue,
  });

  /// Cards to revise today, including overdue ones.
  final int dueToday;
  final int overdue;
  final int total;

  /// Cards due on each of the next 7 days (index 0 = tomorrow).
  final List<int> upcoming;

  /// Earliest due date after today, when nothing is due today.
  final CalendarDate? nextDue;

  static RevisionOverview of(List<RevisionCard> cards, CalendarDate today) {
    var due = 0;
    var overdue = 0;
    final upcoming = List.filled(7, 0);
    CalendarDate? next;
    for (final card in cards) {
      final days = today.daysUntil(card.dueOn);
      if (days <= 0) {
        due++;
        if (days < 0) overdue++;
      } else {
        if (days <= 7) upcoming[days - 1]++;
        if (next == null || card.dueOn.compareTo(next) < 0) next = card.dueOn;
      }
    }
    return RevisionOverview(
      dueToday: due,
      overdue: overdue,
      total: cards.length,
      upcoming: upcoming,
      nextDue: next,
    );
  }
}
