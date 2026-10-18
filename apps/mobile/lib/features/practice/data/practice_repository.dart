import 'package:dio/dio.dart';
import 'package:drift/drift.dart';

import '../../../core/database/app_database.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/utils/app_log.dart';
import '../../question_bank/domain/question.dart';
import '../domain/practice_models.dart';

/// Practice API plus an offline queue for answers.
///
/// Every answer is written to the local queue first and then sent. If the device is
/// offline, it stays queued and is replayed later (in order). The server applies an
/// answer only if its `client_seq` is newer than the stored one, so replays are safe.
class PracticeRepository {
  PracticeRepository(this._dio, this._db, {DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  final Dio _dio;
  final AppDatabase _db;
  final DateTime Function() _clock;
  int _lastSeq = 0;

  static const _base = '/api/v1/practice';

  Future<PracticeSessionView> startPractice(PracticeRequest request) => _guard(
    () async => _session(
      (await _dio.post<Map<String, dynamic>>('$_base/sessions', data: request.toJson())).data!,
    ),
  );

  Future<List<MockTestView>> mockTests() => _guard(() async {
    final response = await _dio.get<List<dynamic>>('$_base/mock-tests');
    return [for (final m in response.data!) MockTestView.fromJson(m as Map<String, dynamic>)];
  });

  Future<PracticeSessionView> startMock(String formatCode) => _guard(
    () async => _session(
      (await _dio.post<Map<String, dynamic>>(
        '$_base/mock-tests',
        data: {'exam_format_code': formatCode},
      )).data!,
    ),
  );

  /// Fetches the session after replaying any queued answers for it, then re-applies
  /// answers still queued (offline) so the learner sees what they chose.
  Future<PracticeSessionView> session(String id) async {
    await flush(sessionId: id);
    final session = await _guard(
      () async => _session((await _dio.get<Map<String, dynamic>>('$_base/sessions/$id')).data!),
    );
    final pending = await (_db.select(
      _db.pendingAnswers,
    )..where((p) => p.sessionId.equals(id))).get();
    var view = session;
    for (final p in pending) {
      final item = view.items.where((i) => i.position == p.position).firstOrNull;
      if (item != null) {
        view = view.withItem(
          item.copyWith(
            selectedPosition: () => p.selectedPosition,
            typedAnswer: () => p.typedAnswer,
          ),
        );
      }
    }
    return view;
  }

  Future<List<SessionSummaryView>> history() => _guard(() async {
    final response = await _dio.get<Map<String, dynamic>>(
      '$_base/sessions',
      queryParameters: {'limit': 50},
    );
    return [
      for (final s in response.data!['items'] as List<dynamic>)
        SessionSummaryView.fromJson(s as Map<String, dynamic>),
    ];
  });

  Future<PracticeSessionView> submit(String id) async {
    await flush(sessionId: id); // never submit without the answers given offline
    return _guard(
      () async =>
          _session((await _dio.post<Map<String, dynamic>>('$_base/sessions/$id/submit')).data!),
    );
  }

  /// Saves an answer: queued locally first, then sent. Typed-in questions pass
  /// [typedAnswer] (and no [selectedPosition]).
  Future<AnswerOutcome> answer(
    String sessionId,
    int position,
    int? selectedPosition, {
    String? typedAnswer,
    int? timeSpentMs,
  }) async {
    final seq = _nextSeq();
    await _db
        .into(_db.pendingAnswers)
        .insertOnConflictUpdate(
          PendingAnswersCompanion.insert(
            sessionId: sessionId,
            position: position,
            selectedPosition: Value(selectedPosition),
            typedAnswer: Value(typedAnswer),
            clientSeq: seq,
            timeSpentMs: Value(timeSpentMs),
            createdAt: _clock().toUtc(),
          ),
        );
    try {
      final ack = await _send(
        sessionId,
        position,
        selectedPosition,
        seq,
        timeSpentMs,
        typed: typedAnswer,
      );
      await _dequeue(sessionId, position, seq);
      return ack;
    } on NetworkFailure {
      return const AnswerOutcome.queued();
    } on TimeoutFailure {
      return const AnswerOutcome.queued();
    } on ServerFailure catch (failure) {
      if (failure.statusCode != null && failure.statusCode! >= 500) {
        return const AnswerOutcome.queued();
      }
      await _dequeue(sessionId, position, seq); // rejected for good (e.g. session closed)
      rethrow;
    }
  }

  /// Replays queued answers (all sessions, or one), oldest first. Stops at the first
  /// connectivity problem; drops answers the server rejects permanently.
  Future<int> flush({String? sessionId}) async {
    final query = _db.select(_db.pendingAnswers)..orderBy([(p) => OrderingTerm.asc(p.clientSeq)]);
    if (sessionId != null) query.where((p) => p.sessionId.equals(sessionId));
    var sent = 0;
    for (final row in await query.get()) {
      try {
        await _send(
          row.sessionId,
          row.position,
          row.selectedPosition,
          row.clientSeq,
          row.timeSpentMs,
          typed: row.typedAnswer,
        );
        sent++;
      } on NetworkFailure {
        return sent;
      } on TimeoutFailure {
        return sent;
      } on ServerFailure catch (failure) {
        if (failure.statusCode != null && failure.statusCode! >= 500) return sent;
        logError('Queued answer rejected (${failure.code})', failure);
      }
      await _dequeue(row.sessionId, row.position, row.clientSeq);
    }
    return sent;
  }

  Future<int> pendingCount(String sessionId) async {
    final rows = await (_db.select(
      _db.pendingAnswers,
    )..where((p) => p.sessionId.equals(sessionId))).get();
    return rows.length;
  }

  Future<void> setBookmark(String questionId, {required bool bookmarked}) => _guard(() async {
    final path = '/api/v1/questions/$questionId/bookmark';
    bookmarked ? await _dio.put<void>(path) : await _dio.delete<void>(path);
  });

  Future<List<BankQuestion>> bookmarks() => _questions('$_base/bookmarks');

  Future<List<BankQuestion>> incorrect() => _questions('$_base/incorrect');

  Future<List<BankQuestion>> _questions(String path) => _guard(() async {
    final response = await _dio.get<Map<String, dynamic>>(path);
    return [
      for (final q in response.data!['items'] as List<dynamic>)
        BankQuestion.fromJson(q as Map<String, dynamic>),
    ];
  });

  Future<AnswerOutcome> _send(
    String sessionId,
    int position,
    int? selected,
    int seq,
    int? timeSpentMs, {
    String? typed,
  }) => _guard(() async {
    final response = await _dio.put<Map<String, dynamic>>(
      '$_base/sessions/$sessionId/answers/$position',
      data: {
        if (typed != null) 'typed_answer': typed else 'selected_position': selected,
        'client_seq': seq,
        'time_spent_ms': ?timeSpentMs,
      },
    );
    final data = response.data!;
    return AnswerOutcome.confirmed(
      data['feedback'] == null
          ? null
          : AnswerFeedback.fromJson(data['feedback'] as Map<String, dynamic>),
      applied: data['applied'] as bool,
      selectedPosition: data['selected_position'] as int?,
      typedAnswer: data['typed_answer'] as String?,
    );
  });

  Future<void> _dequeue(String sessionId, int position, int seq) async {
    // Only remove the entry we sent; a newer answer queued meanwhile must stay.
    await (_db.delete(_db.pendingAnswers)..where(
          (p) =>
              p.sessionId.equals(sessionId) & p.position.equals(position) & p.clientSeq.equals(seq),
        ))
        .go();
  }

  int _nextSeq() {
    final now = _clock().microsecondsSinceEpoch;
    _lastSeq = now > _lastSeq ? now : _lastSeq + 1;
    return _lastSeq;
  }

  static PracticeSessionView _session(Map<String, dynamic> json) =>
      PracticeSessionView.fromJson(json);

  static Future<T> _guard<T>(Future<T> Function() call) async {
    try {
      return await call();
    } on DioException catch (e) {
      throw mapDioException(e);
    }
  }
}
