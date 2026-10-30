import '../../practice/domain/offline_practice.dart' show typedAnswerMatches;
import '../../question_bank/domain/question.dart';

/// How a question of a paper is answered when solving it.
enum SolveKind {
  /// Pick one of its options.
  choice,

  /// Type a short answer that is compared with the paper's (numbers by value).
  typed,

  /// Write an answer in your own words (Q&A notes); checked by AI or against the paper's.
  written,

  /// A multiple-choice question whose options weren't read from the PDF: it needs review.
  unreadable,
}

SolveKind solveKind(BankQuestion question) => switch (question.answerType) {
  'typed' => SolveKind.typed,
  'written' => SolveKind.written,
  _ when question.options.isEmpty => SolveKind.unreadable,
  _ => SolveKind.choice,
};

/// The question depends on a figure; the AI only sees its text, so it can't check answers.
bool hasFigure(BankQuestion question) => question.imageDependent || question.figures.isNotEmpty;

/// A paper's questions in printed order, without the ones a reviewer rejected.
List<BankQuestion> solvableQuestions(Iterable<BankQuestion> questions) {
  final kept = [
    for (final q in questions)
      if (q.status != VerificationStatus.rejected) q,
  ];
  // Stable: questions without a number keep their place after the numbered ones.
  final order = {for (final (i, q) in kept.indexed) q.id: i};
  kept.sort((a, b) {
    final x = a.sourceNumber;
    final y = b.sourceNumber;
    if (x != null && y != null && x != y) return x.compareTo(y);
    if ((x == null) != (y == null)) return x == null ? 1 : -1;
    return order[a.id]!.compareTo(order[b.id]!);
  });
  return kept;
}

/// Whether the chosen option is right; null when the paper gives no answer key.
bool? choiceCorrect(BankQuestion question, int position) {
  final correct = question.correctPosition;
  return correct == null ? null : correct == position;
}

/// Whether the typed answer matches the paper's; null when the paper gives none.
bool? typedCorrect(BankQuestion question, String answer) {
  final expected = question.typedAnswer;
  return expected == null ? null : typedAnswerMatches(expected, answer);
}
