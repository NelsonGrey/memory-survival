import 'dart:async';

import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'consent_service.dart';

/// Real [ConsentService] using Google's User Messaging Platform, which
/// covers both GDPR consent and (via its iOS integration) App Tracking
/// Transparency in one flow.
class UmpConsentService implements ConsentService {
  bool _canRequestAds = false;

  @override
  Future<void> requestConsent() async {
    final params = ConsentRequestParameters();
    final completer = Completer<void>();

    ConsentInformation.instance.requestConsentInfoUpdate(params, () async {
      if (await ConsentInformation.instance.isConsentFormAvailable()) {
        await _loadAndShowForm(completer);
      } else {
        _resolve(completer);
      }
    }, (formError) => _resolve(completer));

    return completer.future;
  }

  Future<void> _loadAndShowForm(Completer<void> completer) async {
    ConsentForm.loadConsentForm((consentForm) {
      consentForm.show((formError) => _resolve(completer));
    }, (formError) => _resolve(completer));
  }

  void _resolve(Completer<void> completer) {
    _canRequestAds = true;
    if (!completer.isCompleted) completer.complete();
  }

  @override
  bool get canRequestAds => _canRequestAds;
}
