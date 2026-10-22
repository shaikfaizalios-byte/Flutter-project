import 'package:preploop/core/errors/app_failure.dart';
import 'package:preploop/core/exams/exam_catalog.dart';
import 'package:preploop/features/exams/data/exams_repository.dart';
import 'package:preploop/features/concepts/domain/concept.dart';
import 'package:preploop/features/documents/domain/imported_document.dart';
import 'package:preploop/features/exams/domain/exam_topics.dart';

/// A small catalog for app tests: the two SSC exams (featured) plus a few others.
const testCatalog = <ExamOption>[
  ...builtInExams,
  ExamOption(code: 'IBPS_PO', shortName: 'IBPS PO', category: 'Banking'),
  ExamOption(code: 'NEET_UG', shortName: 'NEET UG', category: 'Entrance'),
];

/// In-memory exams and topics that follow the server's rules (own exams are private,
/// duplicates refused, an exam in use can't be deleted).
class FakeExamsRepository implements ExamsRepository {
  FakeExamsRepository({List<ExamOption> catalog = testCatalog}) : catalog = [...catalog];

  final List<ExamOption> catalog;
  final topicsByExam = <String, List<ExamTopic>>{};
  final inUse = <String>{};
  TopicDraft? draft;
  AppFailure? draftFailure;
  int _ids = 0;
  final calls = <String>[];

  @override
  Future<List<ExamOption>> exams() async => [...catalog];

  @override
  Future<ExamOption> createExam(String name) async {
    calls.add('create:$name');
    final exam = ExamOption(code: 'MY_${++_ids}', shortName: name, custom: true);
    catalog.add(exam);
    return exam;
  }

  @override
  Future<ExamOption> renameExam(String code, String name) async {
    final i = catalog.indexWhere((e) => e.code == code);
    catalog[i] = ExamOption(code: code, shortName: name, custom: true);
    return catalog[i];
  }

  @override
  Future<void> deleteExam(String code) async {
    if (inUse.contains(code)) {
      throw const ServerFailure(statusCode: 409, code: 'exam_in_use');
    }
    catalog.removeWhere((e) => e.code == code);
  }

  @override
  Future<List<ExamTopic>> topics(String examCode) async => [...?topicsByExam[examCode]];

  @override
  Future<ExamTopic> createTopic(String examCode, NewTopic topic) async {
    final list = topicsByExam.putIfAbsent(examCode, () => []);
    if (list.any(
      (t) =>
          t.subject.toLowerCase() == topic.subject.toLowerCase() &&
          t.name.toLowerCase() == topic.name.toLowerCase(),
    )) {
      throw const ServerFailure(statusCode: 409, code: 'topic_exists');
    }
    final created = ExamTopic(
      id: 't${++_ids}',
      subject: topic.subject,
      name: topic.name,
      own: true,
      keywords: topic.keywords.isEmpty ? [topic.name] : topic.keywords,
    );
    list.add(created);
    return created;
  }

  /// Syllabus imports per exam (newest first), as the server keeps them.
  final importsByExam = <String, List<SyllabusImport>>{};

  @override
  Future<List<ExamTopic>> createTopics(
    String examCode,
    List<NewTopic> topics, {
    String? syllabusName,
    SyllabusKind? syllabusKind,
  }) async {
    final created = <ExamTopic>[];
    for (final t in topics) {
      try {
        created.add(await createTopic(examCode, t));
      } on ServerFailure {
        // duplicates are skipped, as on the server
      }
    }
    if (syllabusName == null || syllabusKind == null || created.isEmpty) return created;
    final importId = 'imp${importsByExam.values.fold(0, (n, l) => n + l.length) + 1}';
    final list = topicsByExam[examCode]!;
    final tagged = <ExamTopic>[];
    for (final t in created) {
      final tagged1 = ExamTopic(
        id: t.id,
        subject: t.subject,
        name: t.name,
        own: t.own,
        keywords: t.keywords,
        syllabusImportId: importId,
      );
      list[list.indexWhere((x) => x.id == t.id)] = tagged1;
      tagged.add(tagged1);
    }
    importsByExam
        .putIfAbsent(examCode, () => [])
        .insert(
          0,
          SyllabusImport(
            id: importId,
            name: syllabusName,
            kind: syllabusKind,
            createdAt: DateTime.utc(2026, 10, 21),
            topicCount: tagged.length,
          ),
        );
    return tagged;
  }

