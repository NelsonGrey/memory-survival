import 'dart:async';

import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'consent_service.dart';

/// Real [ConsentService] using Google's User Messaging Platform, which
/// covers both GDPR consent and (via its iOS integration) App Tracking
/// Transparency in one flow.
///
/// The form is shown only when the SDK says one is required, and ads are
/// requested only when [ConsentInformation.canRequestAds] says so. A hung
/// network call cannot leave the game on the launch spinner. A form the
/// player is still reading when that cap expires still updates [changes]
/// when they finally dismiss it.
class UmpConsentService implements ConsentService {
  bool _canRequestAds = false;
  bool _privacyOptionsRequired = false;
  final _changes = StreamController<void>.broadcast();

  @override
  bool get canRequestAds => _canRequestAds;

  @override
  bool get privacyOptionsRequired => _privacyOptionsRequired;

  @override
  Stream<void> get changes => _changes.stream;

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
      // The update can still succeed after startup has moved on. Show the
      // form then; [changes] tells the app to apply the new decision.
      unawaited(updated.future.then((_) => _showForm()));
      await _readFlags();
      return;
    }

    await _showForm();
  }

  Future<void> _showForm() async {
    final dismissed = Completer<void>();
    try {
      // Resolves when the form is dismissed, or immediately when no form
      // is required. The three-minute cap is only for a form that never
      // calls back; a player reading the form is not cut off at 12 seconds.
      await ConsentForm.loadAndShowConsentFormIfRequired((formError) {
        if (!dismissed.isCompleted) dismissed.complete();
      }).timeout(const Duration(minutes: 3));
      await _readFlags();
    } on TimeoutException {
      await _readFlags();
      // The form is still on screen. Dismissal runs the callback above.
      unawaited(dismissed.future.then((_) => _readFlags()));
    } catch (_) {
      await _readFlags();
    }
  }

  @override
  Future<void> showPrivacyOptions() async {
    try {
      await ConsentForm.showPrivacyOptionsForm((formError) {});
    } catch (_) {}
    await _readFlags();
  }

  Future<void> _readFlags() async {
    var canRequest = _canRequestAds;
    var privacyRequired = _privacyOptionsRequired;
    try {
      canRequest = await ConsentInformation.instance.canRequestAds();
    } catch (_) {
      canRequest = false;
    }
    try {
      final status = await ConsentInformation.instance
          .getPrivacyOptionsRequirementStatus();
      privacyRequired = status == PrivacyOptionsRequirementStatus.required;
    } catch (_) {
      privacyRequired = false;
    }
    final changed =
        canRequest != _canRequestAds ||
        privacyRequired != _privacyOptionsRequired;
    _canRequestAds = canRequest;
    _privacyOptionsRequired = privacyRequired;
    if (changed && !_changes.isClosed) _changes.add(null);
  }
}
