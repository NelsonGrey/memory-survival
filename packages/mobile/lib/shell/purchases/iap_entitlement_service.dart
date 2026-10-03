import 'dart:async';

import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'entitlement_service.dart';

const _kPrefsKey = 'game_shell_ad_free';

/// Real [EntitlementService] backed by `in_app_purchase`, generalized from
/// Modulo Squares' purchase_service.dart. Every game passes its own store
/// product ID for the ad-removal purchase (e.g. `memory_survival_remove_ads`) — the product
/// itself must still be created in Play Console / App Store Connect per
/// game, this class doesn't do that.
///
/// v1 scope: local entitlement caching via SharedPreferences, no
/// server-side receipt verification. Add a Cloud Functions verification
/// step per game before relying on this for a game with a real economy
/// beyond the single ad-removal SKU.
class IapEntitlementService implements EntitlementService {
  IapEntitlementService({
    required String adRemovalProductId,
    InAppPurchase? iap,
  }) : _productId = adRemovalProductId,
       _iap = iap ?? InAppPurchase.instance;

  final String _productId;
  final InAppPurchase _iap;
  final _controller = StreamController<bool>.broadcast();
  StreamSubscription<List<PurchaseDetails>>? _subscription;
  bool _adFree = false;

  @override
  bool get isAdFree => _adFree;

  @override
  Stream<bool> get adFreeChanges => _controller.stream;

  void _setAdFree(bool value) {
    if (_adFree == value) return;
    _adFree = value;
    _controller.add(value);
    SharedPreferences.getInstance().then((p) => p.setBool(_kPrefsKey, value));
  }

  @override
  Future<void> restore() async {
    final prefs = await SharedPreferences.getInstance();
    _adFree = prefs.getBool(_kPrefsKey) ?? false;
    if (_adFree) _controller.add(true);

    _subscription ??= _iap.purchaseStream.listen(_handleUpdates);

    final available = await _iap.isAvailable();
    if (available) {
      await _iap.restorePurchases();
    }
  }

  void _handleUpdates(List<PurchaseDetails> purchases) {
    for (final purchase in purchases) {
      if (purchase.productID != _productId) continue;
      switch (purchase.status) {
        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          _setAdFree(true);
          if (purchase.pendingCompletePurchase) {
            _iap.completePurchase(purchase);
          }
          break;
        case PurchaseStatus.error:
        case PurchaseStatus.canceled:
        case PurchaseStatus.pending:
          break;
      }
    }
  }

  @override
  Future<void> purchaseAdRemoval() async {
    final available = await _iap.isAvailable();
    if (!available) return;

    final response = await _iap.queryProductDetails({_productId});
    if (response.notFoundIDs.contains(_productId) ||
        response.productDetails.isEmpty) {
      throw StateError(
        'Ad-removal product "$_productId" not found in the store listing.',
      );
    }

    final param = PurchaseParam(productDetails: response.productDetails.first);
    await _iap.buyNonConsumable(purchaseParam: param);
  }

  Future<void> dispose() async {
    await _subscription?.cancel();
    await _controller.close();
  }
}
