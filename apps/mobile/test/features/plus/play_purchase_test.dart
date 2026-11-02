import 'package:flutter_test/flutter_test.dart';
import 'package:preploop/core/errors/app_failure.dart';
import 'package:preploop/features/plus/data/play_store.dart';
import 'package:preploop/features/plus/presentation/plus_screen.dart';

import '../../helpers/pump_app.dart';
import 'plus_test.dart' show openPlus;

const monthly = StoreProduct(
  id: 'plus_monthly',
  title: 'PrepLoop Plus (monthly)',
  price: '₹149.00',
);

FakePlayStore playWithOffer() => FakePlayStore(available: true, offers: [monthly]);

void main() {
  testAppWidgets("Plus shows Google Play's offer with Play's price", (tester, db) async {
    await pumpPrepLoopApp(
      tester,
      db,
      plus: FakePlusRepository(playProductIds: ['plus_monthly']),
      playStore: playWithOffer(),
    );
    await openPlus(tester);

    expect(find.text('PrepLoop Plus (monthly)'), findsOneWidget);
    expect(find.text('₹149.00'), findsOneWidget);
    expect(find.text('Restore purchases'), findsOneWidget);
    expect(find.textContaining("can't be bought yet"), findsNothing);
  });

  testAppWidgets('buying: checked by the server first, then completed with Play', (
    tester,
    db,
  ) async {
    final plus = FakePlusRepository(playProductIds: ['plus_monthly']);
    final store = playWithOffer();
    await pumpPrepLoopApp(tester, db, plus: plus, playStore: store);
    await openPlus(tester);

    await tester.tap(find.text('Subscribe'));
    await tester.pumpAndSettle();

    expect(store.bought, [('plus_monthly', 'acct-1')]);
    expect(plus.verified, ['plus_monthly:token-1']);
    expect(store.completed, ['token-1']);
    expect(find.text('Thank you! PrepLoop Plus is on.'), findsOneWidget);
    expect(find.text('Bought with Google Play.'), findsOneWidget);
    expect(find.text('Manage or cancel in Google Play'), findsOneWidget);
  });

  testAppWidgets('a purchase the server cannot check yet is not completed', (tester, db) async {
    final plus = FakePlusRepository(playProductIds: ['plus_monthly'])
      ..verifyFailure = const ServerFailure(statusCode: 502, code: 'store_unavailable');
    final store = playWithOffer();
    await pumpPrepLoopApp(tester, db, plus: plus, playStore: store);
    await openPlus(tester);

    await tester.tap(find.text('Subscribe'));
    await tester.pumpAndSettle();

    expect(store.completed, isEmpty); // Play sends it again; nothing is lost
    expect(find.textContaining("couldn't be checked right now"), findsOneWidget);
  });

  testAppWidgets("another account's purchase is refused and explained", (tester, db) async {
    final plus = FakePlusRepository(playProductIds: ['plus_monthly'])
      ..verifyFailure = const ServerFailure(statusCode: 422, code: 'purchase_refused');
    final store = playWithOffer();
    await pumpPrepLoopApp(tester, db, plus: plus, playStore: store);
    await openPlus(tester);

    await tester.tap(find.text('Subscribe'));
    await tester.pumpAndSettle();

    expect(find.textContaining('did not confirm this purchase for this account'), findsOneWidget);
    expect(find.text('Subscribe'), findsOneWidget); // still not subscribed
  });

  testAppWidgets('a pending payment says so and gives no Plus yet', (tester, db) async {
    final plus = FakePlusRepository(playProductIds: ['plus_monthly']);
    final store = playWithOffer()..nextState = StorePurchaseState.pending;
    await pumpPrepLoopApp(tester, db, plus: plus, playStore: store);
    await openPlus(tester);

    await tester.tap(find.text('Subscribe'));
    await tester.pumpAndSettle();

    expect(plus.verified, isEmpty);
    expect(find.textContaining('waiting for your payment'), findsOneWidget);
  });

  testAppWidgets('a purchase finished while the app was closed is checked on start', (
    tester,
    db,
  ) async {
    final plus = FakePlusRepository(playProductIds: ['plus_monthly']);
    final store = playWithOffer();
    await pumpPrepLoopApp(tester, db, plus: plus, playStore: store);

    store.send(
      const StorePurchase(
        productId: 'plus_monthly',
        token: 'earlier',
        state: StorePurchaseState.purchased,
        needsCompletion: true,
      ),
    );
    await tester.pumpAndSettle();

    expect(plus.verified, ['plus_monthly:earlier']);
    expect(store.completed, ['earlier']);
  });

  testAppWidgets('without Play (web, iOS, no Play app) Plus points to the Android app', (
    tester,
    db,
  ) async {
    await pumpPrepLoopApp(tester, db, plus: FakePlusRepository(playProductIds: ['plus_monthly']));
    await openPlus(tester);

    expect(find.text('Plus can be bought in the Android app from Google Play.'), findsOneWidget);
    expect(find.text('Subscribe'), findsNothing);
  });

  test('the Play subscriptions page is a Google Play address', () {
    expect(playSubscriptionsUri.host, 'play.google.com');
  });
}
