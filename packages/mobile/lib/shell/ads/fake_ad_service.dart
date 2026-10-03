import 'package:flutter/widgets.dart';

import 'ad_service.dart';

/// Deterministic in-memory [AdService] for widget/unit tests and for
/// running the app without hitting real ad networks. Never makes a network
/// call; just tracks call counts so tests can assert on behavior.
class FakeAdService implements AdService {
  bool _adFree = false;
  bool initializeCalled = false;
  int interstitialShownCount = 0;
  int interstitialPreloadCount = 0;

  @override
  Future<void> initialize() async {
    initializeCalled = true;
  }

  @override
  void setAdFree(bool adFree) => _adFree = adFree;

  @override
  bool get isAdFree => _adFree;

  @override
  Widget buildBanner() {
    if (_adFree) return const SizedBox.shrink();
    return Container(
      key: const Key('fake_banner_ad'),
      height: 50,
      alignment: Alignment.center,
      child: const Text('TEST BANNER AD'),
    );
  }

  @override
  void preloadInterstitial() {
    interstitialPreloadCount++;
  }

  @override
  Future<void> showInterstitial() async {
    if (_adFree) return;
    interstitialShownCount++;
  }

  @override
  Future<void> dispose() async {}
}
