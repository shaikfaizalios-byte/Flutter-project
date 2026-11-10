import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/network/api_client.dart';

/// Where an active subscription comes from.
enum PlusSource {
  /// Started from the app on a development server (no payment).
  test,

  /// Given by the PrepLoop team.
  operator,
  play,
  web;

  static PlusSource? fromCode(String? code) => code == null ? null : PlusSource.values.byName(code);
}

/// Plus bought on the website (Paytm): one payment gives [days] of Plus, with no renewal.
@immutable
class WebOffer {
  const WebOffer({required this.amountPaise, required this.days, this.testPayments = false});

  factory WebOffer.fromJson(Map<String, dynamic> json) => WebOffer(
    amountPaise: json['amount_paise'] as int,
    days: json['days'] as int,
    testPayments: json['test_payments'] as bool? ?? false,
  );

  final int amountPaise;
  final int days;

  /// Paytm's test environment: no real money moves.
  final bool testPayments;

  /// The price as written in India, e.g. "₹99" or "₹99.50".
  String get price {
    final rupees = amountPaise ~/ 100;
    final paise = amountPaise % 100;
    return paise == 0 ? '₹$rupees' : '₹$rupees.${paise.toString().padLeft(2, '0')}';
  }
}

/// A website payment the server has started with Paytm.
@immutable
class WebOrder {
  const WebOrder({required this.orderId, required this.payPath});

  final String orderId;

  /// Opened in the browser on the API's address: it sends the learner to Paytm.
  final String payPath;
}

enum WebOrderState { created, pending, success, failed, refunded }

/// A website payment as the server last confirmed it with Paytm.
@immutable
class WebOrderStatus {
  const WebOrderStatus({required this.status, this.grantedUntil, this.testPayment = false});

  factory WebOrderStatus.fromJson(Map<String, dynamic> json) => WebOrderStatus(
    status: WebOrderState.values.byName(json['status'] as String),
    grantedUntil: switch (json['granted_until']) {
      final String at => DateTime.parse(at),
      _ => null,
    },
    testPayment: json['test_payment'] as bool? ?? false,
  );

  final WebOrderState status;
  final DateTime? grantedUntil;
  final bool testPayment;

  /// Paid, failed or refunded: asking again changes nothing.
  bool get settled =>
      status == WebOrderState.success ||
      status == WebOrderState.failed ||
      status == WebOrderState.refunded;
}

/// The account's PrepLoop Plus state. The server decides it; the app only shows it.
@immutable
class PlusStatus {
  const PlusStatus({
    required this.active,
    required this.aiUsedThisMonth,
    required this.aiMonthlyAllowance,
    required this.periodResetsAt,
    this.source,
    this.activeUntil,
    this.testMode = false,
    this.purchasesAvailable = false,
    this.playProductIds = const [],
    this.playAccountId,
    this.webOffer,
  });

  factory PlusStatus.fromJson(Map<String, dynamic> json) => PlusStatus(
    active: json['active'] as bool,
    source: PlusSource.fromCode(json['source'] as String?),
    activeUntil: switch (json['active_until']) {
      final String at => DateTime.parse(at),
      _ => null,
    },
    aiUsedThisMonth: json['ai_used_this_month'] as int,
    aiMonthlyAllowance: json['ai_monthly_allowance'] as int,
    periodResetsAt: DateTime.parse(json['period_resets_at'] as String),
    testMode: json['test_mode'] as bool,
    purchasesAvailable: json['purchases_available'] as bool,
    playProductIds: [for (final id in json['play_product_ids'] as List<dynamic>? ?? []) '$id'],
    playAccountId: json['play_account_id'] as String?,
    webOffer: switch (json['web_offer']) {
      final Map<String, dynamic> offer => WebOffer.fromJson(offer),
      _ => null,
    },
  );

  final bool active;
  final PlusSource? source;
  final DateTime? activeUntil;

  /// Successful AI requests this calendar month (UTC), and the monthly allowance with Plus.
  final int aiUsedThisMonth;
  final int aiMonthlyAllowance;
  final DateTime periodResetsAt;

  /// The server lets learners start a free test subscription (development only).
  final bool testMode;

  /// Store purchases (Google Play, web payments) can be made.
  final bool purchasesAvailable;

  /// Google Play subscriptions this server sells (prices come from Play).
  final List<String> playProductIds;

  /// Passed to Play with a purchase, so the server adds it to this account only.
  final String? playAccountId;

  /// Paying on the website (Paytm); null when the server doesn't offer it.
  final WebOffer? webOffer;
}

/// Days of a test subscription started from the app.
const plusTestDays = 7;

abstract interface class PlusRepository {
  Future<PlusStatus> status();

  Future<PlusStatus> startTest({int days = plusTestDays});

  Future<PlusStatus> endTest();

  /// Reports a Google Play purchase; the server checks it with Google before adding Plus.
  Future<PlusStatus> verifyPlay({required String productId, required String purchaseToken});

  /// Starts a website payment; the server sets the price.
  Future<WebOrder> startWebPayment();

  /// A website payment, checked with Paytm by the server while it isn't settled.
  Future<WebOrderStatus> webOrder(String orderId);
}

class RemotePlusRepository implements PlusRepository {
  RemotePlusRepository(this._dio);

  final Dio _dio;

  static const _path = '/api/v1/me/plus';

  @override
  Future<PlusStatus> status() =>
      _guard(() async => PlusStatus.fromJson((await _dio.get<Map<String, dynamic>>(_path)).data!));

  @override
  Future<PlusStatus> startTest({int days = plusTestDays}) => _guard(
    () async => PlusStatus.fromJson(
      (await _dio.post<Map<String, dynamic>>('$_path/test', data: {'days': days})).data!,
    ),
  );

  @override
  Future<PlusStatus> endTest() => _guard(
    () async => PlusStatus.fromJson((await _dio.delete<Map<String, dynamic>>('$_path/test')).data!),
  );

  @override
  Future<PlusStatus> verifyPlay({required String productId, required String purchaseToken}) =>
      _guard(
        () async => PlusStatus.fromJson(
          (await _dio.post<Map<String, dynamic>>(
            '/api/v1/billing/play/verify',
            data: {'product_id': productId, 'purchase_token': purchaseToken},
          )).data!,
        ),
      );

  @override
  Future<WebOrder> startWebPayment() => _guard(() async {
    final data = (await _dio.post<Map<String, dynamic>>('/api/v1/billing/paytm/orders')).data!;
    return WebOrder(orderId: data['order_id'] as String, payPath: data['pay_path'] as String);
  });

  @override
  Future<WebOrderStatus> webOrder(String orderId) => _guard(
    () async => WebOrderStatus.fromJson(
      (await _dio.get<Map<String, dynamic>>(
        '/api/v1/billing/paytm/orders/${Uri.encodeComponent(orderId)}',
      )).data!,
    ),
  );

  static Future<T> _guard<T>(Future<T> Function() call) async {
    try {
      return await call();
    } on DioException catch (e) {
      throw mapDioException(e);
    }
  }
}

final plusRepositoryProvider = Provider<PlusRepository>(
  (ref) => RemotePlusRepository(ref.watch(dioProvider)),
);

/// The account's Plus status (errors are shown, not retried silently).
final plusStatusProvider = FutureProvider.autoDispose<PlusStatus>(
  (ref) => ref.watch(plusRepositoryProvider).status(),
  retry: (_, _) => null,
);
