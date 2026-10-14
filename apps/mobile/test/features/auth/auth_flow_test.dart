import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:preploop/app/router.dart';
import 'package:preploop/core/database/app_database.dart';
import 'package:preploop/features/auth/application/auth_controller.dart';
import 'package:preploop/features/concepts/data/local_concepts_repository.dart';
import 'package:preploop/features/concepts/domain/concept.dart';
import 'package:preploop/features/study_plan/data/study_profile_repository.dart';
import 'package:preploop/features/study_plan/domain/study_profile.dart';

import '../../helpers/pump_app.dart';

const password = 'correct horse battery';

Future<void> seedConcept(WidgetTester tester, AppDatabase db, String title) => seed(
  tester,
  () => LocalConceptsRepository(db, clock: () => testNow).create(
    ConceptDraft(
      examCode: 'SSC_CGL',
      title: title,
      subject: 'Quantitative Aptitude',
      topic: 'Percentage',
      language: ContentLanguage.english,
    ),
  ),
);

Future<void> seedProfile(WidgetTester tester, AppDatabase db) => seed(
  tester,
  () => StudyProfileRepository(db).save(StudyProfile(onboardingCompletedAt: DateTime.utc(2026))),
);

Future<void> seedLastUser(WidgetTester tester, AppDatabase db, String id) => seed(
  tester,
  () => db
      .into(db.appSettings)
      .insert(AppSettingsCompanion.insert(key: AuthController.lastUserKey, value: id)),
);

Future<int> conceptCount(WidgetTester tester, AppDatabase db) async =>
    (await seed(tester, () => db.select(db.concepts).get())).length;

Future<void> signIn(
  WidgetTester tester, {
  String email = 'learner@example.com',
  String pw = password,
}) async {
  await tester.enterText(find.widgetWithText(TextFormField, 'Email'), email);
  await tester.enterText(find.widgetWithText(TextFormField, 'Password'), pw);
  await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
  await tester.pumpAndSettle();
}

Future<void> openAccount(WidgetTester tester) async {
  await tester.tap(find.descendant(of: find.byType(NavigationBar), matching: find.text('Profile')));
  await tester.pumpAndSettle();
}

