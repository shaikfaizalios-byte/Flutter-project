import 'dart:async';

import 'package:preploop/core/errors/app_failure.dart';
import 'package:preploop/features/plus/data/play_store.dart';
import 'package:preploop/features/plus/data/plus_repository.dart';

/// PrepLoop Plus in memory: not subscribed, 300 AI requests a month, test mode as given.
/// [failure] makes every call fail.
class FakePlusRepository implements PlusRepository {
  FakePlusRepository({this.testMode = false, this.used = 0, this.playProductIds = const []});

  bool testMode;
  int used;

  /// Play products the server sells; non-empty = purchases available.
  List<String> playProductIds;

  /// What the server answers to a purchase check (null = confirmed).
  AppFailure? verifyFailure;
  final verified = <String>[];
  PlusSource? source;
  DateTime? activeUntil;
  AppFailure? failure;
  final calls = <String>[];

  /// What the server offers on the website (null = not offered).
  WebOffer? webOffer;

  /// Answers to webOrder, in turn (the last one repeats).
  final webOrders = <WebOrderStatus>[];
  int webOrderChecks = 0;

  PlusStatus get _status => PlusStatus(
    active: source != null,
    source: source,
    activeUntil: activeUntil,
    aiUsedThisMonth: used,
    aiMonthlyAllowance: 300,
    periodResetsAt: DateTime.utc(2026, 11),
    testMode: testMode,
    purchasesAvailable: playProductIds.isNotEmpty,
    playProductIds: playProductIds,
    playAccountId: playProductIds.isEmpty ? null : 'acct-1',
    webOffer: webOffer,
  );

  @override
  Future<WebOrder> startWebPayment() async {
    calls.add('web-order');
    if (failure != null) throw failure!;
    return const WebOrder(orderId: 'PLUS-1', payPath: '/api/v1/billing/paytm/pay/PLUS-1?e=1&s=x');
  }

  @override
  Future<WebOrderStatus> webOrder(String orderId) async {
    calls.add('web-check:$orderId');
    if (failure != null) throw failure!;
    final answer = webOrders[webOrderChecks.clamp(0, webOrders.length - 1)];
    webOrderChecks++;
    if (answer.status == WebOrderState.success) {
      source = PlusSource.web;
      activeUntil = answer.grantedUntil;
    }
    return answer;
  }

  @override
  Future<PlusStatus> verifyPlay({required String productId, required String purchaseToken}) async {
    verified.add('$productId:$purchaseToken');
    if (verifyFailure != null) throw verifyFailure!;
    source = PlusSource.play;
    activeUntil = DateTime.utc(2026, 12);
    return _status;
  }

  @override
  Future<PlusStatus> status() async {
    if (failure != null) throw failure!;
    return _status;
  }

  @override
  Future<PlusStatus> startTest({int days = plusTestDays}) async {
    calls.add('start:$days');
    if (failure != null) throw failure!;
    source = PlusSource.test;
    activeUntil = DateTime.utc(2026, 10, 1).add(Duration(days: days));
    return _status;
  }

  @override
  Future<PlusStatus> endTest() async {
    calls.add('end');
    if (failure != null) throw failure!;
    source = null;
    activeUntil = null;
    return _status;
  }
}

/// Google Play in memory. Unavailable unless [available]; [buy] answers with a purchase
/// update on [purchases] (or [nextState]).
class FakePlayStore implements PlayStore {
  FakePlayStore({this.available = false, this.offers = const []});

  bool available;
  List<StoreProduct> offers;
  StorePurchaseState nextState = StorePurchaseState.purchased;
  final bought = <(String, String)>[];
  final completed = <String>[];
  final _updates = StreamController<List<StorePurchase>>.broadcast();

  /// Sends a purchase update, as Play does (e.g. one finished while the app was closed).
  void send(StorePurchase purchase) => _updates.add([purchase]);

  @override
  Future<bool> isAvailable() async => available;

  @override
  Future<List<StoreProduct>> products(List<String> ids) async => [
    for (final o in offers)
      if (ids.contains(o.id)) o,
  ];

  @override
  Future<void> buy(StoreProduct product, {required String accountId}) async {
    bought.add((product.id, accountId));
    send(
      StorePurchase(
        productId: product.id,
        token: 'token-${bought.length}',
        state: nextState,
        needsCompletion: nextState != StorePurchaseState.pending,
      ),
    );
  }

  @override
  Future<void> restore({required String accountId}) async {}

  @override
  Stream<List<StorePurchase>> get purchases => _updates.stream;

  @override
  Future<void> complete(StorePurchase purchase) async => completed.add(purchase.token);
}
