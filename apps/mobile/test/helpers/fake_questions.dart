import 'dart:typed_data';

import 'package:preploop/core/errors/app_failure.dart';
import 'package:preploop/core/utils/calendar_date.dart';
import 'package:preploop/features/concepts/domain/concept.dart';
import 'package:preploop/features/question_bank/data/questions_repository.dart';
import 'package:preploop/features/question_bank/domain/question.dart';

BankQuestion bankQuestion({
  String id = 'q1',
  int number = 1,
  String stem = 'What is 20% of 150?',
  String section = 'Quantitative Aptitude',
  String exam = 'SSC_CHSL',
  List<String> options = const ['20', '30', '40', '50'],
  int? answer = 2,
  VerificationStatus status = VerificationStatus.unverified,
  List<String> issues = const [],
  QuestionOrigin origin = QuestionOrigin.source,
  String? documentId = 'doc1',
  String topicStatus = 'unassigned',
  TopicRef? topic,
  Passage? passage,
  String? subject,
  String? explanation,
  ContentLanguage language = ContentLanguage.english,
  AiProvenance? ai,
  AiExplanation? aiExplanation,
  String? topicSuggestedBy,
  String? topicSuggestionReason,
  PatternRef? pattern,
  String patternStatus = 'unassigned',
  String? patternSuggestionReason,
  List<QuestionFigure> figures = const [],
  String answerType = 'choice',
  String? typedAnswer,
  String? sharedSource,
  bool readByAi = false,
}) => BankQuestion(
  id: id,
  readByAi: readByAi,
  readOnly: sharedSource != null,
  sharedSource: sharedSource,
  origin: origin,
  examCode: exam,
  section: section,
  subject: subject,
  stem: stem,
  language: language,
  options: [
    for (final (i, text) in options.indexed)
      QuestionOption(position: i + 1, label: '${i + 1}', text: text),
  ],
  issues: [for (final code in issues) QuestionIssue(code: code, detail: '', resolved: false)],
  status: status,
  sourcePages: const [1],
  imageDependent: issues.contains('image_dependent'),
  topicStatus: topicStatus,
  topic: topic,
  documentId: documentId,
  documentFilename: documentId == null ? null : 'chsl-2024.pdf',
  sourceNumber: number,
  passage: passage,
  correctPosition: answer,
  answerSource: answer == null ? null : 'answer_key',
  explanation: explanation,
  ai: ai,
  aiExplanation: aiExplanation,
  topicSuggestedBy: topicSuggestedBy,
  topicSuggestionReason: topicSuggestionReason,
  pattern: pattern,
  patternStatus: patternStatus,
  patternSuggestionReason: patternSuggestionReason,
  figures: figures,
  answerType: answerType,
  typedAnswer: typedAnswer,
);

const samplePatterns = [
  PatternRef(id: 'p-income', topicId: 't-percent', name: 'Income, expenditure and savings'),
  PatternRef(id: 'p-votes', topicId: 't-percent', name: 'Votes and marks'),
  PatternRef(id: 'p-share', topicId: 't-ratio', name: 'Dividing an amount'),
];

const sampleTopics = [
  TopicRef(id: 't-percent', subject: 'Quantitative Aptitude', name: 'Percentage'),
  TopicRef(id: 't-ratio', subject: 'Quantitative Aptitude', name: 'Ratio and Proportion'),
];

/// In-memory question bank that mimics the server's filters and review rules.
class FakeQuestionsRepository implements QuestionsRepository {
  FakeQuestionsRepository([List<BankQuestion> questions = const []])
    : questions = {for (final q in questions) q.id: q};

  final Map<String, BankQuestion> questions;
  final queries = <QuestionQuery>[];
  final edits = <(String, Map<String, Object?>)>[];
  AppFailure? listFailure;
  int resegmentCalls = 0;
  ParseSummary summary = const ParseSummary(
    segmentationStatus: 'completed',
    questionsFound: 2,
    verified: 0,
    rejected: 0,
    withOpenIssues: 1,
    missingAnswers: 1,
    imageDependent: 0,
    sections: ['Quantitative Aptitude'],
    documentIssues: [QuestionIssue(code: 'numbering_gaps', detail: 'Missing: 3', resolved: false)],
  );
  String pageTextValue = 'Q.1 What is 20% of 150?\n(1) 20 (2) 30 (3) 40 (4) 50';

  @override
  Future<(List<BankQuestion>, int)> list(QuestionQuery query) async {
    queries.add(query);
    if (listFailure != null) throw listFailure!;
    final items = questions.values.where((q) {
      if (query.documentId != null && q.documentId != query.documentId) return false;
      if (query.examCode != null && q.examCode != query.examCode) return false;
      if (query.status != null && q.status != query.status) return false;
      if (query.hasIssues == true && q.openIssues.isEmpty) return false;
      final text = query.text.trim().toLowerCase();
      if (text.isNotEmpty && !q.stem.toLowerCase().contains(text)) return false;
      return true;
    }).toList();
    return (items, items.length);
  }

  @override
  Future<BankQuestion> get(String id) async =>
      questions[id] ?? (throw const ServerFailure(statusCode: 404, code: 'not_found'));

