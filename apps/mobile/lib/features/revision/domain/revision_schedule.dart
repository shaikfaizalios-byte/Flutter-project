import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../../../core/utils/calendar_date.dart';

/// How well the learner recalled a card.
enum RecallRating { again, hard, good, easy }

/// The learner's revision ladder: review days counted from the day a card is added
/// ("Day 1 / 4 / 7" by default). Stored as a setting, never hard-coded in screens.
@immutable
class RevisionSettings {
  const RevisionSettings({this.dayOffsets = defaultDayOffsets});

  static const defaultDayOffsets = [1, 4, 7];
  static const maxSteps = 8;
  static const maxDay = 365;

  /// Strictly increasing day numbers, each 1–[maxDay].
  final List<int> dayOffsets;

  /// True when [offsets] is a usable ladder.
  static bool isValid(List<int> offsets) {
    if (offsets.isEmpty || offsets.length > maxSteps) return false;
    for (var i = 0; i < offsets.length; i++) {
      if (offsets[i] < 1 || offsets[i] > maxDay) return false;
      if (i > 0 && offsets[i] <= offsets[i - 1]) return false;
    }
    return true;
  }

  /// Sorts and de-duplicates; null if the result is not a valid ladder.
  static List<int>? normalize(Iterable<int> offsets) {
    final sorted = offsets.toSet().toList()..sort();
    return isValid(sorted) ? sorted : null;
  }

  /// `"1,4,7"` ↔ settings; invalid stored values fall back to the default.
  static RevisionSettings parse(String? stored) {
    final values = stored?.split(',').map((s) => int.tryParse(s.trim())).toList();
    if (values == null || values.contains(null)) return const RevisionSettings();
    final offsets = values.cast<int>();
    return isValid(offsets) ? RevisionSettings(dayOffsets: offsets) : const RevisionSettings();
  }

  String serialize() => dayOffsets.join(',');

  @override
  bool operator ==(Object other) =>
      other is RevisionSettings && listEquals(other.dayOffsets, dayOffsets);

  @override
  int get hashCode => Object.hashAll(dayOffsets);
}

/// Where a card is on its ladder and when it is next due.
@immutable
class CardSchedule {
  const CardSchedule({
    required this.step,
    required this.gapDays,
    required this.dueOn,
    this.reviewCount = 0,
    this.lapseCount = 0,
  });

  /// Index of the ladder review that is scheduled next. A value equal to the ladder
  /// length (or more, after the ladder was shortened) means the card has
  /// "graduated" and its gaps grow from there.
  final int step;

  /// Days between the previous review (or adding the card) and [dueOn].
  final int gapDays;
  final CalendarDate dueOn;
  final int reviewCount;
  final int lapseCount;

  bool isDue(CalendarDate today) => dueOn.compareTo(today) <= 0;

  bool isOverdue(CalendarDate today) => dueOn.compareTo(today) < 0;

  @override
  bool operator ==(Object other) =>
      other is CardSchedule &&
      other.step == step &&
      other.gapDays == gapDays &&
      other.dueOn == dueOn &&
      other.reviewCount == reviewCount &&
      other.lapseCount == lapseCount;

  @override
  int get hashCode => Object.hash(step, gapDays, dueOn, reviewCount, lapseCount);

  @override
  String toString() => 'CardSchedule(step $step, gap $gapDays, due $dueOn)';
}

/// Spaced-revision rules (pure; see docs/revision.md).
///
/// - Adding a card schedules it on the first ladder day (Day 1 = tomorrow).
/// - **Good** moves to the next ladder day: the gap is the distance between ladder days
///   (1 → 4 → 7 gives gaps of 3 and 3), counted from the day of the review.
///   After the last ladder day the gap doubles, at least the last ladder day, at most
///   [maxGapDays].
/// - **Easy** moves on like Good with a longer gap (× 1.5, rounded up, at least one day more).
/// - **Hard** stays on the same step with half the Good gap (at least 1 day).
/// - **Again** (forgotten) goes back to the start of the ladder.
abstract final class RevisionScheduler {
  static const maxGapDays = 180;

  static CardSchedule initial(CalendarDate addedOn, RevisionSettings settings) {
    final first = settings.dayOffsets.first;
    return CardSchedule(step: 0, gapDays: first, dueOn: addedOn.addDays(first));
  }

  /// Gap (days) that each rating would give, for button labels.
  static Map<RecallRating, int> previewGaps(CardSchedule card, RevisionSettings settings) => {
    for (final rating in RecallRating.values) rating: _next(card, rating, settings).$2,
  };

  static CardSchedule review(
    CardSchedule card,
    RecallRating rating,
    CalendarDate today,
    RevisionSettings settings,
  ) {
    final (step, gap) = _next(card, rating, settings);
    return CardSchedule(
      step: step,
      gapDays: gap,
      dueOn: today.addDays(gap),
      reviewCount: card.reviewCount + 1,
      lapseCount: card.lapseCount + (rating == RecallRating.again ? 1 : 0),
    );
  }

  static (int step, int gap) _next(
    CardSchedule card,
    RecallRating rating,
    RevisionSettings settings,
  ) {
    final offsets = settings.dayOffsets;
    final graduated = offsets.length;
    final step = math.min(card.step, graduated);
    final good = _goodGap(step, card.gapDays, offsets);
    return switch (rating) {
      RecallRating.again => (0, offsets.first),
      RecallRating.hard => (step, math.max(1, good ~/ 2)),
      RecallRating.good => (math.min(step + 1, graduated), good),
      RecallRating.easy => (
        math.min(step + 1, graduated),
        math.min(maxGapDays, math.max(good + 1, (good * 3 + 1) ~/ 2)),
      ),
    };
  }

  static int _goodGap(int step, int lastGap, List<int> offsets) {
    if (step + 1 < offsets.length) return offsets[step + 1] - offsets[step];
    return math.min(maxGapDays, math.max(lastGap * 2, offsets.last));
  }
}
