import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:preploop/core/network/auth_interceptor.dart';

/// Accepts only `Bearer <valid>`; everything else is 401.
class TokenCheckingServer implements HttpClientAdapter {
  String valid = 'new-token';
  final seen = <String?>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final auth = options.headers['Authorization'] as String?;
    seen.add(auth);
    final ok = auth == 'Bearer $valid';
    return ResponseBody.fromString(
      jsonEncode(
        ok
            ? {'ok': true}
            : {
                'error': {'code': 'unauthorized'},
              },
      ),
      ok ? 200 : 401,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  late TokenCheckingServer server;
  late Dio dio;
  late String? token;
  late int refreshes;
  late String? refreshResult;

  setUp(() {
    server = TokenCheckingServer();
    token = 'old-token';
    refreshes = 0;
    refreshResult = 'new-token';
    dio = Dio(BaseOptions(baseUrl: 'http://test.invalid'))..httpClientAdapter = server;
    dio.interceptors.add(
      AuthInterceptor(
        dio,
        accessToken: () => token,
        refresh: () async {
          refreshes++;
          await Future<void>.delayed(const Duration(milliseconds: 5));
          token = refreshResult;
          return refreshResult;
        },
      ),
    );
  });

  test('adds the access token to requests', () async {
    token = 'new-token';
    final response = await dio.get<Object>('/api/v1/concepts');

    expect(response.statusCode, 200);
    expect(server.seen, ['Bearer new-token']);
    expect(refreshes, 0);
  });

  test('a 401 refreshes once and retries with the new token', () async {
    final response = await dio.get<Object>('/api/v1/concepts');

    expect(response.statusCode, 200);
    expect(refreshes, 1);
    expect(server.seen, ['Bearer old-token', 'Bearer new-token']);
  });

  test('concurrent 401s share a single refresh', () async {
    final responses = await Future.wait([
      dio.get<Object>('/a'),
      dio.get<Object>('/b'),
      dio.get<Object>('/c'),
    ]);

    expect(responses.map((r) => r.statusCode), [200, 200, 200]);
    expect(refreshes, 1);
  });

  test('when refreshing fails the 401 is passed on (sign in again)', () async {
    refreshResult = null;

    await expectLater(
      dio.get<Object>('/api/v1/concepts'),
      throwsA(isA<DioException>().having((e) => e.response?.statusCode, 'status', 401)),
    );
    expect(refreshes, 1);
  });

  test('a request is retried at most once', () async {
    server.valid = 'never-valid';

    await expectLater(dio.get<Object>('/api/v1/concepts'), throwsA(isA<DioException>()));
    expect(server.seen, hasLength(2));
  });
}
