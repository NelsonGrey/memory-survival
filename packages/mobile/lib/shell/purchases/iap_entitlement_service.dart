import 'dart:async';

import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'entitlement_service.dart';

const _kPrefsKey = 'game_shell_ad_free';

/// Shown when the store reports a failure after the purchase request was
/// accepted. Deliberately not the raw StoreKit / Play error: those strings
/// are what a reviewer screenshots for a 2.1(b) rejection.
const purchaseFailedMessage =
    'Remove Ads could not be completed. Please try again.';

const storeUnavailableMessage =
    'The App Store is unavailable right now. Please try again.';

const productUnavailableMessage =
    'Remove Ads is not available from the App Store right now. Please try again later.';

/// The slice of `in_app_purchase` this service uses. A narrow type so tests
/// can drive the purchase stream without starting the real store plugin.
abstract class StoreBilling {
  Stream<List<PurchaseDetails>> get purchaseStream;
  Future<bool> isAvailable();
  Future<ProductDetailsResponse> queryProductDetails(Set<String> identifiers);
  Future<bool> buyNonConsumable({required PurchaseParam purchaseParam});
  Future<void> completePurchase(PurchaseDetails purchase);
  Future<void> restorePurchases();
}

class _PluginBilling implements StoreBilling {
  _PluginBilling() : _iap = InAppPurchase.instance;

  final InAppPurchase _iap;

  @override
  Stream<List<PurchaseDetails>> get purchaseStream => _iap.purchaseStream;

  @override
  Future<bool> isAvailable() => _iap.isAvailable();

  @override
  Future<ProductDetailsResponse> queryProductDetails(Set<String> identifiers) =>
      _iap.queryProductDetails(identifiers);

  @override
  Future<bool> buyNonConsumable({required PurchaseParam purchaseParam}) =>
      _iap.buyNonConsumable(purchaseParam: purchaseParam);

  @override
  Future<void> completePurchase(PurchaseDetails purchase) =>
      _iap.completePurchase(purchase);

  @override
  Future<void> restorePurchases() => _iap.restorePurchases();
}

/// Real [EntitlementService] backed by `in_app_purchase`. Every game passes
/// its own store product ID for the ad-removal purchase (e.g.
/// `memory_survival_remove_ads`) — the product itself must still be created
/// in Play Console / App Store Connect per game.
///
/// v1 scope: local entitlement caching via SharedPreferences, no
/// server-side receipt verification. The single ad-removal SKU has no
/// economy beyond hiding ads.
class IapEntitlementService implements EntitlementService {
  IapEntitlementService({
    required String adRemovalProductId,
    StoreBilling? billing,
  }) : _productId = adRemovalProductId,
       _billing = billing ?? _PluginBilling();

  final String _productId;
  final StoreBilling _billing;
  final _controller = StreamController<bool>.broadcast();
  final _errors = StreamController<String>.broadcast();
  StreamSubscription<List<PurchaseDetails>>? _subscription;
  bool _adFree = false;

  @override
  bool get isAdFree => _adFree;

  @override
  Stream<bool> get adFreeChanges => _controller.stream;

  @override
  Stream<String> get purchaseErrors => _errors.stream;

  void _setAdFree(bool value) {
    if (_adFree == value) return;
    _adFree = value;
    _controller.add(value);
    SharedPreferences.getInstance().then((p) => p.setBool(_kPrefsKey, value));
  }

  void _fail(String message) {
    if (!_errors.isClosed) _errors.add(message);
  }

  @override
  Future<void> restore() async {
    final prefs = await SharedPreferences.getInstance();
    _adFree = prefs.getBool(_kPrefsKey) ?? false;
    if (_adFree) _controller.add(true);

    // Subscribe before talking to the store. An unfinished transaction from
    // a previous launch is delivered as soon as something listens, and
    // leaving it unfinished makes the next purchase of this product fail.
    _subscription ??= _billing.purchaseStream.listen(
      _handleUpdates,
      onError: (Object _) => _fail(purchaseFailedMessage),
    );

    final available = await _billing.isAvailable();
    if (available) {
      await _billing.restorePurchases();
    }
  }

  void _handleUpdates(List<PurchaseDetails> purchases) {
    for (final purchase in purchases) {
      final ours = purchase.productID == _productId;
      if (ours &&
          (purchase.status == PurchaseStatus.purchased ||
              purchase.status == PurchaseStatus.restored)) {
        _setAdFree(true);
      } else if (ours && purchase.status == PurchaseStatus.error) {
        _fail(purchaseFailedMessage);
      }
      // Purchased, restored, canceled, and error can all sit in the
      // unfinished queue. completePurchase is required for each of them
      // when the plugin says so; pending must not be completed.
      if (purchase.status != PurchaseStatus.pending &&
          purchase.pendingCompletePurchase) {
        unawaited(_billing.completePurchase(purchase));
      }
    }
  }

  @override
  Future<String?> loadAdRemovalPrice() async {
    try {
      if (!await _billing.isAvailable()) return null;
      final response = await _billing.queryProductDetails({_productId});
      if (response.productDetails.isEmpty) return null;
      return response.productDetails.first.price;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> purchaseAdRemoval() async {
    final available = await _billing.isAvailable();
    if (!available) {
      throw const PurchaseFlowException(storeUnavailableMessage);
    }

    final response = await _billing.queryProductDetails({_productId});
    if (response.notFoundIDs.contains(_productId) ||
        response.productDetails.isEmpty) {
      throw const PurchaseFlowException(productUnavailableMessage);
    }

    final param = PurchaseParam(productDetails: response.productDetails.first);
    final started = await _billing.buyNonConsumable(purchaseParam: param);
    if (!started) {
      throw const PurchaseFlowException(purchaseFailedMessage);
    }
  }

  Future<void> dispose() async {
    await _subscription?.cancel();
    await _controller.close();
    await _errors.close();
  }
}
