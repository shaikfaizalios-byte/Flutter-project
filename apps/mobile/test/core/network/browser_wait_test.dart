import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:preploop/core/network/api_client.dart';

Future<RequestOptions> capture(bool isWeb, {Options? options}) async {
  final dio = Dio(BaseOptions(connectTimeout: const Duration(seconds: 10)))
    ..interceptors.add(BrowserWaitInterceptor(isWeb: isWeb));
  RequestOptions? captured;
  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (o, handler) {
        captured = o;
        handler.reject(DioException(requestOptions: o, type: DioExceptionType.cancel));
      },
    ),
  );
  await dio
      .get<void>('http://example.test/x', options: options)
      .catchError((_) => Response<void>(requestOptions: RequestOptions()));
  return captured!;
}

void main() {
  test('in a browser the connect limit also covers a slow answer (an AI question)', () async {
    final options = Options(receiveTimeout: const Duration(minutes: 2));
    final web = await capture(true, options: options);
    expect(web.connectTimeout, const Duration(minutes: 2, seconds: 10));
    final native = await capture(false, options: options);
    expect(native.connectTimeout, const Duration(seconds: 10));
  });

  test('no receive limit means no connect limit in a browser', () {
    final options = RequestOptions(connectTimeout: const Duration(seconds: 10));
    expect(browserConnectTimeout(options), Duration.zero);
    expect(browserConnectTimeout(RequestOptions()), isNull);
  });
}
