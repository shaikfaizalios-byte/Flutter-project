import 'package:flutter/foundation.dart';

import '../../concepts/domain/concept.dart';

enum VerificationStatus {
  unverified,
  verified,
  rejected;

  static VerificationStatus fromCode(String code) =>
      values.firstWhere((s) => s.name == code, orElse: () => unverified);
}

/// Where a question came from. AI-generated questions (Phase 9) must always be labelled.
enum QuestionOrigin {
  source,
  ai;

  static QuestionOrigin fromCode(String code) => code == 'ai' ? ai : source;
}

@immutable
class QuestionOption {
  const QuestionOption({required this.position, required this.label, required this.text});

  factory QuestionOption.fromJson(Map<String, dynamic> json) => QuestionOption(
    position: json['position'] as int,
    label: json['label'] as String,
    text: json['text'] as String,
  );

  final int position;
  final String label;
  final String text;
}

@immutable
class QuestionIssue {
  const QuestionIssue({required this.code, required this.detail, required this.resolved});

  factory QuestionIssue.fromJson(Map<String, dynamic> json) => QuestionIssue(
    code: json['code'] as String,
    detail: json['detail'] as String? ?? '',
    resolved: json['resolved'] as bool? ?? false,
  );

  final String code;
  final String detail;
  final bool resolved;
}

@immutable
class TopicRef {
  const TopicRef({required this.id, required this.subject, required this.name});

  factory TopicRef.fromJson(Map<String, dynamic> json) => TopicRef(
    id: json['id'] as String,
    subject: json['subject'] as String,
    name: json['name'] as String,
  );

  final String id;
  final String subject;
  final String name;
}

@immutable
class Passage {
  const Passage({required this.text, this.firstQuestion, this.lastQuestion});

  factory Passage.fromJson(Map<String, dynamic> json) => Passage(
    text: json['text'] as String,
    firstQuestion: json['first_question'] as int?,
    lastQuestion: json['last_question'] as int?,
  );

  final String text;
  final int? firstQuestion;
  final int? lastQuestion;
}

/// A question-bank entry with its provenance. Server is the source of truth.
@immutable
/// How an AI-generated question was made (never an official question).
@immutable
class AiProvenance {
  const AiProvenance({
    required this.provider,
    required this.model,
    required this.promptVersion,
    this.sourceQuestionId,
    this.sourceNote,
  });

  factory AiProvenance.fromJson(Map<String, dynamic> json) => AiProvenance(
    provider: json['provider'] as String,
    model: json['model'] as String,
    promptVersion: json['prompt_version'] as String,
    sourceQuestionId: json['source_question_id'] as String?,
    sourceNote: json['source_note'] as String?,
  );

  final String provider;
  final String model;
  final String promptVersion;
  final String? sourceQuestionId;
  final String? sourceNote;
}

enum AiDraftStatus { draft, approved, rejected }

/// An AI explanation for a source question without one. Always labelled "AI-generated".
@immutable
class AiExplanation {
  const AiExplanation({
    required this.id,
    required this.questionId,
    required this.text,
    required this.status,
    required this.modelConfident,
    required this.model,
    this.edited = false,
  });

  factory AiExplanation.fromJson(Map<String, dynamic> json) => AiExplanation(
    id: json['id'] as String,
    questionId: json['question_id'] as String,
    text: json['text'] as String,
    status: AiDraftStatus.values.byName(json['status'] as String),
    modelConfident: json['model_confident'] as bool,
    model: json['model'] as String,
    edited: json['edited'] as bool? ?? false,
  );

  final String id;
  final String questionId;
  final String text;
  final AiDraftStatus status;

  /// False when the model doubted the given answer; reviewers see a warning.
  final bool modelConfident;
  final String model;
  final bool edited;
}

