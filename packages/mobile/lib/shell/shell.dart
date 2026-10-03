/// Ads, consent, the ad-removal entitlement, Game Center sign-in and the
/// standard screen shell that reserves the banner-ad slot. Vendored from the
/// portfolio's game-shell starter; this game owns and maintains it now.
library;

export 'ads/ad_service.dart';
export 'ads/admob_config.dart';
export 'ads/admob_ad_service.dart';
export 'ads/fake_ad_service.dart';

export 'consent/consent_service.dart';
export 'consent/ump_consent_service.dart';
export 'consent/fake_consent_service.dart';

export 'auth/app_user.dart';
export 'auth/platform_game_auth_service.dart';
export 'auth/game_center_auth_service.dart';
export 'auth/fake_platform_game_auth_service.dart';

export 'purchases/entitlement_service.dart';
export 'purchases/iap_entitlement_service.dart';
export 'purchases/fake_entitlement_service.dart';

export 'shell/game_screen_shell.dart';
