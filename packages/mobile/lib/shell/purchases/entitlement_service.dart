/// The single ad-removal purchase every game in the portfolio sells (see
/// each BRD's Monetization hypothesis: "a single one-time in-app purchase
/// disables all ads permanently. This is the only purchase in the MVP.").
abstract class EntitlementService {
  /// Loads any previously-granted entitlement from the platform store.
  /// Call once at startup before wiring [AdService.setAdFree].
  Future<void> restore();

  Stream<bool> get adFreeChanges;
  bool get isAdFree;

  /// Starts the platform purchase flow for the ad-removal product. Resolves
  /// once the flow completes (success, cancel, or error); check
  /// [isAdFree] afterward rather than relying on a return value, since the
  /// purchase may complete asynchronously (e.g. parental approval).
  Future<void> purchaseAdRemoval();
}
