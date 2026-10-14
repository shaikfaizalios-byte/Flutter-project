import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../../../core/database/app_database.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/network/api_client.dart';
import '../../../core/utils/app_log.dart';
import '../../study_plan/application/study_profile_controller.dart';
import '../../sync/application/sync_controller.dart';
import '../data/auth_api.dart';

final tokenStoreProvider = Provider<TokenStore>((ref) => SecureTokenStore());

/// Session loaded before the first frame (decides whether sign-in shows). Overridden in
/// `bootstrap()`.
final initialAuthSessionProvider = Provider<AuthSession?>((ref) => null);

final authApiProvider = Provider<AuthApi>((ref) {
  final dio = buildApiDio(ref.watch(appConfigProvider));
  ref.onDispose(dio.close);
  return RemoteAuthApi(dio);
});

@immutable
class AuthState {
  const AuthState({this.session, this.expired = false});

  final AuthSession? session;

  /// The previous session ended (refresh refused); the sign-in screen says so.
  final bool expired;

  bool get signedIn => session != null;
}

/// The signed-in account and everything that changes it.
///
/// Device data belongs to one account at a time: signing in as a different account than
/// the last one erases the previous learner's data from the device first; signing in on a
/// device that has never had an account adopts its existing data and uploads it.
class AuthController extends Notifier<AuthState> {
  static const lastUserKey = 'auth_last_user_id';

  Future<String?>? _refreshing;

  @override
  AuthState build() => AuthState(session: ref.watch(initialAuthSessionProvider));

  Future<void> signIn(String email, String password) async =>
      _adopt(await ref.read(authApiProvider).login(email.trim(), password));

  Future<void> signUp(String email, String password, {String? displayName}) async => _adopt(
    await ref.read(authApiProvider).register(email.trim(), password, displayName: displayName),
  );

  /// A fresh access token after a 401, or null when the session is over. Concurrent callers
  /// share one refresh (the refresh token rotates and may be used only once).
  Future<String?> refreshAccessToken() => _refreshing ??= _refresh().whenComplete(() {
    _refreshing = null;
  });

  Future<String?> _refresh() async {
    final session = state.session;
    if (session == null) return null;
    try {
      final next = await ref.read(authApiProvider).refresh(session.refreshToken);
      await ref.read(tokenStoreProvider).write(next);
      state = AuthState(session: next);
      return next.accessToken;
    } on ServerFailure catch (failure) {
      if (failure.statusCode == 401) {
        // Expired or revoked: back to sign-in. Device data stays for the same learner.
        await ref.read(tokenStoreProvider).clear();
        state = const AuthState(expired: true);
      }
      return null;
    } on AppFailure {
      return null; // offline: keep the session and try again later
    }
  }

  /// Signs out on this device and removes the learner's data from it. Callers sync first
  /// (and warn about unsynced changes).
  Future<void> signOut() async {
    final session = state.session;
    if (session != null) {
      try {
        await ref.read(authApiProvider).logout(session.refreshToken);
      } on AppFailure catch (error, stack) {
        logError('Server sign-out failed (session still cleared locally)', error, stack);
      }
    }
    await _forgetAccount();
  }

  /// Permanently deletes the account on the server, then everything on this device.
  Future<void> deleteAccount(String password) async {
    final session = state.session;
    if (session == null) return;
    await ref.read(authApiProvider).deleteAccount(session.accessToken, password);
    await _forgetAccount();
  }

  Future<String> exportData() async {
    final session = state.session;
    if (session == null) throw const ServerFailure(statusCode: 401, code: 'unauthorized');
    return ref.read(authApiProvider).export(session.accessToken);
  }

  Future<void> _adopt(AuthSession session) async {
    final db = ref.read(appDatabaseProvider);
    final engine = ref.read(syncEngineProvider);
    final last = await _readSetting(db, lastUserKey);
    if (last != null && last != session.user.id) {
      await engine.eraseLocalUserData(); // another learner's data must not leak
    } else if (last == null) {
      await engine.markAllDirty(); // first account on this device: keep and upload
    }
    await db
        .into(db.appSettings)
        .insertOnConflictUpdate(
          AppSettingsCompanion.insert(key: lastUserKey, value: session.user.id),
        );
    await ref.read(tokenStoreProvider).write(session);
    await ref.read(studyProfileProvider.notifier).reload();
    state = AuthState(session: session);
    unawaited(ref.read(syncControllerProvider.notifier).syncNow());
  }

  Future<void> _forgetAccount() async {
    final db = ref.read(appDatabaseProvider);
    await ref.read(syncEngineProvider).eraseLocalUserData();
    await (db.delete(db.appSettings)..where((s) => s.key.equals(lastUserKey))).go();
    await ref.read(tokenStoreProvider).clear();
    await ref.read(studyProfileProvider.notifier).reload();
    state = const AuthState();
  }

  static Future<String?> _readSetting(AppDatabase db, String key) async =>
      (await (db.select(db.appSettings)..where((s) => s.key.equals(key))).getSingleOrNull())?.value;
}

final authControllerProvider = NotifierProvider<AuthController, AuthState>(AuthController.new);
