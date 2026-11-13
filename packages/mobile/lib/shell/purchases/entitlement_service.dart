/// The single ad-removal purchase every game in the portfolio sells (see
/// each BRD's Monetization hypothesis: "a single one-time in-app purchase
/// disables all ads permanently. This is the only purchase in the MVP.").
/// A purchase that could not be started, written for the player.
///
/// [message] is a complete sentence. It never includes a product id, an
/// exception class, or a stack trace — App Review screenshots those.
class PurchaseFlowException implements Exception {
  const PurchaseFlowException(this.message);

  final String message;

  @override
  String toString() => message;
}

abstract class EntitlementService {
  /// Loads any previously-granted entitlement from the platform store.
  /// Call once at startup before wiring [AdService.setAdFree].
  Future<void> restore();

  Stream<bool> get adFreeChanges;
  bool get isAdFree;

  /// Failures reported on the store's purchase stream after
  /// [purchaseAdRemoval] has already returned (the payment sheet, a
  /// restored transaction, or a transaction left unfinished).
  Stream<String> get purchaseErrors;

  /// The store's localized price, such as "\$2.99", or null when the
  /// product could not be loaded. Never a price typed into the app.
  Future<String?> loadAdRemovalPrice();

  /// Starts the platform purchase flow for the ad-removal product. Resolves
  /// once the store has accepted the request, not when the payment sheet
  /// finishes. Throws [PurchaseFlowException] when the store or the product
  /// is unavailable. A later failure arrives on [purchaseErrors].
  Future<void> purchaseAdRemoval();
}
