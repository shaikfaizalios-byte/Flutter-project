/// A recall check after a focus session ("brain dump"): the learner writes what they remember
/// without looking, then compares with the material. Retrieving from memory strengthens it
/// more than re-reading (the testing effect); the self-rating only chooses the advice shown.
abstract final class RecallRules {
  /// Minutes focused before a session ended early still offers a recall check.
  static const minMinutes = 5;
}

/// How much the learner remembered, compared with their notes or papers.
enum RecallAmount { almostAll, most, half, little }