class BankQuestion {
  const BankQuestion({
    required this.id,
    required this.origin,
    required this.examCode,
    required this.stem,
    required this.language,
    required this.options,
    required this.issues,
    required this.status,
    required this.sourcePages,
    required this.imageDependent,
    required this.topicStatus,
    this.section,
    this.subject,
    this.topic,
    this.documentId,
    this.documentFilename,
    this.sourceNumber,
    this.passage,
    this.correctPosition,
    this.answerSource,
    this.explanation,
    this.topicSuggestedBy,
    this.ai,
    this.aiExplanation,
  });

  factory BankQuestion.fromJson(Map<String, dynamic> json) => BankQuestion(
    id: json['id'] as String,
    origin: QuestionOrigin.fromCode(json['origin'] as String),
    examCode: json['exam_code'] as String,
    section: json['section'] as String?,
    subject: json['subject'] as String?,
    topic: json['topic'] == null ? null : TopicRef.fromJson(json['topic'] as Map<String, dynamic>),
    topicStatus: json['topic_status'] as String,
    topicSuggestedBy: json['topic_suggested_by'] as String?,
    ai: json['ai'] == null ? null : AiProvenance.fromJson(json['ai'] as Map<String, dynamic>),
    aiExplanation: json['ai_explanation'] == null
        ? null
        : AiExplanation.fromJson(json['ai_explanation'] as Map<String, dynamic>),
    stem: json['stem'] as String,
    language: ContentLanguage.fromCode(json['language'] as String),
    documentId: json['document_id'] as String?,
    documentFilename: json['document_filename'] as String?,
    sourceNumber: json['source_question_number'] as int?,
    sourcePages: [for (final p in json['source_pages'] as List<dynamic>) p as int],
    passage: json['passage'] == null
        ? null
        : Passage.fromJson(json['passage'] as Map<String, dynamic>),
    options: [
      for (final o in json['options'] as List<dynamic>)
        QuestionOption.fromJson(o as Map<String, dynamic>),
    ],
    correctPosition: json['correct_option_position'] as int?,
    answerSource: json['answer_source'] as String?,
    explanation: json['explanation'] as String?,
    imageDependent: json['image_dependent'] as bool,
    status: VerificationStatus.fromCode(json['verification_status'] as String),
    issues: [
      for (final i in json['issues'] as List<dynamic>)
        QuestionIssue.fromJson(i as Map<String, dynamic>),
    ],
  );

  final String id;
  final QuestionOrigin origin;
  final String examCode;
  final String? section;
  final String? subject;
  final TopicRef? topic;
  final String topicStatus; // unassigned | suggested | confirmed

  /// Who suggested the topic while [topicStatus] is "suggested": `keywords` or `ai`.
  final String? topicSuggestedBy;

  /// Set for AI-generated questions.
  final AiProvenance? ai;

  /// Latest AI explanation (draft or approved) for a source question without one.
  final AiExplanation? aiExplanation;
  final String stem;
  final ContentLanguage language;
  final String? documentId;
  final String? documentFilename;
  final int? sourceNumber;
  final List<int> sourcePages;
  final Passage? passage;
  final List<QuestionOption> options;
  final int? correctPosition;
  final String? answerSource;
  final String? explanation;
  final bool imageDependent;
  final VerificationStatus status;
  final List<QuestionIssue> issues;

  List<QuestionIssue> get openIssues => [
    for (final i in issues)
      if (!i.resolved) i,
  ];

  /// Copy with fields that AI actions and reports change. Nullable fields take a getter so
  /// they can be cleared: `copyWith(topic: () => null)`.
  BankQuestion copyWith({
    TopicRef? Function()? topic,
    String? topicStatus,
    String? Function()? topicSuggestedBy,
    AiExplanation? Function()? aiExplanation,
    VerificationStatus? status,
    List<QuestionIssue>? issues,
  }) => BankQuestion(
    id: id,
    origin: origin,
    examCode: examCode,
    stem: stem,
    language: language,
    options: options,
    issues: issues ?? this.issues,
    status: status ?? this.status,
    sourcePages: sourcePages,
    imageDependent: imageDependent,
    topicStatus: topicStatus ?? this.topicStatus,
    section: section,
    subject: subject,
    topic: topic != null ? topic() : this.topic,
    documentId: documentId,
    documentFilename: documentFilename,
    sourceNumber: sourceNumber,
    passage: passage,
    correctPosition: correctPosition,
    answerSource: answerSource,
    explanation: explanation,
    topicSuggestedBy: topicSuggestedBy != null ? topicSuggestedBy() : this.topicSuggestedBy,
    ai: ai,
    aiExplanation: aiExplanation != null ? aiExplanation() : this.aiExplanation,
  );
}

