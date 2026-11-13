import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:memory_survival/app/app_services.dart';
import 'package:memory_survival/gamecenter/fake_game_center_progress_service.dart';
import 'package:memory_survival/shell/ads/fake_ad_service.dart';
import 'package:memory_survival/shell/auth/fake_platform_game_auth_service.dart';
import 'package:memory_survival/shell/consent/fake_consent_service.dart';
import 'package:memory_survival/shell/purchases/fake_entitlement_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Holds [initialize] open so a purchase can arrive while the SDK is starting.
class _SlowAds extends FakeAdService {
  final started = Completer<void>();
  final release = Completer<void>();

  @override
  Future<void> initialize() async {
    initializeCalled = true;
    if (!started.isCompleted) started.complete();
    await release.future;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  AppServices services({
    required FakeConsentService consent,
    required FakeEntitlementService entitlement,
    required FakeAdService ads,
  }) {
    return AppServices(
      consent: consent,
      entitlement: entitlement,
      ads: ads,
      auth: FakePlatformGameAuthService(),
      progress: FakeGameCenterProgressService(),
      openUrl: (_) async {},
    );
  }

  test('a restore that lands during ad startup still removes ads', () async {
    final ads = _SlowAds();
    final entitlement = FakeEntitlementService();
    final app = services(
      consent: FakeConsentService(),
      entitlement: entitlement,
      ads: ads,
    );

    final pending = app.initialize();
    await ads.started.future;
    await entitlement.purchaseAdRemoval();
    ads.release.complete();
    await pending;

    expect(ads.isAdFree, isTrue);
  });

  test('consent granted after startup starts ads', () async {
    final ads = FakeAdService();
    final consent = FakeConsentService(canRequestAds: false);
    final app = services(
      consent: consent,
      entitlement: FakeEntitlementService(),
      ads: ads,
    );

    await app.initialize();
    expect(ads.initializeCalled, isFalse);
    expect(ads.isAdFree, isTrue);

    consent.canRequestAds = true;
    consent.notifyChanged();
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);

    expect(ads.initializeCalled, isTrue);
    expect(ads.isAdFree, isFalse);
  });
}