  @override
  Future<BankQuestion> update(String id, QuestionEdit edit) async {
    final json = edit.toJson();
    edits.add((id, json));
    final current = questions[id]!;
    final options =
        (json['options'] as List<Object?>?)
            ?.map((o) => (o! as Map<String, Object?>)['text']! as String)
            .toList() ??
        [for (final o in current.options) o.text];
    final answer = json.containsKey('correct_option_position')
        ? json['correct_option_position'] as int?
        : current.correctPosition;
    final contentIssues = [
      if (answer == null) 'missing_answer',
      if (options.length != 4) 'incomplete_options',
    ];
    final status = switch (json['verification_status']) {
      'verified' => VerificationStatus.verified,
      'rejected' => VerificationStatus.rejected,
      _ => current.status,
    };
    if (status == VerificationStatus.verified && contentIssues.isNotEmpty) {
      throw const ServerFailure(statusCode: 422, code: 'cannot_verify');
    }
    final updated = bankQuestion(
      id: id,
      number: current.sourceNumber ?? 1,
      stem: json['stem'] as String? ?? current.stem,
      options: options,
      answer: answer,
      status: status,
      issues: status == VerificationStatus.verified ? const [] : contentIssues,
      origin: current.origin,
      documentId: current.documentId,
      topic: json.containsKey('topic_id')
          ? sampleTopics.where((t) => t.id == json['topic_id']).firstOrNull
          : current.topic,
      topicStatus: json['topic_id'] != null ? 'confirmed' : current.topicStatus,
      pattern: json.containsKey('pattern_id')
          ? samplePatterns.where((p) => p.id == json['pattern_id']).firstOrNull
          : current.pattern,
      patternStatus: json['pattern_id'] != null ? 'confirmed' : 'unassigned',
    );
    questions[id] = updated;
    return updated;
  }

  final topicRequests = <String?>[];

  @override
  Future<List<TopicRef>> topics({String? examCode}) async {
    topicRequests.add(examCode);
    return sampleTopics;
  }

  @override
  Future<ParseSummary> parseSummary(String documentId) async => summary;

  @override
  Future<ParseSummary> resegment(String documentId) async {
    resegmentCalls++;
    return summary;
  }

  final figureRequests = <(String, String)>[];
  final acceptCalls = <String>[];

  /// A valid 1x1 PNG, so `Image.memory` can decode it in widget tests.
  static final pngPixel = Uint8List.fromList(const [
    0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, //
    0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01, 0x08, 0x06, 0x00, 0x00, 0x00, 0x1F,
    0x15, 0xC4, 0x89, 0x00, 0x00, 0x00, 0x0B, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0xF8,
    0x0F, 0x04, 0x00, 0x09, 0xFB, 0x03, 0xFD, 0xFB, 0x5E, 0x6B, 0x2B, 0x00, 0x00, 0x00, 0x00,
    0x49, 0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
  ]);

  final paperDates = <(String, int?, CalendarDate?, int?)>[];

  @override
  Future<List<PatternRef>> patterns() async => samplePatterns;

  @override
  Future<void> setPaperDate(String documentId, {int? year, CalendarDate? date, int? shift}) async {
    paperDates.add((documentId, year, date, shift));
    summary = ParseSummary(
      segmentationStatus: summary.segmentationStatus,
      questionsFound: summary.questionsFound,
      verified: summary.verified,
      rejected: summary.rejected,
      withOpenIssues: summary.withOpenIssues,
      missingAnswers: summary.missingAnswers,
      imageDependent: summary.imageDependent,
      sections: summary.sections,
      documentIssues: summary.documentIssues,
      topicsSuggested: summary.topicsSuggested,
      topicsUnassigned: summary.topicsUnassigned,
      paperDate: PaperDate(year: year, date: date, shift: shift, status: 'confirmed'),
    );
  }

  final verifyCleanCalls = <String>[];

  @override
  Future<({int verified, int left})> verifyClean(String documentId) async {
    verifyCleanCalls.add(documentId);
    var verified = 0;
    var left = 0;
    for (final q in questions.values.toList()) {
      if (q.documentId != documentId || q.status != VerificationStatus.unverified) continue;
      final clean = q.issues.every((i) => i.resolved) && q.correctPosition != null;
      if (clean) {
        questions[q.id] = q.copyWith(status: VerificationStatus.verified);
        verified++;
      } else {
        left++;
      }
    }
    return (verified: verified, left: left);
  }

  @override
  Future<({int topics, int patterns})> acceptSuggestedTopics(String documentId) async {
    acceptCalls.add(documentId);
    var accepted = 0;
    var patterns = 0;
    for (final q in questions.values.toList()) {
      if (q.documentId == documentId &&
          q.topicStatus == 'suggested' &&
          q.status != VerificationStatus.rejected) {
        questions[q.id] = q.copyWith(
          topicStatus: 'confirmed',
          topicSuggestedBy: () => null,
          topicSuggestionReason: () => null,
        );
        accepted++;
        if (q.patternStatus == 'suggested') patterns++;
      }
    }
    return (topics: accepted, patterns: patterns);
  }

  @override
  Future<Uint8List> figure(String questionId, String figureId) async {
    figureRequests.add((questionId, figureId));
    return pngPixel;
  }

  @override
  Future<String> pageText(String documentId, int page) async => pageTextValue;
}
