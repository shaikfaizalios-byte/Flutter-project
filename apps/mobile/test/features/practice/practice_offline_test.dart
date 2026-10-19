import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:preploop/core/errors/app_failure.dart';
import 'package:preploop/features/practice/data/practice_repository.dart';
import 'package:preploop/features/practice/domain/offline_practice.dart';
import 'package:preploop/features/practice/domain/practice_models.dart';

import '../../helpers/pump_app.dart';

Map<String, dynamic> packQuestion(String id, {int correct = 2, String exam = 'SSC_CHSL'}) => {
  'id': id,
  'exam_code': exam,
  'section': 'Quantitative Aptitude',
  'subject': 'Quantitative Aptitude',
  'topic_id': null,
  'pattern_id': null,
  'stem': 'Question $id?',
  'passage': null,
  'options': [
    for (var i = 1; i <= 4; i++) {'position': i, 'label': '$i', 'text': 'opt $i'},
  ],
  'answer_type': 'choice',
  'correct_position': correct,
  'typed_answer': null,
  'typed_answer_numeric': false,
  'explanation': 'Because.',
  'shared': false,
  'shared_source': null,
  'document_filename': 'mine.pdf',
  'page': 1,
  'question_number': 1,
};

/// Scripted server for offline practice: the pack, starting (fails while offline) and uploads.
class OfflineServer implements HttpClientAdapter {
  bool offline = false;
  List<Map<String, dynamic>> pack = [packQuestion('a'), packQuestion('b', correct: 3)];
  final uploads = <Map<String, dynamic>>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    if (offline) {
      throw DioException(requestOptions: options, type: DioExceptionType.connectionError);
    }
    if (options.path.endsWith('/offline-pack')) {
      return _json(200, {'questions': pack, 'limit': 500, 'generated_at': '2026-10-19T09:00:00Z'});
    }
    if (options.path.endsWith('/offline-sessions')) {
      final body = options.data as Map<String, dynamic>;
      uploads.add(body);
      return _json(201, {
        'id': body['client_id'],
        'mode': 'practice',
        'status': 'submitted',
        'started_at': body['started_at'],
        'server_now': '2026-10-19T10:00:00Z',
        'submit_reason': 'offline',
        'items': <Object>[],
        'result': null,
      });
    }
    return _json(500, {
      'error': {'code': 'unexpected', 'message': options.path},
    });
  }

  static ResponseBody _json(int status, Object data) => ResponseBody.fromString(
    jsonEncode(data),
    status,
    headers: {
      Headers.contentTypeHeader: ['application/json'],
    },
  );

  @override
  void close({bool force = false}) {}
}

void main() {
  late OfflineServer server;
  late PracticeRepository repo;
  var now = DateTime.utc(2026, 10, 19, 9);

  setUp(() {
    server = OfflineServer();
    final dio = Dio(BaseOptions(baseUrl: 'http://test.invalid'))..httpClientAdapter = server;
    now = DateTime.utc(2026, 10, 19, 9);
    repo = PracticeRepository(dio, createTestDatabase(), clock: () => now);
  });

  test('typed answers match like the server: numbers by value, else ignoring spaces/case', () {
    expect(typedAnswerMatches('2.5', '2.50'), isTrue);
    expect(typedAnswerMatches('-15', '−15.0'), isTrue);
    expect(typedAnswerMatches('1000', '1,000'), isTrue);
    expect(typedAnswerMatches('2.5', '2.49'), isFalse);
    expect(typedAnswerMatches('0', '-0.00'), isTrue);
    expect(typedAnswerMatches('3142', '3 1 4 2'), isTrue);
    expect(typedAnswerMatches('BDAC', 'bdac'), isTrue);
  });

  test('without a connection and no saved questions, starting still fails', () async {
    server.offline = true;
    await expectLater(repo.startPractice(const PracticeRequest()), throwsA(isA<NetworkFailure>()));
  });

  test('offline practice: saved questions, device marking, upload when back online', () async {
    expect(await repo.refreshOfflinePack(), 2);
    expect(await repo.offlineQuestionCount(), 2);

    server.offline = true;
    final session = await repo.startPractice(const PracticeRequest(count: 10));
    expect(session.offline, isTrue);
    expect(session.items, hasLength(2));

    final first = session.items.firstWhere((i) => i.questionId == 'a');
    final outcome = await repo.answer(session.id, first.position, 2);
    expect(outcome.feedback!.isCorrect, isTrue);
    expect(outcome.feedback!.explanation, 'Because.');
    // Answers are final once given, as online.
    final again = await repo.answer(session.id, first.position, 1);
    expect(again.applied, isFalse);
    expect(again.selectedPosition, 2);

    now = now.add(const Duration(minutes: 3));
    final done = await repo.submit(session.id);
    expect(done.offline, isTrue);
    expect(done.result!.total.correct, 1);
    expect(done.result!.total.unattempted, 1);
    expect(await repo.offlineSessionsToUpload(), 1);

    // Back online: the session is uploaded once, with the device times.
    server.offline = false;
    await repo.flush();
    expect(server.uploads, hasLength(1));
    final body = server.uploads.single;
    expect(body['client_id'], session.id);
    final items = body['items'] as List<dynamic>;
    expect(items.firstWhere((i) => (i as Map)['question_id'] == 'a')['selected_position'], 2);
    expect(await repo.offlineSessionsToUpload(), 0);
    await repo.flush();
    expect(server.uploads, hasLength(1));
  });

  test('finishing while online uploads at once and shows the server result', () async {
    await repo.refreshOfflinePack();
    server.offline = true;
    final session = await repo.startPractice(const PracticeRequest(examCode: 'SSC_CHSL'));
    server.offline = false;
    final done = await repo.submit(session.id);
    expect(done.offline, isFalse); // the server's session
    expect(done.submitReason, 'offline');
    expect(server.uploads.single['exam_code'], 'SSC_CHSL');
    expect(await repo.offlineSessionsToUpload(), 0);
  });

  test('filters apply to saved questions; nothing matching rethrows the failure', () async {
    server.pack = [packQuestion('a', exam: 'SSC_CGL')];
    await repo.refreshOfflinePack();
    server.offline = true;
    await expectLater(
      repo.startPractice(const PracticeRequest(examCode: 'SSC_CHSL')),
      throwsA(isA<NetworkFailure>()),
    );
    final cgl = await repo.startPractice(const PracticeRequest(examCode: 'SSC_CGL'));
    expect(cgl.items.single.questionId, 'a');
  });
}
