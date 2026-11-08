import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:preploop/core/network/api_client.dart';
import 'package:preploop/features/question_bank/application/question_bank_providers.dart';
import 'package:preploop/features/question_bank/domain/question.dart';

/// Answers figure links with fixed bytes, or fails, and records what was asked.
class LinkServer implements HttpClientAdapter {
  LinkServer({this.fails = false});

  final bool fails;
  final asked = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    asked.add(options);
    if (fails) throw DioException(requestOptions: options, type: DioExceptionType.connectionError);
    return ResponseBody.fromBytes([1, 2, 3], 200);
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  test('a figure reads its link from the server', () {
    final figure = QuestionFigure.fromJson({
      'id': 'f',
      'kind': 'stem',
      'page_number': 1,
      'width': 10,
      'height': 10,
      'url': '/api/v1/media/figures/abc.png?e=1&s=2',
    });
    expect(figure.url, '/api/v1/media/figures/abc.png?e=1&s=2');
  });

  ProviderContainer container(LinkServer server, Uint8List signedIn) {
    final dio = Dio(BaseOptions(baseUrl: 'http://test.invalid'))..httpClientAdapter = server;
    return ProviderContainer(
      overrides: [
        mediaDioProvider.overrideWithValue(dio),
        figureBytesProvider.overrideWith((ref, key) async => signedIn),
      ],
    );
  }

  test('a linked figure comes without the access token', () async {
    final server = LinkServer();
    final ref = container(server, Uint8List.fromList([9]));
    addTearDown(ref.dispose);
    final bytes = await ref.read(publicFigureProvider(('q', 'f', '/media/x.png')).future);
    expect(bytes, [1, 2, 3]);
    expect(server.asked.single.headers.containsKey('Authorization'), isFalse);
  });

  test('a link that fails falls back to the signed-in endpoint', () async {
    final ref = container(LinkServer(fails: true), Uint8List.fromList([9]));
    addTearDown(ref.dispose);
    expect(await ref.read(publicFigureProvider(('q', 'f', '/media/x.png')).future), [9]);
  });
}
