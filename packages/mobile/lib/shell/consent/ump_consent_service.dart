import 'dart:async';

import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'consent_service.dart';

/// Real [ConsentService] using Google's User Messaging Platform, which
/// covers both GDPR consent and (via its iOS integration) App Tracking
/// Transparency in one flow.
///
/// The form is shown only when the SDK says one is required, and ads are
/// requested only when [ConsentInformation.canRequestAds] says so. A hung
/// network call cannot leave the game on the launch spinner.
class UmpConsentService implements ConsentService {
  bool _canRequestAds = false;
  bool _privacyOptionsRequired = false;

  @override
  bool get canRequestAds => _canRequestAds;

  @override
  bool get privacyOptionsRequired => _privacyOptionsRequired;

  @override
  Future<void> requestConsent() async {
    final updated = Completer<void>();
    ConsentInformation.instance.requestConsentInfoUpdate(
      ConsentRequestParameters(),
      () {
        if (!updated.isCompleted) updated.complete();
      },
      (formError) {
        if (!updated.isCompleted) updated.complete();
      },
    );

    try {
      await updated.future.timeout(const Duration(seconds: 12));
    } on TimeoutException {
      await _readFlags();
      return;
    }

    try {
      // Resolves when the form is dismissed, or immediately when no form
      // is required. The three-minute cap is only for a form that never
      // calls back; a player reading the form is not cut off at 12 seconds.
      await ConsentForm.loadAndShowConsentFormIfRequired(
        (formError) {},
      ).timeout(const Duration(minutes: 3));
    } catch (_) {
      // A failed or abandoned form still leaves a decision to read below.
    }
    await _readFlags();
  }

  @override
  Future<void> showPrivacyOptions() async {
    try {
      await ConsentForm.showPrivacyOptionsForm((formError) {});
    } catch (_) {}
    await _readFlags();
  }

  Future<void> _readFlags() async {
    try {
      _canRequestAds = await ConsentInformation.instance.canRequestAds();
    } catch (_) {
      _canRequestAds = false;
    }
    try {
      final status = await ConsentInformation.instance
          .getPrivacyOptionsRequirementStatus();
      _privacyOptionsRequired =
          status == PrivacyOptionsRequirementStatus.required;
    } catch (_) {
      _privacyOptionsRequired = false;
    }
  }
}
