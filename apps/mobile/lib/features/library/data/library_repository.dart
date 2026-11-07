import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:drift/drift.dart';

import '../../../core/database/app_database.dart';
import '../../../core/errors/app_failure.dart';
import '../domain/library_models.dart';

/// PrepLoop's curated library: search, and chapters saved for offline practice. Saved questions
/// join the offline questions, marked with their chapter, so the daily pack leaves them alone.
class LibraryRepository {
  LibraryRepository(this._dio, this._db, {DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  final Dio _dio;
  final AppDatabase _db;
  final DateTime Function() _clock;

  static const _base = '/api/v1/library';

  Future<LibraryPage> search(LibraryQuery query) => _guard(() async {
    final response = await _dio.get<Map<String, dynamic>>(
      '$_base/search',
      queryParameters: {
        'exam': query.exam,
        if (query.text.isNotEmpty) 'q': query.text,
        'unit': ?query.unit,
        'topic_id': ?query.topicId,
        'pattern_id': ?query.patternId,
        'format': ?query.format,
        'year': ?query.year,
        'difficulty': ?query.difficulty,
      },
    );
    return LibraryPage.fromJson(response.data!);
  });

  Future<List<LibraryPack>> packs(String exam) => _guard(() async {
    final response = await _dio.get<List<dynamic>>('$_base/packs', queryParameters: {'exam': exam});
    return [for (final p in response.data!) LibraryPack.fromJson(p as Map<String, dynamic>)];
  });

  /// What the device holds for this exam: chapter key to its last seen change.
  Future<Map<String, int>> savedPacks(String exam) async {
    final rows = await (_db.select(_db.libraryPacks)..where((p) => p.examCode.equals(exam))).get();
    return {for (final row in rows) row.packKey: row.seq};
  }

  /// Saves a chapter, or brings a saved one up to date: only what changed is fetched.
  Future<void> savePack(String exam, LibraryPack pack) async {
    final saved = await savedPacks(exam);
    final data = await _guard(
      () async => (await _dio.get<Map<String, dynamic>>(
        '$_base/packs/${pack.key}',
        queryParameters: {'exam': exam, 'since': saved[pack.key] ?? 0},
      )).data!,
    );
    final questions = [
      for (final q in data['questions'] as List<dynamic>) q as Map<String, dynamic>,
    ];
    final removed = (data['removed'] as List<dynamic>).cast<String>();
    final now = _clock().toUtc();
    await _db.transaction(() async {
      final stale = [...removed, for (final q in questions) q['id'] as String];
      await (_db.delete(_db.offlineFigures)..where((f) => f.questionId.isIn(stale))).go();
      await (_db.delete(_db.offlineQuestions)..where((q) => q.id.isIn(removed))).go();
      await _db.batch((batch) {
        batch.insertAllOnConflictUpdate(_db.offlineQuestions, [
          for (final q in questions)
            OfflineQuestionsCompanion.insert(
              id: q['id'] as String,
              examCode: q['exam_code'] as String,
              subject: Value(q['subject'] as String?),
              topicId: Value(q['topic_id'] as String?),
              patternId: Value(q['pattern_id'] as String?),
              packKey: Value(pack.key),
              data: jsonEncode(q),
              savedAt: now,
            ),
        ]);
        batch.insertAll(_db.offlineFigures, [
          for (final f in data['figures'] as List<dynamic>)
            OfflineFiguresCompanion.insert(
              id: (f as Map<String, dynamic>)['id'] as String,
              questionId: f['question_id'] as String,
              data: base64Decode(f['data'] as String),
            ),
        ]);
      });
      await _db
          .into(_db.libraryPacks)
          .insertOnConflictUpdate(
            LibraryPacksCompanion.insert(
              examCode: exam,
              packKey: pack.key,
              name: pack.name,
              seq: data['seq'] as int,
              savedAt: now,
            ),
          );
    });
  }

  /// A figure saved with a chapter, for use without a connection.
  Future<Uint8List?> savedFigure(String figureId) async {
    final row = await (_db.select(
      _db.offlineFigures,
    )..where((f) => f.id.equals(figureId))).getSingleOrNull();
    return row?.data;
  }

  static Future<T> _guard<T>(Future<T> Function() call) async {
    try {
      return await call();
    } on DioException catch (e) {
      throw mapDioException(e);
    }
  }
}
