import 'dart:async';

import 'entitlement_service.dart';

/// Deterministic in-memory [EntitlementService] for tests: no store calls,
/// [purchaseAdRemoval] grants the entitlement immediately.
class FakeEntitlementService implements EntitlementService {
  /// When true, [restore] finds a previous purchase and grants the
  /// entitlement, like the store replaying a past ad-removal purchase.
  ///
  /// [purchaseFailure] is thrown from [purchaseAdRemoval] instead of
  /// granting, so tests can assert the player-facing message.
  FakeEntitlementService({
    this.hasPreviousPurchase = false,
    this.purchaseFailure,
    this.priceLabel = r'$2.99',
  });

  final bool hasPreviousPurchase;
  final String? purchaseFailure;
  final String? priceLabel;
  final _controller = StreamController<bool>.broadcast();
  final _errors = StreamController<String>.broadcast();
  bool _adFree = false;

  @override
  Future<void> restore() async {
    if (!hasPreviousPurchase) return;
    _adFree = true;
    _controller.add(true);
  }

  @override
  Stream<bool> get adFreeChanges => _controller.stream;

  @override
  bool get isAdFree => _adFree;

  @override
  Stream<String> get purchaseErrors => _errors.stream;

  @override
  Future<String?> loadAdRemovalPrice() async => priceLabel;

  @override
  Future<void> purchaseAdRemoval() async {
    final failure = purchaseFailure;
    if (failure != null) throw PurchaseFlowException(failure);
    _adFree = true;
    _controller.add(true);
  }
}
