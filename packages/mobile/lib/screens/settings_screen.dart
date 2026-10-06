import 'dart:async';

import 'package:flutter/material.dart';
import '../shell/shell.dart';

import '../app/app_services.dart';
import '../gamecenter/game_center_connection.dart';
import '../settings/unlocks.dart';
import '../theme/game_theme.dart';
import 'ad_top_scaffold.dart';

/// Settings: the gameplay palette (Appearance), Game Center, the ad-removal
/// purchase (Purchases), and the relaxed clock (Accessibility). A
/// non-gameplay screen, so it carries the banner like every other menu
/// (MAS-BR-015).
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key, required this.services});

  final AppServices services;

  @override
  Widget build(BuildContext context) {
    return AdTopScaffold(
      adService: services.ads,
      title: 'Settings',
      body: ListenableBuilder(
        listenable: Listenable.merge([
          services.theme,
          services.relaxedClock,
          services.suggestions,
          services.personalBests,
          services.scenarioProgress,
        ]),
        builder: (context, _) => ListView(
          padding: const EdgeInsets.symmetric(vertical: 8),
          children: [
            const _SectionHeader('Appearance'),
            for (final id in gameThemeOrder) _paletteTile(context, id),
            const SizedBox(height: 16),
            if (services.connection.supported) ...[
              const _SectionHeader('Game Center'),
              ListenableBuilder(
                listenable: services.connection,
                builder: (context, _) => _GameCenterSection(services: services),
              ),
            ],
            const SizedBox(height: 16),
            const _SectionHeader('Purchases'),
            _PurchaseSection(entitlement: services.entitlement),
            const SizedBox(height: 16),
            const _SectionHeader('Accessibility'),
            SwitchListTile(
              title: const Text('Relaxed clock'),
              subtitle: const Text('Each clock tick lasts twice as long'),
              value: services.relaxedClock.value,
              onChanged: services.relaxedClock.set,
            ),
            const SizedBox(height: 16),
            const _SectionHeader('Gameplay assists'),
            SwitchListTile(
              title: const Text('Suggested placement'),
              subtitle: const Text(
                'Adds a one-tap button that places a request in the tidiest '
                'spot. Those requests earn no clean-run multiplier.',
              ),
              value: services.suggestions.value,
              onChanged: services.suggestions.set,
            ),
            const SizedBox(height: 16),
            const _SectionHeader('Legal'),
            _LegalLink(
              label: 'Privacy Policy',
              url: legalUrls.privacy,
              openUrl: services.openUrl,
            ),
            _LegalLink(
              label: 'Terms of Use',
              url: legalUrls.terms,
              openUrl: services.openUrl,
            ),
            _LegalLink(
              label: 'Support',
              url: legalUrls.support,
              openUrl: services.openUrl,
            ),
          ],
        ),
      ),
    );
  }
}

extension on SettingsScreen {
  Widget _paletteTile(BuildContext context, GameThemeId id) {
    final unlocked = isPaletteUnlocked(
      id,
      services.personalBests,
      services.scenarioProgress,
    );
    return _PaletteTile(
      palette: gameThemePalettes[id]!,
      selected: id == services.theme.value,
      requirement: unlocked ? null : paletteUnlocks[id]!.requirement,
      onTap: unlocked
          ? () => services.theme.select(id)
          : () => ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Locked: ${paletteUnlocks[id]!.requirement}'),
              ),
            ),
    );
  }
}

/// Where this game's Privacy/Terms/Support pages live. Memory Survival has
/// no marketing site of its own (unlike Modulo Squares, which has a
/// separate site/repo/domain) — these are lightweight pages on the Nelson
/// Grey site instead; see docs/STORE_SETUP.md.
class _LegalUrls {
  const _LegalUrls();

  static const _base = 'https://nelsongrey.com/games/memory-survival';

  Uri get privacy => Uri.parse('$_base/privacy');
  Uri get terms => Uri.parse('$_base/terms');
  Uri get support => Uri.parse('$_base/support');
}

const legalUrls = _LegalUrls();

class _LegalLink extends StatelessWidget {
  const _LegalLink({
    required this.label,
    required this.url,
    required this.openUrl,
  });

  final String label;
  final Uri url;
  final UrlOpener openUrl;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(label),
      trailing: const Icon(Icons.open_in_new, size: 18),
      onTap: () => openUrl(url),
    );
  }
}

/// Ad-free status, the one-time "Remove Ads" purchase (MAS-BR-007: a
/// single $2.99 IAP, matching Modulo Squares), and Restore Purchases.
/// [EntitlementService] isn't a [Listenable] — it reports changes on
/// [EntitlementService.adFreeChanges] instead — so this rebuilds off a
/// [StreamBuilder], seeded with the already-loaded [isAdFree] value.
class _PurchaseSection extends StatelessWidget {
  const _PurchaseSection({required this.entitlement});

