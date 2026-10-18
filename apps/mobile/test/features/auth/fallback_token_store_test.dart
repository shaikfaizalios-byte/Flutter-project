import 'package:flutter_test/flutter_test.dart';
import 'package:preploop/features/auth/data/auth_api.dart';

import '../../helpers/pump_app.dart';

/// A secure store that fails like flutter_secure_storage on a non-secure web origin.
class BrokenStore implements TokenStore {
  @override
  Future<AuthSession?> read() => Future.error(UnsupportedError('crypto.subtle missing'));

  @override
  Future<void> write(AuthSession session) => Future.error(UnsupportedError('crypto.subtle'));

  @override
  Future<void> clear() => Future.error(UnsupportedError('crypto.subtle'));
}

void main() {
  test('development web: falls back to memory once, never writes elsewhere', () async {
    final errors = <Object>[];
    final store = FallbackTokenStore(BrokenStore(), allowFallback: true, onFallback: errors.add);

    expect(await store.read(), isNull);
    expect(store.inMemory, isTrue);
    await store.write(testSession);
    expect((await store.read())!.refreshToken, testSession.refreshToken);
    await store.clear();
    expect(await store.read(), isNull);
    expect(errors, hasLength(1));
  });

  test('release builds and native apps never fall back', () async {
    final store = FallbackTokenStore(BrokenStore(), allowFallback: false);
    await expectLater(store.write(testSession), throwsUnsupportedError);
    expect(store.inMemory, isFalse);
  });

  test('a working secure store is used as is', () async {
    final secure = FakeTokenStore(null);
    final store = FallbackTokenStore(secure, allowFallback: true);
    await store.write(testSession);
    expect(await secure.read(), isNotNull);
    expect(store.inMemory, isFalse);
  });
}
