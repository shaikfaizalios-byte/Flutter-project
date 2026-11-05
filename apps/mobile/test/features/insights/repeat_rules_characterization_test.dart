import 'package:flutter_test/flutter_test.dart';
import 'package:preploop/features/insights/domain/repeats.dart';

/// Pins the "seen in most papers" and small-sample lines SSC learners see today, so moving
/// the numbers into exam profiles can't change them unnoticed.
void main() {
  PapersBasis papers(int total) => PapersBasis(total: total, dated: total, undated: 0, years: []);
  RepeatCounts inPapers(int count) => RepeatCounts(questions: count, papers: count);

  test('seen in most papers needs 3 papers and half of them', () {
    const cases = [
      // papers imported, papers with the topic, seen in most
      (2, 2, false),
      (3, 1, false),
      (3, 2, true),
      (4, 1, false),
      (4, 2, true),
      (5, 2, false),
      (5, 3, true),
      (6, 3, true),
    ];
    for (final (total, present, expected) in cases) {
      expect(
        RepeatRules.seenInMostPapers(inPapers(present), papers(total)),
        expected,
        reason: '$present of $total',
      );
    }
  });

  test('fewer than 5 papers is a small sample, and no papers is not', () {
    expect(RepeatRules.isSmallSample(papers(0)), isFalse);
    expect(RepeatRules.isSmallSample(papers(1)), isTrue);
    expect(RepeatRules.isSmallSample(papers(4)), isTrue);
    expect(RepeatRules.isSmallSample(papers(5)), isFalse);
  });
}
