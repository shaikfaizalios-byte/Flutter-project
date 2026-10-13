import 'package:preploop/core/errors/app_failure.dart';
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
}) => BankQuestion(
  id: id,
  origin: origin,
  examCode: exam,
  section: section,
  stem: stem,
  language: ContentLanguage.english,
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
);

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
    );
    questions[id] = updated;
    return updated;
  }

  @override
  Future<List<TopicRef>> topics() async => sampleTopics;

  @override
  Future<ParseSummary> parseSummary(String documentId) async => summary;

  @override
  Future<ParseSummary> resegment(String documentId) async {
    resegmentCalls++;
    return summary;
  }

  @override
  Future<String> pageText(String documentId, int page) async => pageTextValue;
}
