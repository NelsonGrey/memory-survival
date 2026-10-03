import 'dart:async';

import 'entitlement_service.dart';

/// Deterministic in-memory [EntitlementService] for tests: no store calls,
/// [purchaseAdRemoval] grants the entitlement immediately.
class FakeEntitlementService implements EntitlementService {
  /// When true, [restore] finds a previous purchase and grants the
  /// entitlement, like the store replaying a past ad-removal purchase.
  FakeEntitlementService({this.hasPreviousPurchase = false});

  final bool hasPreviousPurchase;
  final _controller = StreamController<bool>.broadcast();
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
  Future<void> purchaseAdRemoval() async {
    _adFree = true;
    _controller.add(true);
  }
}
