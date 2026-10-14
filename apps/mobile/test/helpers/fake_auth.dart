import 'package:preploop/core/errors/app_failure.dart';
import 'package:preploop/features/auth/data/auth_api.dart';

const testUser = AuthUser(id: 'user-1', email: 'learner@example.com', displayName: 'Asha');

/// A signed-in session for app tests (the default in `pumpPrepLoopApp`).
const testSession = AuthSession(accessToken: 'access-1', refreshToken: 'refresh-1', user: testUser);

class FakeTokenStore implements TokenStore {
  FakeTokenStore([this.session]);

  AuthSession? session;

  @override
  Future<AuthSession?> read() async => session;

  @override
  Future<void> write(AuthSession session) async => this.session = session;

  @override
  Future<void> clear() async => session = null;
}

/// In-memory accounts with the server's rules (uniform credential errors, rotating refresh
/// tokens).
class FakeAuthApi implements AuthApi {
  FakeAuthApi({Map<String, String>? passwords})
    : passwords = passwords ?? {'learner@example.com': 'correct horse battery'};

  /// email → password.
  final Map<String, String> passwords;
  bool offline = false;

  /// When true, refreshing fails with 401 (session revoked/expired).
  bool refreshRevoked = false;
  int refreshCount = 0;
  final loggedOut = <String>[];
  final deleted = <String>[];

  /// Emailed codes: email → code (reset), and the verification code.
  final resetCodes = <String, String>{};
  String? verificationCode;
  final resetPasswords = <String, String>{};
  int _n = 1;

  AuthSession _issue(String email) {
    _n++;
    return AuthSession(
      accessToken: 'access-$_n',
      refreshToken: 'refresh-$_n',
      user: AuthUser(id: 'user-${email.hashCode}', email: email),
    );
  }

  void _online() {
    if (offline) throw const NetworkFailure();
  }

  @override
  Future<AuthSession> register(String email, String password, {String? displayName}) async {
    _online();
    if (passwords.containsKey(email)) {
      throw const ServerFailure(statusCode: 409, code: 'email_taken');
    }
    passwords[email] = password;
    return _issue(email);
  }

  @override
  Future<AuthSession> login(String email, String password) async {
    _online();
    if (passwords[email] != password) {
      throw const ServerFailure(statusCode: 401, code: 'invalid_credentials');
    }
    return _issue(email);
  }

  @override
  Future<AuthSession> refresh(String refreshToken) async {
    _online();
    refreshCount++;
    if (refreshRevoked) throw const ServerFailure(statusCode: 401, code: 'unauthorized');
    return AuthSession(
      accessToken: 'access-r$refreshCount',
      refreshToken: 'refresh-r$refreshCount',
      user: testUser,
    );
  }

  @override
  Future<void> logout(String refreshToken) async {
    _online();
    loggedOut.add(refreshToken);
  }

  @override
  Future<String> export(String accessToken) async {
    _online();
    return '{"user": {"email": "learner@example.com"}}';
  }

  @override
  Future<void> deleteAccount(String accessToken, String password) async {
    _online();
    if (password != 'correct horse battery') {
      throw const ServerFailure(statusCode: 401, code: 'invalid_credentials');
    }
    deleted.add(accessToken);
  }

  @override
  Future<void> requestPasswordReset(String email) async {
    _online();
    if (passwords.containsKey(email)) resetCodes[email] = '123456';
  }

  @override
  Future<void> confirmPasswordReset(String email, String code, String newPassword) async {
    _online();
    if (resetCodes[email] != code) {
      throw const ServerFailure(statusCode: 400, code: 'invalid_code');
    }
    resetCodes.remove(email);
    passwords[email] = newPassword;
    resetPasswords[email] = newPassword;
  }

  @override
  Future<void> requestVerification(String accessToken) async {
    _online();
    verificationCode = '654321';
  }

  @override
  Future<AuthUser> confirmVerification(String accessToken, String code) async {
    _online();
    if (code != verificationCode) {
      throw const ServerFailure(statusCode: 400, code: 'invalid_code');
    }
    return const AuthUser(
      id: 'user-1',
      email: 'learner@example.com',
      displayName: 'Asha',
      emailVerified: true,
    );
  }
}
