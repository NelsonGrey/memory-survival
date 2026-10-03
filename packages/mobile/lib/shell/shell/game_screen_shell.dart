import 'package:flutter/widgets.dart';

import '../ads/ad_service.dart';

/// Standard screen layout for every game: a persistent banner-ad slot
/// pinned to the top (inside the top [SafeArea]) with the game's own
/// content below it. Every game should build its screens on top of this
/// instead of reinventing ad placement per game.
///
/// [showBanner] should be `true` on every non-gameplay screen — menu,
/// select, settings, results — and on the *pause overlay*, which is the
/// same route as the gameplay screen with different state, not a separate
/// screen. In practice that means the gameplay screen's own build method
/// should pass `showBanner: isPaused` (or equivalently `!isActivelyResolving`)
/// rather than a static value, so the banner appears the instant the player
/// pauses and disappears the instant they resume.
///
/// Binary Rhythm Game is the one documented exception: its BRD requires no
/// ad of any kind, including the banner, during active song performance —
/// reserving full screen space matters more than ad density for a
/// timing-critical game. Its pause overlay still follows the normal rule.
///
/// [showInterstitial] on [AdService] is a separate concern from this
/// widget — call it once per round-exit in the navigation code that leaves
/// the gameplay screen, not from here.
class GameScreenShell extends StatelessWidget {
  const GameScreenShell({
    super.key,
    required this.adService,
    required this.body,
    this.showBanner = true,
  });

  final AdService adService;
  final Widget body;
  final bool showBanner;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SafeArea(
          bottom: false,
          child: showBanner ? adService.buildBanner() : const SizedBox.shrink(),
        ),
        Expanded(child: body),
      ],
    );
  }
}