  @override
  Future<List<SyllabusImport>> syllabusImports(String examCode) async => [
    for (final i in importsByExam[examCode] ?? const <SyllabusImport>[])
      SyllabusImport(
        id: i.id,
        name: i.name,
        kind: i.kind,
        createdAt: i.createdAt,
        topicCount: (topicsByExam[examCode] ?? const <ExamTopic>[])
            .where((t) => t.syllabusImportId == i.id)
            .length,
      ),
  ];

  @override
  Future<int> deleteSyllabusImport(String importId) async {
    calls.add('delete-import:$importId');
    var removed = 0;
    for (final list in topicsByExam.values) {
      final before = list.length;
      list.removeWhere((t) => t.syllabusImportId == importId);
      removed += before - list.length;
    }
    for (final imports in importsByExam.values) {
      imports.removeWhere((i) => i.id == importId);
    }
    return removed;
  }

  @override
  Future<ExamTopic> updateTopic(String topicId, {String? subject, String? name}) async {
    for (final list in topicsByExam.values) {
      final i = list.indexWhere((t) => t.id == topicId);
      if (i >= 0) {
        final old = list[i];
        list[i] = ExamTopic(
          id: old.id,
          subject: subject ?? old.subject,
          name: name ?? old.name,
          own: true,
          keywords: old.keywords,
        );
        return list[i];
      }
    }
    throw const ServerFailure(statusCode: 404, code: 'not_found');
  }

  @override
  Future<void> deleteTopic(String topicId) async {
    for (final list in topicsByExam.values) {
      list.removeWhere((t) => t.id == topicId);
    }
  }

  @override
  Future<TopicDraft> draftTopics(String examCode) async {
    calls.add('draft:$examCode');
    if (draftFailure != null) throw draftFailure!;
    return draft ?? const TopicDraft(model: 'fake-model', questionsConsidered: 0, topics: []);
  }

  /// Returned by [readSyllabus]; [syllabusFailure] makes it fail.
  SyllabusDraft syllabus = const SyllabusDraft(
    pages: 1,
    readBy: 'text',
    unreadablePages: 0,
    topics: [],
  );
  AppFailure? syllabusFailure;

  @override
  Future<int> deleteTopics(List<String> topicIds) async {
    calls.add('delete-many:${topicIds.join(',')}');
    var removed = 0;
    for (final list in topicsByExam.values) {
      final before = list.length;
      list.removeWhere((t) => t.own && topicIds.contains(t.id));
      removed += before - list.length;
    }
    return removed;
  }

  @override
  Future<SyllabusDraft> readSyllabusText(String examCode, String text) async {
    calls.add('syllabus-text:$examCode');
    if (syllabusFailure != null) throw syllabusFailure!;
    return syllabus;
  }

  @override
  Future<ExamTopic> setCompleted(String topicId, {required bool completed}) async {
    calls.add('completed:$topicId:$completed');
    for (final entry in topicsByExam.entries) {
      final i = entry.value.indexWhere((t) => t.id == topicId);
      if (i >= 0) {
        entry.value[i] = entry.value[i].copyWith(completed: completed);
        return entry.value[i];
      }
    }
    throw const ServerFailure(statusCode: 404, code: 'not_found');
  }

  @override
  Future<SyllabusDraft> readSyllabus(
    String examCode,
    UploadSource source, {
    required ContentLanguage language,
  }) async {
    calls.add('syllabus:$examCode:${source.name}');
    if (syllabusFailure != null) throw syllabusFailure!;
    return syllabus;
  }
}
