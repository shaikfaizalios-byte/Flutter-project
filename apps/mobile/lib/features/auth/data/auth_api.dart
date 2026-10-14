import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../../core/errors/app_failure.dart';

@immutable
class AuthUser {
  const AuthUser({required this.id, required this.email, this.displayName});

  factory AuthUser.fromJson(Map<String, dynamic> json) => AuthUser(
    id: json['id'] as String,
    email: json['email'] as String,
    displayName: json['display_name'] as String?,
  );

  final String id;
  final String email;
  final String? displayName;

  Map<String, Object?> toJson() => {'id': id, 'email': email, 'display_name': displayName};
}

/// Tokens for the signed-in account. The access token is short-lived; the refresh token
/// rotates on every use.
@immutable
class AuthSession {
  const AuthSession({required this.accessToken, required this.refreshToken, required this.user});

  factory AuthSession.fromJson(Map<String, dynamic> json) => AuthSession(
    accessToken: json['access_token'] as String,
    refreshToken: json['refresh_token'] as String,
    user: AuthUser.fromJson(json['user'] as Map<String, dynamic>),
  );

  final String accessToken;
  final String refreshToken;
  final AuthUser user;

  Map<String, Object?> toJson() => {
    'access_token': accessToken,
    'refresh_token': refreshToken,
    'user': user.toJson(),
  };
}

/// Where the session is kept between launches. Tests use an in-memory fake.
abstract interface class TokenStore {
  Future<AuthSession?> read();

  Future<void> write(AuthSession session);

  Future<void> clear();
}

/// Keeps the session in the platform keystore (Android Keystore / iOS Keychain).
class SecureTokenStore implements TokenStore {
  SecureTokenStore([FlutterSecureStorage? storage])
    : _storage = storage ?? const FlutterSecureStorage();

  static const _key = 'preploop_session';
  final FlutterSecureStorage _storage;

  @override
  Future<AuthSession?> read() async {
    final raw = await _storage.read(key: _key);
    if (raw == null) return null;
    try {
      return AuthSession.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } on Object {
      await clear(); // unreadable (e.g. format changed): sign in again
      return null;
    }
  }

  @override
  Future<void> write(AuthSession session) =>
      _storage.write(key: _key, value: jsonEncode(session.toJson()));

  @override
  Future<void> clear() => _storage.delete(key: _key);
}

/// Account endpoints. Uses its own Dio without the auth interceptor (no refresh loops).
abstract interface class AuthApi {
  Future<AuthSession> register(String email, String password, {String? displayName});

  Future<AuthSession> login(String email, String password);

  Future<AuthSession> refresh(String refreshToken);

  Future<void> logout(String refreshToken);

  /// Everything the server holds for the account, as pretty-printed JSON.
  Future<String> export(String accessToken);

  Future<void> deleteAccount(String accessToken, String password);
}

class RemoteAuthApi implements AuthApi {
  RemoteAuthApi(this._dio);

  final Dio _dio;
  static const _base = '/api/v1/auth';

  @override
  Future<AuthSession> register(String email, String password, {String? displayName}) =>
      _session('$_base/register', {
        'email': email,
        'password': password,
        if (displayName != null && displayName.trim().isNotEmpty) 'display_name': displayName,
      });

  @override
  Future<AuthSession> login(String email, String password) =>
      _session('$_base/login', {'email': email, 'password': password});

  @override
  Future<AuthSession> refresh(String refreshToken) =>
      _session('$_base/refresh', {'refresh_token': refreshToken});

  @override
  Future<void> logout(String refreshToken) =>
      _guard(() => _dio.post<void>('$_base/logout', data: {'refresh_token': refreshToken}));

  @override
  Future<String> export(String accessToken) => _guard(() async {
    final response = await _dio.get<Object>('$_base/me/export', options: _bearer(accessToken));
    return const JsonEncoder.withIndent('  ').convert(response.data);
  });

  @override
  Future<void> deleteAccount(String accessToken, String password) => _guard(
    () => _dio.post<void>(
      '$_base/me/delete',
      data: {'password': password},
      options: _bearer(accessToken),
    ),
  );

  Future<AuthSession> _session(String path, Map<String, Object> body) => _guard(
    () async =>
        AuthSession.fromJson((await _dio.post<Map<String, dynamic>>(path, data: body)).data!),
  );

  static Options _bearer(String token) => Options(headers: {'Authorization': 'Bearer $token'});

  static Future<T> _guard<T>(Future<T> Function() call) async {
    try {
      return await call();
    } on DioException catch (e) {
      throw mapDioException(e);
    }
  }
}