  final EntitlementService entitlement;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<bool>(
      stream: entitlement.adFreeChanges,
      initialData: entitlement.isAdFree,
      builder: (context, snapshot) {
        final adFree = snapshot.data ?? false;
        return Column(
          children: [
            ListTile(
              leading: Icon(
                adFree ? Icons.check_circle_outline : Icons.tv_off_outlined,
              ),
              title: Text(adFree ? 'Ad-free' : 'Ads on'),
              subtitle: Text(
                adFree
                    ? 'You will never see an ad in this game.'
                    : 'A banner and the occasional interstitial support '
                          'free play.',
              ),
            ),
            if (!adFree)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
                child: FilledButton(
                  onPressed: () => _purchase(context),
                  child: const Text('Remove Ads — \$2.99'),
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: OutlinedButton(
                onPressed: () => _restore(context),
                child: const Text('Restore Purchases'),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _purchase(BuildContext context) async {
    try {
      await entitlement.purchaseAdRemoval();
      // The store's own payment sheet handles the flow from here; a
      // completed purchase arrives through adFreeChanges above.
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    }
  }

  Future<void> _restore(BuildContext context) async {
    String message;
    try {
      message = await _restoreAndConfirm()
          ? 'Purchase restored. Ads are removed.'
          : 'No previous purchase found for this Apple Account.';
    } catch (_) {
      message = 'Could not reach the App Store. Please try again.';
    }
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  /// The store reports restored purchases asynchronously on its purchase
  /// stream, after [EntitlementService.restore] has already returned, so
  /// wait briefly for the entitlement to arrive before saying anything.
  Future<bool> _restoreAndConfirm() async {
    final granted = Completer<bool>();
    final sub = entitlement.adFreeChanges.listen((adFree) {
      if (adFree && !granted.isCompleted) granted.complete(true);
    });
    final timeout = Timer(const Duration(seconds: 6), () {
      if (!granted.isCompleted) granted.complete(false);
    });
    try {
      await entitlement.restore();
      if (entitlement.isAdFree) return true;
      return await granted.future;
    } finally {
      timeout.cancel();
      unawaited(sub.cancel());
    }
  }
}

class _GameCenterSection extends StatelessWidget {
  const _GameCenterSection({required this.services});

  final AppServices services;

  @override
  Widget build(BuildContext context) {
    final connection = services.connection;
    final connecting = connection.status == GameCenterStatus.connecting;
    final subtitle = switch (connection.status) {
      GameCenterStatus.off =>
        'Post scores, earn achievements and sync progress across devices',
      GameCenterStatus.connecting => 'Connecting…',
      GameCenterStatus.connected =>
        'Connected as ${connection.playerName ?? 'your Game Center player'}',
      GameCenterStatus.unavailable =>
        'Couldn\'t reach Game Center. Check that you\'re signed in under '
            'iOS Settings > Game Center, then try again',
    };
    return Column(
      children: [
        SwitchListTile(
          secondary: const Icon(Icons.sports_esports),
          title: const Text('Connect to Game Center'),
          subtitle: Text(subtitle),
          value:
              connection.isConnected ||
              connecting ||
              connection.status == GameCenterStatus.unavailable,
          onChanged: connecting
              ? null
              : (on) => on ? connection.connect() : connection.disconnect(),
        ),
        if (connection.status == GameCenterStatus.unavailable)
          ListTile(
            leading: const Icon(Icons.refresh),
            title: const Text('Try again'),
            onTap: connection.connect,
          ),
        ListTile(
          enabled: connection.isConnected,
          leading: const Icon(Icons.leaderboard),
          title: const Text('Leaderboard'),
          onTap: connection.isConnected
              ? services.progress.showLeaderboard
              : null,
        ),
        ListTile(
          enabled: connection.isConnected,
          leading: const Icon(Icons.emoji_events),
          title: const Text('Achievements'),
          onTap: connection.isConnected
              ? services.progress.showAchievements
              : null,
        ),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      header: true,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
        child: Text(
          title,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _PaletteTile extends StatelessWidget {
  const _PaletteTile({
    required this.palette,
    required this.selected,
    required this.onTap,
    this.requirement,
  });

  final GameThemePalette palette;
  final bool selected;
  final VoidCallback onTap;

  /// Set when the palette is still locked: how to earn it.
  final String? requirement;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      selected: selected,
      minTileHeight: 64,
      leading: _Swatch(palette: palette),
      title: Text(palette.name),
      subtitle: requirement == null ? null : Text('Locked: $requirement'),
      trailing: requirement != null
          ? const Icon(Icons.lock_outline)
          : selected
          ? const Icon(Icons.check)
          : null,
    );
  }
}

/// A miniature of the register on the palette's page color: a 1 cell, a 0
/// cell and an overflow pip.
class _Swatch extends StatelessWidget {
  const _Swatch({required this.palette});

  final GameThemePalette palette;

  @override
  Widget build(BuildContext context) {
    final p = palette;
    Widget cell({required bool on}) => Container(
      width: 16,
      height: 24,
      decoration: BoxDecoration(
        color: on ? p.cellUsed : p.cellFree,
        borderRadius: BorderRadius.circular(4),
        border: on ? null : Border.all(color: p.cellFreeBorder, width: 1.5),
      ),
    );
    return ExcludeSemantics(
      child: Container(
        width: 72,
        height: 40,
        decoration: BoxDecoration(
          color: p.pageBg,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.black12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            cell(on: true),
            const SizedBox(width: 3),
            cell(on: false),
            const SizedBox(width: 6),
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: p.danger,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
