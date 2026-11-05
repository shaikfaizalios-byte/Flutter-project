import 'package:flutter_test/flutter_test.dart';
import 'package:preploop/core/exams/exam_catalog.dart';
import 'package:preploop/features/insights/domain/repeats.dart';

/// Pins the "seen in most papers" and small-sample lines SSC learners see today, so moving
/// the numbers into exam profiles can't change them unnoticed.
void main() {
  final rules = RepeatRules.of(builtInExams.first.profile);
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
        rules.seenInMostPapers(inPapers(present), papers(total)),
        expected,
        reason: '$present of $total',
      );
    }
  });

  test('fewer than 5 papers is a small sample, and no papers is not', () {
    expect(rules.isSmallSample(papers(0)), isFalse);
    expect(rules.isSmallSample(papers(1)), isTrue);
    expect(rules.isSmallSample(papers(4)), isTrue);
    expect(rules.isSmallSample(papers(5)), isFalse);
  });

  test('every built-in exam and the defaults use the same numbers', () {
    for (final profile in [defaultExamProfile, ...builtInExams.map((e) => e.profile)]) {
      expect(profile.repeatShare, 0.5);
      expect(profile.minPapers, 3);
      expect(profile.reliablePapers, 5);
    }
  });

  test('an exam with its own numbers gets its own rules', () {
    final strict = ExamOption.fromJson({
      'code': 'X',
      'name': 'X',
      'profile': {
        'kind': 'mcq',
        'options_per_question': 5,
        'repeat_share': 0.75,
        'min_papers': 4,
        'reliable_papers': 8,
        'counting_unit': 'session',
      },
    });
    final own = RepeatRules.of(strict.profile);
    expect(own.seenInMostPapers(inPapers(3), papers(4)), isTrue);
    expect(own.seenInMostPapers(inPapers(2), papers(4)), isFalse);
    expect(own.isSmallSample(papers(7)), isTrue);
    expect(strict.profile.optionsPerQuestion, 5);
    final saved = ExamOption.fromJson(strict.toJson());
    expect(saved.profile.repeatShare, 0.75);
  });

  test('an exam saved before profiles had them uses the defaults', () {
    final old = ExamOption.fromJson({'code': 'X', 'name': 'X'});
    expect(old.profile, same(defaultExamProfile));
  });
}
