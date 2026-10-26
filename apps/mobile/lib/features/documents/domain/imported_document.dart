import 'package:flutter/foundation.dart';

import '../../concepts/domain/concept.dart';

enum DocumentStatus {
  queued,
  processing,
  completed,
  failed;

  bool get isActive => this == queued || this == processing;

  static DocumentStatus fromCode(String code) =>
      values.firstWhere((s) => s.name == code, orElse: () => failed);
}

/// A PDF uploaded to the server for text extraction (server is the source of truth).
@immutable
class ImportedDocument {
  const ImportedDocument({
    required this.id,
    required this.filename,
    required this.examCode,
    required this.language,
    required this.status,
    required this.pageCount,
    required this.pagesProcessed,
    required this.needsReviewCount,
    required this.createdAt,
    this.errorCode,
    this.segmentationStatus = 'pending',
    this.questionsFound = 0,
    this.questionsToCheck = 0,
  });

  factory ImportedDocument.fromJson(Map<String, dynamic> json) => ImportedDocument(
    id: json['id'] as String,
    filename: json['original_filename'] as String,
    examCode: json['exam_code'] as String,
    language: ContentLanguage.fromCode(json['language'] as String),
    status: DocumentStatus.fromCode(json['status'] as String),
    pageCount: json['page_count'] as int,
    pagesProcessed: json['pages_processed'] as int,
    needsReviewCount: json['needs_review_count'] as int,
    errorCode: json['error_code'] as String?,
    createdAt: DateTime.parse(json['created_at'] as String),
    segmentationStatus: json['segmentation_status'] as String? ?? 'pending',
    questionsFound: json['questions_found'] as int? ?? 0,
    questionsToCheck: json['questions_to_check'] as int? ?? 0,
  );

  final String id;
  final String filename;
  final String examCode;
  final ContentLanguage language;
  final DocumentStatus status;
  final int pageCount;
  final int pagesProcessed;
  final int needsReviewCount;
  final String? errorCode;
  final DateTime createdAt;

  /// Question segmentation: pending | completed | failed.
  final String segmentationStatus;
  final int questionsFound;

  /// Questions with an open review issue ("9 need a look").
  final int questionsToCheck;

  bool get canReview => status == DocumentStatus.completed;

  /// 0..1 processing progress.
  double get progress => pageCount == 0 ? 0 : (pagesProcessed / pageCount).clamp(0, 1);
}

/// A picked file ready to upload. [open] returns a fresh byte stream each time it is
/// called, so the file is streamed rather than loaded into memory.
@immutable
class UploadSource {
  const UploadSource({required this.name, required this.length, required this.open});

  final String name;
  final int length;
  final Stream<List<int>> Function() open;
}
