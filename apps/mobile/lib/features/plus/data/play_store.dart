import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

/// A PrepLoop Plus subscription as Google Play shows it (title and price come from Play,
/// in the learner's currency; the app never shows a price of its own).
@immutable
class StoreProduct {
  const StoreProduct({required this.id, required this.title, required this.price, this.raw});

  final String id;
  final String title;
  final String price;

  /// The plugin's product details, needed to start the purchase.
  final Object? raw;
}

enum StorePurchaseState { pending, purchased, restored, error, canceled }

/// A purchase update from Google Play. [token] is the purchase token the server checks with
/// Google; the app never decides on its own that a purchase is valid.
@immutable
class StorePurchase {
  const StorePurchase({
    required this.productId,
    required this.token,
    required this.state,
    this.needsCompletion = false,
    this.raw,
  });

  final String productId;
  final String token;
  final StorePurchaseState state;
  final bool needsCompletion;
  final Object? raw;
}

/// Google Play Billing as the app uses it. Tests use a fake.
abstract interface class PlayStore {
  /// Google Play billing on this device (Android with Play; never on web or iOS).
  Future<bool> isAvailable();

  Future<List<StoreProduct>> products(List<String> ids);

  /// Starts Play's purchase sheet. [accountId] is the server's obfuscated id for this account.
  Future<void> buy(StoreProduct product, {required String accountId});

  /// Asks Play to send this account's existing purchases again (they arrive in [purchases]).
  Future<void> restore({required String accountId});

  Stream<List<StorePurchase>> get purchases;

  /// Tells Play the purchase was handled (after the server confirmed it).
  Future<void> complete(StorePurchase purchase);
}

class InAppPurchasePlayStore implements PlayStore {
  InAppPurchase get _iap => InAppPurchase.instance;

  /// Play Billing exists only in the Android app (the plugin has no web implementation).
  static bool get _android => !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  @override
  Future<bool> isAvailable() async => _android && await _iap.isAvailable();

  @override
  Future<List<StoreProduct>> products(List<String> ids) async {
    final response = await _iap.queryProductDetails(ids.toSet());
    final seen = <String>{};
    return [
      for (final p in response.productDetails)
        if (seen.add(p.id)) StoreProduct(id: p.id, title: p.title, price: p.price, raw: p),
    ];
  }

  @override
  Future<void> buy(StoreProduct product, {required String accountId}) async {
    await _iap.buyNonConsumable(
      purchaseParam: PurchaseParam(
        productDetails: product.raw! as ProductDetails,
        applicationUserName: accountId,
      ),
    );
  }

  @override
  Future<void> restore({required String accountId}) =>
      _iap.restorePurchases(applicationUserName: accountId);

  @override
  Stream<List<StorePurchase>> get purchases => !_android
      ? const Stream.empty()
      : _iap.purchaseStream.map(
          (updates) => [
            for (final p in updates)
              StorePurchase(
                productId: p.productID,
                token: p.verificationData.serverVerificationData,
                state: switch (p.status) {
                  PurchaseStatus.pending => StorePurchaseState.pending,
                  PurchaseStatus.purchased => StorePurchaseState.purchased,
                  PurchaseStatus.restored => StorePurchaseState.restored,
                  PurchaseStatus.error => StorePurchaseState.error,
                  PurchaseStatus.canceled => StorePurchaseState.canceled,
                },
                needsCompletion: p.pendingCompletePurchase,
                raw: p,
              ),
          ],
        );

  @override
  Future<void> complete(StorePurchase purchase) async {
    if (purchase.needsCompletion) await _iap.completePurchase(purchase.raw! as PurchaseDetails);
  }
}

/// Overridden in tests with a fake store.
final playStoreProvider = Provider<PlayStore>((ref) => InAppPurchasePlayStore());
