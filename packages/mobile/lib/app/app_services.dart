import 'dart:io';

import '../shell/shell.dart';
import 'package:url_launcher/url_launcher.dart' as url_launcher;

import '../engine/engine.dart';
import '../gamecenter/connection_gated_progress_service.dart';
import '../gamecenter/fake_game_center_progress_service.dart';
import '../gamecenter/game_center_connection.dart';
import '../gamecenter/game_center_progress_service.dart';
import '../gamecenter/games_services_progress_service.dart';
import '../settings/best_score.dart';
import '../settings/daily_challenge.dart';
import '../settings/difficulty_setting.dart';
import '../settings/personal_bests.dart';
import '../settings/scenario_progress.dart';
import '../settings/suggestions_setting.dart';
import '../settings/how_to_play_setting.dart';
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
    RelaxedClockSetting? relaxedClock,
    DifficultySetting? difficulty,
    BestScore? bestScore,
    PersonalBests? personalBests,
    DailyChallenge? daily,
    ScenarioProgress? scenarioProgress,
    SuggestionsSetting? suggestions,
    HowToPlaySetting? howToPlay,
    UrlOpener? openUrl,
  }) : theme = theme ?? ThemeController(),
       relaxedClock = relaxedClock ?? RelaxedClockSetting(),
       difficulty = difficulty ?? DifficultySetting(),
       bestScore = bestScore ?? BestScore(),
       personalBests = personalBests ?? PersonalBests(),
       daily = daily ?? DailyChallenge(),
       scenarioProgress = scenarioProgress ?? ScenarioProgress(),
       suggestions = suggestions ?? SuggestionsSetting(),
       howToPlay = howToPlay ?? HowToPlaySetting(),
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
    // On every successful sign-in, grant what was earned while disconnected
    // and push this device's best endless score, which a disconnected run
    // could not submit. Game Center keeps only the better score, so
    // re-sending is harmless.
    this.connection.onConnected = () async {
      await this.progress.flushEarned();
      final best = this.bestScore.bestFor(Difficulty.normal);
      if (best > 0) await this.progress.submitScore(best);
    };
    this.difficulty.addListener(
      () => this.bestScore.select(this.difficulty.value),
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

  /// Accessibility: doubles simulation ticks when on.
  final RelaxedClockSetting relaxedClock;

  /// Endless-mode difficulty, read when a run starts.
  final DifficultySetting difficulty;

  /// Best endless score on this device, per difficulty and ruleset version.
  final BestScore bestScore;

  /// Longest streak, largest rescue and most waves, per ruleset version.
  final PersonalBests personalBests;

  /// Today's shared seed and the best score on it.
  final DailyChallenge daily;

  /// Objectives met in each authored scenario.
  final ScenarioProgress scenarioProgress;

  /// The optional one-tap placement suggestion (no multiplier).
  final SuggestionsSetting suggestions;

  /// Whether the player has seen the how-to-play screen.
  final HowToPlaySetting howToPlay;

  /// Opens the Privacy/Terms/Support links in Settings.
  final UrlOpener openUrl;

  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    await theme.load();
    await relaxedClock.load();
    await difficulty.load();
    await bestScore.load();
    bestScore.select(difficulty.value);
    await personalBests.load();
    await daily.load();
    await scenarioProgress.load();
    await suggestions.load();
    await howToPlay.load();
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
