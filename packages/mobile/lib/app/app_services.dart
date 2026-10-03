import 'dart:io';

import '../shell/shell.dart';
import 'package:url_launcher/url_launcher.dart' as url_launcher;

import '../gamecenter/connection_gated_progress_service.dart';
import '../gamecenter/fake_game_center_progress_service.dart';
import '../gamecenter/game_center_connection.dart';
import '../gamecenter/game_center_progress_service.dart';
import '../gamecenter/games_services_progress_service.dart';
import '../layout/game_layout.dart';
import '../settings/relaxed_clock_setting.dart';
import '../theme/theme_controller.dart';

/// Opens a URL in the device's browser. A function, not a call straight to
/// `url_launcher`, so widget tests can inject a fake instead of hitting a
/// real platform channel.
typedef UrlOpener = Future<void> Function(Uri url);

Future<void> _defaultOpenUrl(Uri url) => url_launcher.launchUrl(
  url,
  mode: url_launcher.LaunchMode.externalApplication,
);

/// The ad-removal product ID. Must match the in-app purchase created in App
/// Store Connect (see docs/STORE_SETUP.md).
const adRemovalProductId = 'memory_survival_remove_ads';

/// The app's services (ads, consent, purchases, Game Center, settings),
/// wired in dependency order by [initialize].
class AppServices {
  AppServices({
    ConsentService? consent,
    EntitlementService? entitlement,
    AdService? ads,
    PlatformGameAuthService? auth,
    GameCenterProgressService? progress,
    GameCenterConnection? connection,
    ThemeController? theme,
    LayoutController? layout,
    RelaxedClockSetting? relaxedClock,
    UrlOpener? openUrl,
  }) : theme = theme ?? ThemeController(),
       layout = layout ?? LayoutController(),
       relaxedClock = relaxedClock ?? RelaxedClockSetting(),
       openUrl = openUrl ?? _defaultOpenUrl,
       consent = consent ?? UmpConsentService(),
       entitlement =
           entitlement ??
           IapEntitlementService(adRemovalProductId: adRemovalProductId),
       // Google's public test IDs until this game has its own AdMob app and
       // units provisioned (docs/STORE_SETUP.md). Never reuse another game's
       // production IDs.
       ads = ads ?? AdMobAdService(AdMobConfig.test()),
       auth = auth ?? _defaultAuth(),
       progressBackend = progress ?? _defaultProgress() {
    this.connection =
        connection ??
        GameCenterConnection(auth: this.auth, supported: _gcSupported);
    this.progress = ConnectionGatedProgressService(
      progressBackend,
      this.connection,
    );
  }

  final ConsentService consent;
  final EntitlementService entitlement;
  final AdService ads;

  /// Game Center on iOS/macOS. Android falls back to a fake — Play Games
  /// Services isn't wired up yet.
  final PlatformGameAuthService auth;

  static PlatformGameAuthService _defaultAuth() =>
      (Platform.isIOS || Platform.isMacOS)
      ? GameCenterAuthService()
      : FakePlatformGameAuthService();

  static bool get _gcSupported => Platform.isIOS || Platform.isMacOS;

  /// Whether the player has opted in to Game Center, and whether it's live.
  /// Nothing talks to Game Center until they connect.
  late final GameCenterConnection connection;

  /// The real (or fake) Game Center calls, same iOS/macOS-only story as
  /// [auth]. Always reach them through [progress], which honors the
  /// player's choice.
  final GameCenterProgressService progressBackend;

  /// Leaderboard/achievements/cloud save, active only while [connection] is
  /// connected — see [GameCenterProgressService].
  late final ConnectionGatedProgressService progress;

  static GameCenterProgressService _defaultProgress() =>
      (Platform.isIOS || Platform.isMacOS)
      ? GamesServicesProgressService()
      : FakeGameCenterProgressService();

  /// The player's gameplay palette. Not a platform service — it lives
  /// here so every screen reaches it the same way.
  final ThemeController theme;

  /// The player's gameplay layout.
  final LayoutController layout;

  /// Accessibility: doubles simulation ticks when on.
  final RelaxedClockSetting relaxedClock;

  /// Opens the Privacy/Terms/Support links in Settings.
  final UrlOpener openUrl;

  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    await theme.load();
    await layout.load();
    await relaxedClock.load();
    await consent.requestConsent();
    await entitlement.restore();

    // Only reconnects a player who already opted in; a failed sign-in (e.g.
    // no Game Center account on this device) lands in
    // GameCenterStatus.unavailable and never blocks the app from starting.
    await connection.load();

    if (consent.canRequestAds) {
      await ads.initialize();
    }
    ads.setAdFree(entitlement.isAdFree);
    entitlement.adFreeChanges.listen(ads.setAdFree);
  }
}