void main() {
  test('redirect rule: sign-in first, then onboarding', () {
    String? go(String path, {bool signedIn = true, bool onboarded = true}) =>
        appRedirect(signedIn: signedIn, onboardingCompleted: onboarded, path: path);

    expect(go('/home', signedIn: false), AppRoutes.signIn);
    expect(go(AppRoutes.signIn, signedIn: false), isNull);
    expect(go(AppRoutes.signIn), AppRoutes.home);
    expect(go(AppRoutes.signIn, onboarded: false), AppRoutes.onboarding);
    expect(go('/home', onboarded: false), AppRoutes.onboarding);
    expect(go('/home'), isNull);
  });

  testAppWidgets('signed out: sign-in screen; wrong password is explained', (tester, db) async {
    await pumpPrepLoopApp(tester, db, session: null);

    expect(find.text('Sign in to your study account.'), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
    await signIn(tester, pw: 'wrong password');

    expect(find.text('Email or password is not correct.'), findsOneWidget);
  });

  testAppWidgets('signing in keeps this device\'s data and opens Home', (tester, db) async {
    await seedProfile(tester, db);
    await seedConcept(tester, db, 'Made before signing in');
    final store = FakeTokenStore();
    final server = FakeSyncServer();
    await pumpPrepLoopApp(tester, db, session: null, tokenStore: store, syncServer: server);

    await signIn(tester);

    expect(find.text('Your study loop'), findsOneWidget);
    expect(store.session?.user.email, 'learner@example.com');
    expect(await conceptCount(tester, db), 1);
    // First account on this device: existing data is uploaded to it.
    expect(server.keys.map((k) => k.split(':').first), containsAll(['concept', 'study_profile']));
  });

  testAppWidgets('signing in as a different learner removes the previous data', (tester, db) async {
    await seedConcept(tester, db, 'Someone else\'s note');
    await seedLastUser(tester, db, 'previous-user');
    await pumpPrepLoopApp(tester, db, session: null);

    await signIn(tester);

    expect(await conceptCount(tester, db), 0);
    expect(find.byType(NavigationBar), findsNothing); // fresh learner → onboarding
  });

  testAppWidgets('creating an account starts onboarding', (tester, db) async {
    final api = FakeAuthApi();
    await pumpPrepLoopApp(
      tester,
      db,
      session: null,
      authApi: api,
      studyProfile: const StudyProfile(),
    );

    await tester.tap(find.text('New here? Create an account'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextFormField, 'Email'), 'new@example.com');
    await tester.enterText(find.widgetWithText(TextFormField, 'Password'), 'short');
    await tester.tap(find.widgetWithText(FilledButton, 'Create account'));
    await tester.pumpAndSettle();
    expect(find.text('At least 10 characters'), findsWidgets);

    await tester.enterText(find.widgetWithText(TextFormField, 'Password'), password);
    await tester.tap(find.widgetWithText(FilledButton, 'Create account'));
    await tester.pumpAndSettle();

    expect(api.passwords['new@example.com'], password);
    expect(find.byType(NavigationBar), findsNothing); // onboarding comes first
  });

  testAppWidgets('sign out removes the learner\'s data from the device', (tester, db) async {
    await seedConcept(tester, db, 'Mine');
    final api = FakeAuthApi();
    final store = FakeTokenStore(testSession);
    final server = FakeSyncServer();
    await pumpPrepLoopApp(tester, db, authApi: api, tokenStore: store, syncServer: server);
    await openAccount(tester);
    expect(find.text('learner@example.com'), findsOneWidget);

    await tester.tap(find.widgetWithText(OutlinedButton, 'Sign out'));
    await tester.pumpAndSettle();
    expect(find.textContaining('removed from this device'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Sign out'));
    await tester.pumpAndSettle();

    expect(find.text('Sign in to your study account.'), findsOneWidget);
    expect(api.loggedOut, ['refresh-1']);
    expect(store.session, isNull);
    expect(await conceptCount(tester, db), 0);
    expect(server.keys, isNotEmpty); // synced before leaving
  });

  testAppWidgets('signing out offline warns about unsynced changes', (tester, db) async {
    await seedConcept(tester, db, 'Not uploaded');
    final server = FakeSyncServer()..offline = true;
    await pumpPrepLoopApp(tester, db, syncServer: server);
    await openAccount(tester);

    await tester.tap(find.widgetWithText(OutlinedButton, 'Sign out'));
    await tester.pumpAndSettle();

    expect(find.textContaining('1 change has not synced yet'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(await conceptCount(tester, db), 1);
  });

  testAppWidgets('sync now uploads changes and shows the status', (tester, db) async {
    await seedConcept(tester, db, 'To upload');
    final server = FakeSyncServer();
    await pumpPrepLoopApp(tester, db, syncServer: server);
    await openAccount(tester);
    expect(find.text('1 change waiting to sync'), findsOneWidget);

    await tester.tap(find.text('Sync now'));
    await tester.pumpAndSettle();

    expect(server.keys.single, startsWith('concept:'));
    expect(find.textContaining('Synced '), findsOneWidget);

    server.offline = true;
    await seedConcept(tester, db, 'Offline change');
    await tester.tap(find.text('Sync now'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Offline.'), findsOneWidget);
  });

  testAppWidgets('account deletion needs the password and clears the device', (tester, db) async {
    await seedConcept(tester, db, 'Mine');
    final api = FakeAuthApi();
    await pumpPrepLoopApp(tester, db, authApi: api);
    await openAccount(tester);

    await tester.tap(find.text('Delete account'));
    await tester.pumpAndSettle();
    expect(find.textContaining('cannot be undone'), findsOneWidget);
    await tester.enterText(find.byType(TextField).last, 'wrong');
    await tester.tap(find.text('Delete permanently'));
    await tester.pumpAndSettle();
    expect(find.text('Email or password is not correct.'), findsOneWidget);
    expect(api.deleted, isEmpty);

    await tester.tap(find.text('Delete account'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, password);
    await tester.tap(find.text('Delete permanently'));
    await tester.pumpAndSettle();

    expect(api.deleted, ['access-1']);
    expect(find.text('Sign in to your study account.'), findsOneWidget);
    expect(await conceptCount(tester, db), 0);
  });

  testAppWidgets('data export is copied to the clipboard', (tester, db) async {
    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (
      call,
    ) async {
      if (call.method == 'Clipboard.setData') {
        copied = (call.arguments as Map<Object?, Object?>)['text'] as String?;
      }
      return null;
    });
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    await pumpPrepLoopApp(tester, db);
    await openAccount(tester);

    await tester.tap(find.text('Copy my data'));
    await tester.pumpAndSettle();

    expect(copied, contains('learner@example.com'));
    expect(find.textContaining('copied as JSON'), findsOneWidget);
  });

  testAppWidgets('an expired session returns to sign-in with an explanation', (tester, db) async {
    final api = FakeAuthApi()..refreshRevoked = true;
    await pumpPrepLoopApp(tester, db, authApi: api);
    final container = ProviderScope.containerOf(tester.element(find.byType(Scaffold).first));

    expect(await container.read(authControllerProvider.notifier).refreshAccessToken(), isNull);
    await tester.pumpAndSettle();

    expect(find.text('You were signed out. Please sign in again.'), findsOneWidget);
  });

  testAppWidgets('sign-in is localised in Hindi', (tester, db) async {
    await pumpPrepLoopApp(tester, db, session: null, deviceLocale: const Locale('hi'));

    expect(find.text('अपने अध्ययन खाते में साइन इन करें।'), findsOneWidget);
    expect(find.text('नए हैं? खाता बनाएँ'), findsOneWidget);
  });
}
