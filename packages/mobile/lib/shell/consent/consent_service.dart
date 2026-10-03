/// GDPR/UMP + App Tracking Transparency consent, resolved once before any
/// [AdService] is initialized. Every game's TRD requires ad requests to wait
/// on this — see e.g. MAS-TR-015.
abstract class ConsentService {
  /// Runs the platform consent flow (UMP form if required by the player's
  /// region, ATT prompt on iOS). Completes once a decision is known, even if
  /// the player declines — a decision, not consent itself, unblocks ads
  /// (non-personalized ads are still shown to a player who declines).
  Future<void> requestConsent();

  /// Whether it's safe to initialize the ad SDK and request ads.
  bool get canRequestAds;
}
