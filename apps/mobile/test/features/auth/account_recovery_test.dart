import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:preploop/app/router.dart';

import '../../helpers/pump_app.dart';

void main() {
  test('reset and legal pages are reachable without an account', () {
    for (final path in [AppRoutes.forgotPassword, AppRoutes.privacy, AppRoutes.terms]) {
      expect(appRedirect(signedIn: false, onboardingCompleted: false, path: path), isNull);
    }
    expect(
      appRedirect(signedIn: false, onboardingCompleted: true, path: '/home'),
      AppRoutes.signIn,
    );
  });

  testAppWidgets('forgot password: code by email, then a new password', (tester, db) async {
    final api = FakeAuthApi();
    await pumpPrepLoopApp(tester, db, session: null, authApi: api);

    await tester.tap(find.text('Forgot password?'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).first, 'learner@example.com');
    await tester.tap(find.text('Send code'));
    await tester.pumpAndSettle();
    expect(find.textContaining('we sent a 6-digit code'), findsOneWidget);

    await tester.enterText(find.widgetWithText(TextFormField, '6-digit code'), '000000');
    await tester.enterText(find.widgetWithText(TextFormField, 'New password'), 'a brand new pass');
    await tester.tap(find.text('Set new password'));
    await tester.pumpAndSettle();
    expect(find.textContaining('not valid or has expired'), findsOneWidget);

    await tester.enterText(find.widgetWithText(TextFormField, '6-digit code'), '123456');
    await tester.tap(find.text('Set new password'));
    await tester.pumpAndSettle();

    expect(api.resetPasswords['learner@example.com'], 'a brand new pass');
    expect(find.text('Password changed. Sign in with your new password.'), findsOneWidget);
    expect(find.text('Sign in to your study account.'), findsOneWidget);
  });

  testAppWidgets('unknown emails get the same answer (no account enumeration)', (tester, db) async {
    final api = FakeAuthApi();
    await pumpPrepLoopApp(tester, db, session: null, authApi: api);
    await tester.tap(find.text('Forgot password?'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).first, 'nobody@example.com');
    await tester.tap(find.text('Send code'));
    await tester.pumpAndSettle();

    expect(find.textContaining('If an account exists'), findsOneWidget);
    expect(api.resetCodes, isEmpty);
  });

  testAppWidgets('confirming the email from Profile', (tester, db) async {
    final api = FakeAuthApi();
    final store = FakeTokenStore(testSession);
    await pumpPrepLoopApp(tester, db, authApi: api, tokenStore: store);
    await tester.tap(
      find.descendant(of: find.byType(NavigationBar), matching: find.text('Profile')),
    );
    await tester.pumpAndSettle();
    expect(find.text('Confirm your email'), findsOneWidget);

    await tester.tap(find.widgetWithText(TextButton, 'Confirm'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, '654321');
    await tester.tap(find.widgetWithText(FilledButton, 'Confirm'));
    await tester.pumpAndSettle();

    expect(find.text('Email confirmed.'), findsOneWidget);
    expect(find.text('Confirm your email'), findsNothing);
    expect(store.session?.user.emailVerified, isTrue);
  });

  testAppWidgets('privacy policy and terms open from sign-in, marked as drafts', (
    tester,
    db,
  ) async {
    await pumpPrepLoopApp(tester, db, session: null);

    await tester.tap(find.text('Privacy policy'));
    await tester.pumpAndSettle();
    expect(find.text('Privacy policy (draft)'), findsOneWidget);
    expect(find.textContaining('Draft for legal review'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();

    await tester.tap(find.text('Terms of use'));
    await tester.pumpAndSettle();
    expect(find.text('Terms of use (draft)'), findsOneWidget);
    expect(
      find.textContaining('not affiliated with the Staff Selection Commission'),
      findsOneWidget,
    );
  });
}
