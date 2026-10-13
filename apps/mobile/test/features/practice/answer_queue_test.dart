import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:preploop/core/errors/app_failure.dart';
import 'package:preploop/features/practice/data/practice_repository.dart';

import '../../helpers/pump_app.dart';

/// Scripted HTTP layer: records requests; can simulate being offline or a closed session.
class FakeServer implements HttpClientAdapter {
  bool offline = false;
  bool sessionClosed = false;
  final requests = <(String method, String path, Map<String, dynamic>? body)>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    if (offline) {
      throw DioException(requestOptions: options, type: DioExceptionType.connectionError);
    }
    final body = options.data is Map<String, dynamic> ? options.data as Map<String, dynamic> : null;
    requests.add((options.method, options.path, body));
    if (sessionClosed) {
      return _json(409, {
        'error': {'code': 'session_closed', 'message': 'closed'},
      });
    }
    return _json(200, {
      'position': int.parse(options.path.split('/').last),
      'selected_position': body?['selected_position'],
      'applied': true,
      'feedback': null,
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
  late FakeServer server;
  late PracticeRepository repo;
  var now = DateTime.utc(2026, 10, 14, 9);

  setUp(() {
    server = FakeServer();
    final dio = Dio(BaseOptions(baseUrl: 'http://test.invalid'))..httpClientAdapter = server;
    now = DateTime.utc(2026, 10, 14, 9);
    repo = PracticeRepository(dio, createTestDatabase(), clock: () => now);
  });

  test('online answers are sent and not left in the queue', () async {
    final outcome = await repo.answer('s1', 1, 2);

    expect(outcome.queued, isFalse);
    expect(outcome.applied, isTrue);
    expect(await repo.pendingCount('s1'), 0);
    expect(server.requests.single.$3!['selected_position'], 2);
  });

  test('offline answers are queued and replayed in order with their sequence numbers', () async {
    server.offline = true;
    expect((await repo.answer('s1', 1, 2)).queued, isTrue);
    now = now.add(const Duration(seconds: 1));
    expect((await repo.answer('s1', 2, 3)).queued, isTrue);
    now = now.add(const Duration(seconds: 1));
    expect((await repo.answer('s1', 1, 4)).queued, isTrue); // replaces the queued answer for Q1
    expect(await repo.pendingCount('s1'), 2);

    server.offline = false;
    final sent = await repo.flush(sessionId: 's1');

    expect(sent, 2);
    expect(await repo.pendingCount('s1'), 0);
    final bodies = server.requests.map((r) => r.$3!).toList();
    expect(bodies.map((b) => b['selected_position']), [3, 4]); // oldest first
    final seqs = bodies.map((b) => b['client_seq'] as int).toList();
    expect(seqs[0] < seqs[1], isTrue);
  });

  test('sequence numbers stay increasing even if the clock does not move', () async {
    server.offline = true;
    await repo.answer('s1', 1, 1);
    await repo.answer('s1', 2, 1);
    server.offline = false;
    await repo.flush();

    final seqs = server.requests.map((r) => r.$3!['client_seq'] as int).toList();
    expect(seqs.toSet().length, 2);
  });

  test('replay stops at the first connectivity problem and keeps the rest', () async {
    server.offline = true;
    await repo.answer('s1', 1, 1);
    await repo.answer('s1', 2, 1);

    expect(await repo.flush(), 0);
    expect(await repo.pendingCount('s1'), 2);
  });

  test('answers for a closed session are dropped, not retried forever', () async {
    server.offline = true;
    await repo.answer('s1', 1, 1);
    server
      ..offline = false
      ..sessionClosed = true;

    await repo.flush();

    expect(await repo.pendingCount('s1'), 0);
  });

  test('a direct answer to a closed session reports the failure', () async {
    server.sessionClosed = true;

    await expectLater(
      repo.answer('s1', 1, 1),
      throwsA(isA<ServerFailure>().having((f) => f.code, 'code', 'session_closed')),
    );
    expect(await repo.pendingCount('s1'), 0);
  });
}
