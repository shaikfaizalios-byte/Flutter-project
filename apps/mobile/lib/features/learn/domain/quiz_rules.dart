/// How a knowledge check is judged (shown in the UI so learners can trust the verdict).
/// Product choices, not validated research.
abstract final class QuizRules {
  /// Share correct to say the learner knows the topic.
  static const knowIt = 0.8;

  /// Share correct to say the learner knows parts of it.
  static const partly = 0.5;
}

enum QuizVerdict { knowsIt, partly, learnFirst }

/// The verdict for [correct] answers out of [total] questions.
QuizVerdict quizVerdict(int correct, int total) {
  if (total <= 0) return QuizVerdict.learnFirst;
  final share = correct / total;
  if (share >= QuizRules.knowIt) return QuizVerdict.knowsIt;
  if (share >= QuizRules.partly) return QuizVerdict.partly;
  return QuizVerdict.learnFirst;
}
