import 'package:preploop/core/errors/app_failure.dart';
import 'package:preploop/features/ai/data/ai_repository.dart';
import 'package:preploop/features/concepts/domain/concept.dart';
import 'package:preploop/features/question_bank/domain/question.dart';

import 'fake_questions.dart';

/// Stand-in for the AI API. Disabled by default (as on a server without a key). When a
/// [questions] fake is given, AI actions update it so screens refresh like the real API.
class FakeAiRepository implements AiRepository {
  FakeAiRepository({this.enabled = false, this.questions});

  bool enabled;
  FakeQuestionsRepository? questions;

  /// Thrown by the next AI action (then cleared).
  AppFailure? failure;
  String draftText = 'AI: 20/100 × 150 = 30.';
  bool confident = true;
  TopicRef? topicToSuggest = sampleTopics.first;
  int generatedCount = 2;
  int rejectedCount = 0;

  final calls = <String>[];
  final generatedFor = <(String basis, ContentLanguage language, int count)>[];
  final reports = <(String questionId, ReportReason reason, String note)>[];

  void _maybeFail() {
    final f = failure;
    failure = null;
    if (f != null) throw f;
  }

  void _update(String id, BankQuestion Function(BankQuestion q) change) {
    final store = questions;
    if (store != null && store.questions.containsKey(id)) {
      store.questions[id] = change(store.questions[id]!);
    }
  }

  @override
  Future<AiStatus> status() async =>
      enabled ? const AiStatus(enabled: true, model: 'fake-model') : AiStatus.off;

  @override
  Future<AiExplanation> draftExplanation(String questionId) async {
    calls.add('draft:$questionId');
    _maybeFail();
    final draft = AiExplanation(
      id: 'e-$questionId',
      questionId: questionId,
      text: draftText,
      status: AiDraftStatus.draft,
      modelConfident: confident,
      model: 'fake-model',
    );
    _update(questionId, (q) => q.copyWith(aiExplanation: () => draft));
    return draft;
  }

  @override
  Future<AiExplanation> reviewExplanation(String id, {required bool approve, String? text}) async {
    calls.add('${approve ? 'approve' : 'reject'}:$id${text == null ? '' : ':$text'}');
    _maybeFail();
    final questionId = id.substring(2);
    final reviewed = AiExplanation(
      id: id,
      questionId: questionId,
      text: text ?? draftText,
      status: approve ? AiDraftStatus.approved : AiDraftStatus.rejected,
      modelConfident: confident,
      model: 'fake-model',
      edited: text != null,
    );
    _update(questionId, (q) => q.copyWith(aiExplanation: () => approve ? reviewed : null));
    return reviewed;
  }

  GeneratedQuestions _generated() => GeneratedQuestions(
    created: [
      for (var i = 1; i <= generatedCount; i++)
        bankQuestion(
          id: 'ai$i',
          stem: 'AI question $i?',
          origin: QuestionOrigin.ai,
          documentId: null,
          ai: const AiProvenance(provider: 'fake', model: 'fake-model', promptVersion: 'p9.1'),
        ),
    ],
    rejected: rejectedCount,
  );

  @override
  Future<GeneratedQuestions> generateFromQuestion(
    BankQuestion source, {
    required ContentLanguage language,
    int count = 3,
  }) async {
    generatedFor.add(('question:${source.id}', language, count));
    _maybeFail();
    return _generated();
  }

  @override
  Future<GeneratedQuestions> generateFromConcept(
    Concept concept, {
    required ContentLanguage language,
    int count = 3,
  }) async {
    generatedFor.add(('concept:${concept.title}', language, count));
    _maybeFail();
    return _generated();
  }

  @override
  Future<(BankQuestion, bool)> suggestTopic(String questionId) async {
    calls.add('topic:$questionId');
    _maybeFail();
    final topic = topicToSuggest;
    _update(
      questionId,
      (q) => topic == null
          ? q
          : q.copyWith(topic: () => topic, topicStatus: 'suggested', topicSuggestedBy: () => 'ai'),
    );
    final updated = questions?.questions[questionId] ?? bankQuestion(id: questionId);
    return (updated, topic != null);
  }

  /// Steps returned by [suggestPaperTopics], in order (the last one repeats).
  List<PaperTopicsResult> paperSteps = const [
    PaperTopicsResult(considered: 2, suggested: 1, noMatch: 1, remaining: 0),
  ];

  @override
  Future<PaperTopicsResult> suggestPaperTopics(String documentId) async {
    calls.add('paper-topics:$documentId');
    _maybeFail();
    final step = paperSteps.first;
    if (paperSteps.length > 1) paperSteps = paperSteps.sublist(1);
    return step;
  }

  @override
  Future<BankQuestion> report(String questionId, ReportReason reason, {String note = ''}) async {
    reports.add((questionId, reason, note));
    _maybeFail();
    return bankQuestion(id: questionId, issues: const ['learner_report']);
  }
}
