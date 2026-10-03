import 'package:flutter/widgets.dart';

/// Ad layer behind an interface so every game can use a deterministic fake
/// in tests (see [MAS-TR-015]
/// in TECHNICAL_REQUIREMENTS.md) and swap in the
/// real AdMob implementation only in the running app.
///
/// Contract every implementation must honor:
/// - No ad request is made before [ConsentService] reports a decision.
/// - No ad request is made once [setAdFree] has been called with `true`.
/// - A banner widget built while ad-free must be a zero-size [SizedBox].
///
/// Portfolio-wide ad placement rule (see each game's `*-BR-015`/`*-TR-015`):
/// - [buildBanner] belongs on every non-gameplay screen — menu, select,
///   settings, results, and the pause overlay — via [GameScreenShell]. Never
///   during active gameplay resolution.
/// - [showInterstitial] is called exactly once per completed/exited round,
///   on the way back to a non-gameplay screen. It must never be called to
///   gate the *start* of a round, and never on ordinary menu navigation
///   (e.g. opening settings from the main menu). A real implementation
///   should also enforce a minimum interval between shows as a safety net
///   against a caller accidentally invoking it too often — see
///   [AdMobAdService]'s `minInterstitialInterval`.
abstract class AdService {
  /// One-time SDK initialization. Must be called after consent is resolved.
  Future<void> initialize();

  /// Whether ads are currently suppressed (the ad-removal entitlement is
  /// active). [GameScreenShell] and [showInterstitial] both consult this.
  void setAdFree(bool adFree);
  bool get isAdFree;

  /// Builds the persistent top banner. Returns an empty [SizedBox] when
  /// [isAdFree] is true or the banner hasn't finished loading yet.
  Widget buildBanner();

  /// Loads an interstitial in the background so it's ready when
  /// [showInterstitial] is called at the next round-exit.
  void preloadInterstitial();

  /// Shows the preloaded interstitial if one is ready and the player is not
  /// ad-free. Call this exactly once when a round ends, on the way back to
  /// a non-gameplay screen — never during active core-gameplay resolution,
  /// never to gate the start of a round, and never on ordinary menu
  /// navigation. See each game's BRD ad-placement requirement.
  Future<void> showInterstitial();

  Future<void> dispose();
}
