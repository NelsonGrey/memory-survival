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
  ///
  /// This is the UMP SDK's own answer after [requestConsent], not a value
  /// the app forces to true. It stays false when consent is required and
  /// has not been gathered.
  bool get canRequestAds;

  /// True when the privacy message requires an in-app entry point so the
  /// player can change their choice. False everywhere else, including the
  /// US when no such message is configured.
  bool get privacyOptionsRequired;

  /// Presents that entry point. No-op when [privacyOptionsRequired] is false.
  Future<void> showPrivacyOptions();

  /// Fires when [canRequestAds] or [privacyOptionsRequired] changes after
  /// [requestConsent] has already returned. That happens when the player
  /// leaves the consent form open past the startup cap and dismisses it
  /// later, or when they change their choice from [showPrivacyOptions].
  Stream<void> get changes;
}
