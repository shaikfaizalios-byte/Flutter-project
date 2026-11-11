import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:preploop/core/database/app_database.dart';
import 'package:preploop/core/errors/app_failure.dart';
import 'package:preploop/features/plus/application/web_payments.dart';
import 'package:preploop/features/plus/data/plus_repository.dart';
import 'package:preploop/features/plus/presentation/web_payment_return_screen.dart';

import '../../helpers/pump_app.dart';
import 'plus_test.dart' show openPlus;

const offer = WebOffer(amountPaise: 9900, days: 30, testPayments: true);

Future<List<Uri>> pumpWithWeb(
  WidgetTester tester,
  AppDatabase db,
  FakePlusRepository plus, {
  bool web = true,
}) async {
  final opened = <Uri>[];
  await pumpPrepLoopApp(
    tester,
    db,
    plus: plus,
    extraOverrides: [
      webPaymentsSupportedProvider.overrideWithValue(web),
      paymentPageOpenerProvider.overrideWithValue((uri) async {
        opened.add(uri);
        return true;
      }),
    ],
  );
  return opened;
}

Future<void> comeBackFromPaying(
  WidgetTester tester,
  String order, {
  String path = '/profile/plus/payment',
}) async {
  GoRouter.of(tester.element(find.byType(Scaffold).first)).go('$path?order=$order');
  await tester.pump();
  await tester.pump();
}

void main() {
  test('prices read as written in India', () {
    expect(offer.price, '₹99');
    expect(const WebOffer(amountPaise: 9950, days: 30).price, '₹99.50');
    expect(const WebOffer(amountPaise: 9905, days: 30).price, '₹99.05');
  });

  testAppWidgets('the website offers Plus for one Paytm payment, opened in the same tab', (
    tester,
    db,
  ) async {
    final plus = FakePlusRepository()..webOffer = offer;
    final opened = await pumpWithWeb(tester, db, plus);
    await openPlus(tester);

    expect(find.text('₹99 for 30 days'), findsOneWidget);
    expect(find.textContaining('Nothing renews or is charged again'), findsOneWidget);
    expect(find.textContaining('Test payments'), findsOneWidget);
    expect(find.textContaining("Plus can't be bought yet"), findsNothing);

    await tester.tap(find.text('Pay with Paytm'));
    await tester.pumpAndSettle();
    expect(plus.calls, ['web-order']);
    expect(opened.single.toString(), endsWith('/api/v1/billing/paytm/pay/PLUS-1?e=1&s=x'));
  });

  testAppWidgets('a Razorpay offer names Razorpay and keeps the same flow', (tester, db) async {
    final plus = FakePlusRepository()
      ..webOffer = const WebOffer(amountPaise: 9900, days: 30, provider: 'razorpay');
    final opened = await pumpWithWeb(tester, db, plus);
    await openPlus(tester);
    expect(find.text('Pay with Razorpay'), findsOneWidget);
    expect(find.textContaining('Razorpay takes the payment'), findsOneWidget);
    expect(find.textContaining('Paytm'), findsNothing);
    expect(find.textContaining('Test payments'), findsNothing);
    await tester.tap(find.text('Pay with Razorpay'));
    await tester.pumpAndSettle();
    expect(plus.calls, ['web-order']);
    expect(opened, hasLength(1));
  });

  testAppWidgets('the Android app never offers the website payment', (tester, db) async {
    final plus = FakePlusRepository()..webOffer = offer;
    await pumpWithWeb(tester, db, plus, web: false);
    await openPlus(tester);
    expect(find.text('Pay with Paytm'), findsNothing);
    expect(find.textContaining("Plus can't be bought yet"), findsOneWidget);
  });

  testAppWidgets('a failed start says so and opens nothing', (tester, db) async {
    final plus = FakePlusRepository()..webOffer = offer;
    final opened = await pumpWithWeb(tester, db, plus);
    await openPlus(tester);
    plus.failure = const NetworkFailure();
    await tester.tap(find.text('Pay with Paytm'));
    await tester.pumpAndSettle();
    expect(find.text('The payment page could not be opened. Try again.'), findsOneWidget);
    expect(opened, isEmpty);
  });

  testAppWidgets('coming back from paying waits for the server, then shows Plus is on', (
    tester,
    db,
  ) async {
    final plus = FakePlusRepository()..webOffer = offer;
    plus.webOrders.addAll([
      const WebOrderStatus(status: WebOrderState.pending, testPayment: true),
      WebOrderStatus(
        status: WebOrderState.success,
        grantedUntil: DateTime.utc(2026, 12, 10),
        testPayment: true,
      ),
    ]);
    await pumpWithWeb(tester, db, plus);
    await comeBackFromPaying(tester, 'PLUS-9');

    expect(find.textContaining('still being confirmed'), findsOneWidget);
    expect(find.text('Test payment: no real money was taken.'), findsOneWidget);
    await tester.pump(webPayCheckEvery);
    await tester.pump();
    expect(find.text('Thank you! PrepLoop Plus is on until Dec 10, 2026.'), findsOneWidget);
    expect(plus.calls.where((c) => c == 'web-check:PLUS-9'), hasLength(2));

    await tester.tap(find.text('Back to PrepLoop Plus'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Plus is active until'), findsOneWidget);
    expect(find.textContaining('Paid on the website.'), findsOneWidget);
    expect(find.text('Add 30 days with Paytm'), findsOneWidget);
  });

  testAppWidgets('a failed payment and a payment not found yet are told plainly', (
    tester,
    db,
  ) async {
    final plus = FakePlusRepository()
      ..webOrders.add(const WebOrderStatus(status: WebOrderState.failed));
    await pumpWithWeb(tester, db, plus);
    await comeBackFromPaying(tester, 'PLUS-2', path: '/profile/plus/paytm'); // older return address
    expect(find.textContaining('did not go through'), findsOneWidget);

    plus
      ..webOrders.clear()
      ..webOrderChecks = 0
      ..webOrders.add(const WebOrderStatus(status: WebOrderState.created));
    await comeBackFromPaying(tester, 'PLUS-3');
    await tester.pump(webPayCheckFor + webPayCheckEvery);
    for (var i = 0; i < 50; i++) {
      await tester.pump(webPayCheckEvery);
    }
    expect(find.textContaining('No completed payment for this order yet'), findsOneWidget);
    expect(find.text('Check again'), findsOneWidget);

    await comeBackFromPaying(tester, '');
    expect(find.text('No payment to check. Start again from PrepLoop Plus.'), findsOneWidget);
  });
}