@immutable
class ParseSummary {
  const ParseSummary({
    required this.segmentationStatus,
    required this.questionsFound,
    required this.verified,
    required this.rejected,
    required this.withOpenIssues,
    required this.missingAnswers,
    required this.imageDependent,
    required this.sections,
    required this.documentIssues,
    this.formatName,
  });

  factory ParseSummary.fromJson(Map<String, dynamic> json) => ParseSummary(
    segmentationStatus: json['segmentation_status'] as String,
    questionsFound: json['questions_found'] as int,
    verified: json['verified'] as int,
    rejected: json['rejected'] as int,
    withOpenIssues: json['with_open_issues'] as int,
    missingAnswers: json['missing_answers'] as int,
    imageDependent: json['image_dependent'] as int,
    sections: [for (final s in json['sections'] as List<dynamic>) s as String],
    formatName: (json['exam_format'] as Map<String, dynamic>?)?['name'] as String?,
    documentIssues: [
      for (final i in json['document_issues'] as List<dynamic>)
        QuestionIssue.fromJson(i as Map<String, dynamic>),
    ],
  );

  final String segmentationStatus; // pending | completed | failed
  final int questionsFound;
  final int verified;
  final int rejected;
  final int withOpenIssues;
  final int missingAnswers;
  final int imageDependent;
  final List<String> sections;
  final String? formatName;
  final List<QuestionIssue> documentIssues;
}

/// Which questions to list.
@immutable
class QuestionQuery {
  const QuestionQuery({
    this.documentId,
    this.examCode,
    this.status,
    this.hasIssues,
    this.text = '',
  });

  final String? documentId;
  final String? examCode;
  final VerificationStatus? status;
  final bool? hasIssues;
  final String text;

  Map<String, Object> toParams() => {
    'limit': 100,
    'document_id': ?documentId,
    'exam': ?examCode,
    'status': ?status?.name,
    'has_issues': ?hasIssues,
    if (text.trim().isNotEmpty) 'q': text.trim(),
  };

  @override
  bool operator ==(Object other) =>
      other is QuestionQuery &&
      other.documentId == documentId &&
      other.examCode == examCode &&
      other.status == status &&
      other.hasIssues == hasIssues &&
      other.text == text;

  @override
  int get hashCode => Object.hash(documentId, examCode, status, hasIssues, text);
}

/// Reviewer edits sent to the server. Null fields are left unchanged, except those
/// listed in [clear].
@immutable
class QuestionEdit {
  const QuestionEdit({
    this.stem,
    this.options,
    this.correctPosition,
    this.explanation,
    this.topicId,
    this.imageDependent,
    this.status,
    this.clear = const {},
  });

  final String? stem;
  final List<(String label, String text)>? options;
  final int? correctPosition;
  final String? explanation;
  final String? topicId;
  final bool? imageDependent;
  final VerificationStatus? status;

  /// JSON field names to set to null (e.g. `topic_id`, `correct_option_position`).
  final Set<String> clear;

  Map<String, Object?> toJson() => {
    'stem': ?stem,
    if (options != null)
      'options': [
        for (final (label, text) in options!) {'label': label, 'text': text},
      ],
    'correct_option_position': ?correctPosition,
    'explanation': ?explanation,
    'topic_id': ?topicId,
    'image_dependent': ?imageDependent,
    'verification_status': ?status?.name,
    for (final field in clear) field: null,
  };
}
