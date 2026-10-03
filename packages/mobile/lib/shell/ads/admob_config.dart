import 'dart:io';

/// Per-game AdMob configuration. Every game constructs one of these with its
/// own store-assigned IDs — nothing here is shared across games, only the
/// shape is. Test unit IDs are Google's public sample IDs and are safe to
/// commit; production IDs are not secret but are still constructor-injected
/// rather than hardcoded so this package stays game-agnostic.
class AdMobConfig {
  const AdMobConfig({
    required this.androidAppId,
    required this.iosAppId,
    required this.androidBannerId,
    required this.iosBannerId,
    required this.androidInterstitialId,
    required this.iosInterstitialId,
  });

  /// Google's shared public test IDs. Safe default for dev builds before a
  /// game has its own AdMob app/unit IDs provisioned.
  factory AdMobConfig.test() => const AdMobConfig(
    androidAppId: 'ca-app-pub-3940256099942544~3347511713',
    iosAppId: 'ca-app-pub-3940256099942544~1458002511',
    androidBannerId: 'ca-app-pub-3940256099942544/6300978111',
    iosBannerId: 'ca-app-pub-3940256099942544/2934735716',
    androidInterstitialId: 'ca-app-pub-3940256099942544/1033173712',
    iosInterstitialId: 'ca-app-pub-3940256099942544/4411468910',
  );

  final String androidAppId;
  final String iosAppId;
  final String androidBannerId;
  final String iosBannerId;
  final String androidInterstitialId;
  final String iosInterstitialId;

  String get appId => Platform.isAndroid ? androidAppId : iosAppId;
  String get bannerId => Platform.isAndroid ? androidBannerId : iosBannerId;
  String get interstitialId =>
      Platform.isAndroid ? androidInterstitialId : iosInterstitialId;
}
