import 'package:flutter/widgets.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'ad_service.dart';
import 'admob_config.dart';

/// Real [AdService] backed by Google Mobile Ads. Construct one per app with
/// that app's own [AdMobConfig] — never share ad unit IDs across games.
class AdMobAdService implements AdService {
  AdMobAdService(
    this._config, {
    this.minInterstitialInterval = const Duration(seconds: 30),
  });

  final AdMobConfig _config;
  bool _adFree = false;
  InterstitialAd? _interstitialAd;
  bool _interstitialLoading = false;

  /// Safety net, not the primary control: callers must still only invoke
  /// [showInterstitial] once per round-exit per the [AdService] contract.
  /// This just guarantees that even a caller bug (e.g. a double-tap on an
  /// exit button firing the handler twice) can't show back-to-back
  /// interstitials.
  final Duration minInterstitialInterval;
  DateTime? _lastInterstitialShownAt;

  @override
  Future<void> initialize() async {
    await MobileAds.instance.initialize();
    preloadInterstitial();
  }

  @override
  void setAdFree(bool adFree) {
    _adFree = adFree;
    if (adFree) {
      _interstitialAd?.dispose();
      _interstitialAd = null;
    }
  }

  @override
  bool get isAdFree => _adFree;

  /// Every call gets its own [_BannerAdView], which owns its own [BannerAd]
  /// with a proper create/load/dispose lifecycle. This is deliberate:
  /// [GameScreenShell] is used on several screens, and Flutter can keep more
  /// than one of them mounted at once (route-transition animations, in
  /// particular) — sharing a single `BannerAd`/`AdWidget` pair across every
  /// call site throws "This AdWidget is already in the Widget tree" the
  /// moment two are on screen simultaneously. Found by actually running the
  /// app rather than by the unit tests, which only exercise [FakeAdService].
  @override
  Widget buildBanner() {
    if (_adFree) return const SizedBox.shrink();
    return _BannerAdView(bannerId: _config.bannerId);
  }

  @override
  void preloadInterstitial() {
    if (_adFree || _interstitialLoading || _interstitialAd != null) return;
    _interstitialLoading = true;
    InterstitialAd.load(
      adUnitId: _config.interstitialId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _interstitialAd = ad;
          _interstitialLoading = false;
        },
        onAdFailedToLoad: (error) {
          _interstitialLoading = false;
        },
      ),
    );
  }

  @override
  Future<void> showInterstitial() async {
    if (_adFree || _interstitialAd == null) return;

    final lastShown = _lastInterstitialShownAt;
    if (lastShown != null &&
        DateTime.now().difference(lastShown) < minInterstitialInterval) {
      return;
    }

    final ad = _interstitialAd!;
    _interstitialAd = null;
    _lastInterstitialShownAt = DateTime.now();
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (a) {
        a.dispose();
        preloadInterstitial();
      },
      onAdFailedToShowFullScreenContent: (a, error) {
        a.dispose();
        preloadInterstitial();
      },
    );
    await ad.show();
  }

  @override
  Future<void> dispose() async {
    _interstitialAd?.dispose();
  }
}

class _BannerAdView extends StatefulWidget {
  const _BannerAdView({required this.bannerId});

  final String bannerId;

  @override
  State<_BannerAdView> createState() => _BannerAdViewState();
}

class _BannerAdViewState extends State<_BannerAdView> {
  BannerAd? _ad;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    final ad = BannerAd(
      adUnitId: widget.bannerId,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (_) {
          if (mounted) setState(() => _loaded = true);
        },
        onAdFailedToLoad: (ad, error) => ad.dispose(),
      ),
    );
    _ad = ad;
    ad.load();
  }

  @override
  void dispose() {
    _ad?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ad = _ad;
    if (!_loaded || ad == null) return const SizedBox.shrink();
    return SizedBox(
      width: ad.size.width.toDouble(),
      height: ad.size.height.toDouble(),
      child: AdWidget(ad: ad),
    );
  }
}
