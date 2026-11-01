import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/utils/app_log.dart';
import '../../ai/application/ai_providers.dart';
import '../../auth/application/auth_controller.dart';
import '../data/play_store.dart';
import '../data/plus_repository.dart';

/// What the last purchase update means for the learner.
enum PurchaseNotice {
  none,

  /// Play is still waiting for the payment (e.g. a cash or bank payment).
  pending,

  /// The server confirmed the purchase with Google; Plus is on.
  added,

  /// Google does not confirm the purchase for this account (e.g. bought from another one).
  refused,

  /// It couldn't be checked now (offline, Google unreachable); Play sends it again later.
  failed,
}

@immutable
class PlayPurchaseState {
  const PlayPurchaseState({this.busy = false, this.notice = PurchaseNotice.none});

  final bool busy;
  final PurchaseNotice notice;
}

/// Listens to Google Play purchase updates for the whole app. A purchase counts only after
/// the server has checked it with Google (POST /billing/play/verify); only then is it
/// completed with Play.
class PlayPurchaseController extends Notifier<PlayPurchaseState> {
  @override
  PlayPurchaseState build() {
    final store = ref.watch(playStoreProvider);
    final updates = store.purchases.listen(
      _onUpdates,
      onError: (Object error, StackTrace stack) => logError('Play purchase stream', error, stack),
    );
    ref.onDispose(updates.cancel);
    return const PlayPurchaseState();
  }

  Future<void> buy(StoreProduct product, {required String accountId}) async {
    state = const PlayPurchaseState(busy: true);
    try {
      await ref.read(playStoreProvider).buy(product, accountId: accountId);
    } on Object catch (error, stack) {
      logError('Starting a Play purchase failed', error, stack);
      state = const PlayPurchaseState(notice: PurchaseNotice.failed);
    }
  }

  Future<void> restore({required String accountId}) async {
    state = const PlayPurchaseState(busy: true);
    try {
      await ref.read(playStoreProvider).restore(accountId: accountId);
      if (state.busy) state = const PlayPurchaseState();
    } on Object catch (error, stack) {
      logError('Restoring Play purchases failed', error, stack);
      state = const PlayPurchaseState(notice: PurchaseNotice.failed);
    }
  }

  Future<void> _onUpdates(List<StorePurchase> updates) async {
    for (final purchase in updates) {
      switch (purchase.state) {
        case StorePurchaseState.pending:
          state = const PlayPurchaseState(notice: PurchaseNotice.pending);
        case StorePurchaseState.canceled:
          state = const PlayPurchaseState();
        case StorePurchaseState.error:
          await _complete(purchase);
          state = const PlayPurchaseState(notice: PurchaseNotice.failed);
        case StorePurchaseState.purchased || StorePurchaseState.restored:
          await _verify(purchase);
      }
    }
  }

  Future<void> _verify(StorePurchase purchase) async {
    if (!ref.read(authControllerProvider).signedIn) return; // checked after the next sign-in
    try {
      await ref
          .read(plusRepositoryProvider)
          .verifyPlay(productId: purchase.productId, purchaseToken: purchase.token);
      await _complete(purchase);
      state = const PlayPurchaseState(notice: PurchaseNotice.added);
    } on ServerFailure catch (failure) {
      if (failure.code == 'purchase_refused') {
        await _complete(purchase); // not this account's to keep waiting for
        state = const PlayPurchaseState(notice: PurchaseNotice.refused);
      } else {
        state = const PlayPurchaseState(notice: PurchaseNotice.failed);
      }
    } on AppFailure {
      state = const PlayPurchaseState(notice: PurchaseNotice.failed);
    }
    ref
      ..invalidate(plusStatusProvider)
      ..invalidate(aiStatusProvider);
  }

  Future<void> _complete(StorePurchase purchase) async {
    try {
      await ref.read(playStoreProvider).complete(purchase);
    } on Object catch (error, stack) {
      logError('Completing a Play purchase failed', error, stack);
    }
  }
}

final playPurchaseControllerProvider = NotifierProvider<PlayPurchaseController, PlayPurchaseState>(
  PlayPurchaseController.new,
);

/// The Plus subscriptions Play offers this learner, with Play's prices. Empty when purchases
/// are not available (server not configured, not Android, or no Play on the device).
final playOffersProvider = FutureProvider.autoDispose<List<StoreProduct>>((ref) async {
  final status = await ref.watch(plusStatusProvider.future);
  if (!status.purchasesAvailable || status.playProductIds.isEmpty) return const [];
  final store = ref.watch(playStoreProvider);
  if (!await store.isAvailable()) return const [];
  return store.products(status.playProductIds);
}, retry: (_, _) => null);
