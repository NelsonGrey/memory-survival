import 'consent_service.dart';

/// Deterministic fake for tests: resolves immediately, always permits ads.
class FakeConsentService implements ConsentService {
  bool requestConsentCalled = false;

  @override
  Future<void> requestConsent() async {
    requestConsentCalled = true;
  }

  @override
  bool get canRequestAds => true;
}
