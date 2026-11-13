import 'consent_service.dart';

/// Deterministic fake for tests: resolves immediately, always permits ads.
class FakeConsentService implements ConsentService {
  FakeConsentService({
    this.canRequestAds = true,
    this.privacyOptionsRequired = false,
  });

  bool requestConsentCalled = false;
  int privacyOptionsShown = 0;

  @override
  final bool canRequestAds;

  @override
  final bool privacyOptionsRequired;

  @override
  Future<void> requestConsent() async {
    requestConsentCalled = true;
  }

  @override
  Future<void> showPrivacyOptions() async {
    privacyOptionsShown++;
  }
}
