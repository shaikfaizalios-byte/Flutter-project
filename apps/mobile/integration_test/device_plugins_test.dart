// Real platform plugins on an emulator/device (no fakes):
//   flutter test integration_test/device_plugins_test.dart -d <device-id>
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:preploop/core/database/app_database.dart';
import 'package:preploop/features/auth/data/auth_api.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('secure storage keeps and clears the session (Keystore/Keychain)', (tester) async {
    final store = SecureTokenStore();
    const session = AuthSession(
      accessToken: 'device-test-access',
      refreshToken: 'device-test-refresh',
      user: AuthUser(id: 'device-test', email: 'device@example.com'),
    );

    await store.write(session);
    final read = await store.read();
    expect(read?.refreshToken, 'device-test-refresh');
    expect(read?.user.email, 'device@example.com');

    await store.clear();
    expect(await store.read(), isNull);
  });

  testWidgets('the on-disk database opens and migrates to the current schema', (tester) async {
    final db = AppDatabase.open();
    addTearDown(db.close);

    await db.select(db.syncOutbox).get(); // forces open + migrations
    final version = await db.customSelect('PRAGMA user_version').getSingle();
    expect(version.data.values.single, db.schemaVersion);
  });
}
