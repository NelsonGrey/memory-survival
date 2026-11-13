import 'dart:async';

import 'consent_service.dart';

/// Deterministic fake for tests: resolves immediately, always permits ads.
class FakeConsentService implements ConsentService {
  FakeConsentService({
    this.canRequestAds = true,
    this.privacyOptionsRequired = false,
  });

  bool requestConsentCalled = false;
  int privacyOptionsShown = 0;
  final _changes = StreamController<void>.broadcast();

  @override
  bool canRequestAds;

  @override
  final bool privacyOptionsRequired;

  @override
  Stream<void> get changes => _changes.stream;

  /// Test hook for a consent decision that arrives after startup.
  void notifyChanged() {
    if (!_changes.isClosed) _changes.add(null);
  }

  @override
  Future<void> requestConsent() async {
    requestConsentCalled = true;
  }

  @override
  Future<void> showPrivacyOptions() async {
    privacyOptionsShown++;
  }
}
