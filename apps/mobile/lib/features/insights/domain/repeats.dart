import 'package:flutter/foundation.dart';

/// Questions of something per confirmed paper year.
@immutable
class YearCount {
  const YearCount(this.year, this.questions);

  factory YearCount.fromJson(Map<String, dynamic> json) =>
      YearCount(json['year'] as int, json['questions'] as int);

  final int year;
  final int questions;
}

/// How often something appeared in the learner's own papers (reviewed questions only).
@immutable
class RepeatCounts {
  const RepeatCounts({required this.questions, required this.papers, this.years = const []});

  factory RepeatCounts.fromJson(Map<String, dynamic> json) => RepeatCounts(
    questions: json['questions'] as int,
    papers: json['papers'] as int,
    years: [
      for (final y in json['years'] as List<dynamic>) YearCount.fromJson(y as Map<String, dynamic>),
    ],
  );

  final int questions;
  final int papers;

  /// Only papers with a confirmed date.
  final List<YearCount> years;
}

@immutable
class PatternRepeat {
  const PatternRepeat({
    required this.patternId,
    required this.name,
    required this.confirmed,
    required this.unreviewed,
  });

  factory PatternRepeat.fromJson(Map<String, dynamic> json) => PatternRepeat(
    patternId: json['pattern_id'] as String,
    name: json['name'] as String,
    confirmed: RepeatCounts.fromJson(json['confirmed'] as Map<String, dynamic>),
    unreviewed: json['unreviewed'] as int,
  );

  final String patternId;
  final String name;
  final RepeatCounts confirmed;
  final int unreviewed;
}

@immutable
class TopicRepeat {
  const TopicRepeat({
    required this.topicId,
    required this.subject,
    required this.name,
    required this.confirmed,
    required this.unreviewed,
    this.patterns = const [],
    this.withoutPattern = 0,
  });

  factory TopicRepeat.fromJson(Map<String, dynamic> json) => TopicRepeat(
    topicId: json['topic_id'] as String,
    subject: json['subject'] as String,
    name: json['name'] as String,
    confirmed: RepeatCounts.fromJson(json['confirmed'] as Map<String, dynamic>),
    unreviewed: json['unreviewed'] as int,
    patterns: [
      for (final p in json['patterns'] as List<dynamic>)
        PatternRepeat.fromJson(p as Map<String, dynamic>),
    ],
    withoutPattern: json['without_pattern'] as int,
  );

  final String topicId;
  final String subject;
  final String name;
  final RepeatCounts confirmed;
  final int unreviewed;
  final List<PatternRepeat> patterns;
  final int withoutPattern;
}

@immutable
class SimilarQuestion {
  const SimilarQuestion({
    required this.questionId,
    required this.documentFilename,
    required this.stemExcerpt,
    required this.verified,
    this.examYear,
    this.questionNumber,
  });

  factory SimilarQuestion.fromJson(Map<String, dynamic> json) => SimilarQuestion(
    questionId: json['question_id'] as String,
    documentFilename: json['document_filename'] as String,
    examYear: json['exam_year'] as int?,
    questionNumber: json['question_number'] as int?,
    stemExcerpt: json['stem_excerpt'] as String,
    verified: json['verified'] as bool,
  );

  final String questionId;
  final String documentFilename;
  final int? examYear;
  final int? questionNumber;
  final String stemExcerpt;
  final bool verified;
}

/// Questions worded alike (numbers ignored) in different papers: a wording-based suggestion.
@immutable
class SimilarGroup {
  const SimilarGroup({
    required this.papers,
    required this.questions,
    this.subject,
    this.topicName,
    this.years = const [],
  });

  factory SimilarGroup.fromJson(Map<String, dynamic> json) => SimilarGroup(
    subject: json['subject'] as String?,
    topicName: json['topic_name'] as String?,
    papers: json['papers'] as int,
    years: [for (final y in json['years'] as List<dynamic>) y as int],
    questions: [
      for (final q in json['questions'] as List<dynamic>)
        SimilarQuestion.fromJson(q as Map<String, dynamic>),
    ],
  );

  final String? subject;
  final String? topicName;
  final int papers;
  final List<int> years;
  final List<SimilarQuestion> questions;
}

/// Which papers the numbers are based on.
@immutable
class PapersBasis {
  const PapersBasis({
    required this.total,
    required this.dated,
    required this.undated,
    this.years = const [],
  });

  factory PapersBasis.fromJson(Map<String, dynamic> json) => PapersBasis(
    total: json['total'] as int,
    dated: json['dated'] as int,
    undated: json['undated'] as int,
    years: [for (final y in json['years'] as List<dynamic>) y as int],
  );

  final int total;
  final int dated;
  final int undated;
  final List<int> years;
}

/// Starter papers: what the shared bank holds for one exam (verified questions only).
@immutable
class SharedBankExam {
  const SharedBankExam({required this.examCode, required this.papers, required this.questions});

  factory SharedBankExam.fromJson(Map<String, dynamic> json) => SharedBankExam(
    examCode: json['exam_code'] as String,
    papers: json['papers'] as int,
    questions: json['questions'] as int,
  );

  final String examCode;
  final int papers;
  final int questions;
}

/// A topic of the exam (name only).
@immutable
class TopicRef {
  const TopicRef({required this.topicId, required this.subject, required this.name});

  factory TopicRef.fromJson(Map<String, dynamic> json) => TopicRef(
    topicId: json['topic_id'] as String,
    subject: json['subject'] as String,
    name: json['name'] as String,
  );

  final String topicId;
  final String subject;
  final String name;
}

/// A question type of a topic that appeared, never seen in these papers.
@immutable
class PatternGap {
  const PatternGap({required this.topicName, required this.name});

  factory PatternGap.fromJson(Map<String, dynamic> json) =>
      PatternGap(topicName: json['topic_name'] as String, name: json['name'] as String);

  final String topicName;
  final String name;
}

/// What these papers did not ask (for one exam). Not a prediction.
@immutable
class NotRepeated {
  const NotRepeated({
    this.notSeen = const [],
    this.patternsNotSeen = const [],
    this.questionsWithoutTopic = 0,
  });

  factory NotRepeated.fromJson(Map<String, dynamic>? json) => json == null
      ? const NotRepeated()
      : NotRepeated(
          notSeen: [
            for (final t in json['not_seen'] as List<dynamic>)
              TopicRef.fromJson(t as Map<String, dynamic>),
          ],
          patternsNotSeen: [
            for (final g in json['patterns_not_seen'] as List<dynamic>)
              PatternGap.fromJson(g as Map<String, dynamic>),
          ],
          questionsWithoutTopic: json['questions_without_topic'] as int,
        );

  /// Syllabus topics with no question in these papers.
  final List<TopicRef> notSeen;
  final List<PatternGap> patternsNotSeen;

  /// Questions without a topic yet: some may belong to [notSeen] topics.
  final int questionsWithoutTopic;
}

@immutable
class RepeatsReport {
  const RepeatsReport({
    required this.papers,
    this.topics = const [],
    this.similarGroups = const [],
    this.examCode,
    this.notRepeated = const NotRepeated(),
  });

  factory RepeatsReport.fromJson(Map<String, dynamic> json) => RepeatsReport(
    examCode: json['exam_code'] as String?,
    papers: PapersBasis.fromJson(json['papers'] as Map<String, dynamic>),
    topics: [
      for (final t in json['topics'] as List<dynamic>)
        TopicRepeat.fromJson(t as Map<String, dynamic>),
    ],
    similarGroups: [
      for (final g in json['similar_groups'] as List<dynamic>)
        SimilarGroup.fromJson(g as Map<String, dynamic>),
    ],
    notRepeated: NotRepeated.fromJson(json['not_repeated'] as Map<String, dynamic>?),
  );

  final String? examCode;
  final PapersBasis papers;
  final List<TopicRepeat> topics;
  final List<SimilarGroup> similarGroups;
  final NotRepeated notRepeated;

  /// Topics that came in exactly one of these papers (reviewed questions only).
  List<TopicRepeat> get seenOnce => [
    for (final t in topics)
      if (t.confirmed.papers == 1) t,
  ];
}

/// Named, shown-in-the-app rule for calling something "seen in most papers". A product
/// choice, not research: at least [minPapers] papers imported and present in at least
/// [share] of them.
abstract final class RepeatRules {
  static const minPapers = 3;
  static const share = 0.5;

  /// Below this many papers, counts are a small sample (a topic seen 2-3 times can be
  /// chance). A product choice, shown in the UI, not a statistical test.
  static const reliablePapers = 5;

  static bool isSmallSample(PapersBasis basis) => basis.total > 0 && basis.total < reliablePapers;

  static bool seenInMostPapers(RepeatCounts counts, PapersBasis basis) =>
      basis.total >= minPapers && counts.papers / basis.total >= share;
}
