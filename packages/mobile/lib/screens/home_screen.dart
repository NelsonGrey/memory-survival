import 'package:flutter/material.dart';

import '../app/app_services.dart';
import '../game/game_screen.dart';
import '../engine/engine.dart';
import '../shell/shell.dart';
import '../theme/game_theme.dart';
import '../theme/memory_survival_brand.dart';
import 'game_center_widgets.dart';
import 'how_to_play_screen.dart';
import 'scenario_select_screen.dart';
import 'settings_screen.dart';

/// Home screen: starts an endless run or opens Settings. Carries the banner
/// like every non-gameplay screen (MAS-BR-015).
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.services});

  final AppServices services;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  AppServices get services => widget.services;

  @override
  void initState() {
    super.initState();
    // First visit only: offer Game Center once, after the screen is up.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && services.connection.shouldPrompt) {
        showGameCenterPrompt(context, services.connection);
      }
    });
  }

  /// The first Play shows the instructions, then starts the run.
  void _play({RunMode mode = RunMode.endless}) {
    final nav = Navigator.of(context);
    MaterialPageRoute<void> game() => MaterialPageRoute<void>(
      builder: (_) => GameScreen(services: services, mode: mode),
    );
    if (services.howToPlay.value) {
      nav.push(game());
    } else {
      nav.push(
        MaterialPageRoute<void>(
          builder: (_) => HowToPlayScreen(
            services: services,
            onStart: () => nav.pushReplacement(game()),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([
        services.theme,
        services.daily,
        services.bestScore,
        services.personalBests,
        services.scenarioProgress,
      ]),
      builder: (context, _) {
        final p = services.theme.palette;
        final daily = services.daily.todaysBest;
        return Scaffold(
          backgroundColor: p.pageBg,
          body: GameScreenShell(
            adService: services.ads,
            body: CorridorBackdrop(
              palette: p,
              pressure: 0.35,
              child: SafeArea(
                top: false,
                child: LayoutBuilder(
                  builder: (context, box) => SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(minHeight: box.maxHeight),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const SizedBox(height: 24),
                          Semantics(
                            header: true,
                            label: 'Memory Survival',
                            child: ExcludeSemantics(
                              child: Image.asset(
                                stackedWordmarkAsset,
                                height: 190,
                                fit: BoxFit.contain,
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),
                          Text(
                            'EVERY GAP IS A RISK.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: p.textPrimary,
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 2.6,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'A real-time memory allocation puzzle',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: p.textMuted, fontSize: 12),
                          ),
                          const SizedBox(height: 18),
                          Center(
                            child: MiniStrip(
                              pattern: 'uuu.hh.uu..d',
                              palette: p,
                              cell: 20,
                            ),
                          ),
                          const SizedBox(height: 26),
                          SizedBox(
                            height: 58,
                            child: FilledButton.icon(
                              onPressed: _play,
                              icon: const Icon(Icons.play_arrow_rounded),
                              label: const Text('Play'),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: _tile(
                                  icon: Icons.today_outlined,
                                  label: 'Daily run',
                                  detail: daily == null
                                      ? 'New seed today'
                                      : 'Best $daily',
                                  onTap: () => _play(mode: RunMode.daily),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _tile(
                                  icon: Icons.flag_outlined,
                                  label: 'Scenarios',
                                  detail:
                                      '${services.scenarioProgress.totalStars}'
                                      ' of ${scenarios.length * 3} stars',
                                  onTap: () => Navigator.of(context).push(
                                    MaterialPageRoute<void>(
                                      builder: (_) => ScenarioSelectScreen(
                                        services: services,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 18),
                          _records(p),
                          const SizedBox(height: 10),
                          Wrap(
                            alignment: WrapAlignment.center,
                            spacing: 8,
                            children: [
                              TextButton.icon(
                                onPressed: () => Navigator.of(context).push(
                                  MaterialPageRoute<void>(
                                    builder: (_) =>
                                        HowToPlayScreen(services: services),
                                  ),
                                ),
                                icon: const Icon(Icons.help_outline),
                                label: const Text('How to play'),
                              ),
                              TextButton.icon(
                                onPressed: () => Navigator.of(context).push(
                                  MaterialPageRoute<void>(
                                    builder: (_) =>
                                        SettingsScreen(services: services),
                                  ),
                                ),
                                icon: const Icon(Icons.settings_outlined),
                                label: const Text('Settings'),
                              ),
                            ],
                          ),
                          GameCenterBadge(services: services),
                          const SizedBox(height: 16),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  /// A rounded panel with an icon, a label and one line of detail.
  Widget _tile({
    required IconData icon,
    required String label,
    required String detail,
    required VoidCallback onTap,
  }) {
    final p = services.theme.palette;
    return Semantics(
      button: true,
      label: '$label, $detail',
      excludeSemantics: true,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 88),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: p.cellFree,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: p.cellFreeBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: p.ok, size: 22),
              const SizedBox(height: 8),
              Text(
                label,
                style: TextStyle(
                  color: p.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(detail, style: TextStyle(color: p.textMuted, fontSize: 12)),
            ],
          ),
        ),
      ),
    );
  }

  /// Best score and personal records, once there are any.
  Widget _records(GameThemePalette p) {
    final best = services.bestScore.value;
    final b = services.personalBests;
    if (best == 0 && b.bestStreak == 0 && b.mostWaves == 0) {
      return const SizedBox.shrink();
    }
    Widget stat(String value, String label) => Column(
      children: [
        Text(
          value,
          style: TextStyle(
            color: p.textPrimary,
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),
        Text(label, style: TextStyle(color: p.textMuted, fontSize: 11)),
      ],
    );
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        border: Border.symmetric(
          horizontal: BorderSide(
            color: p.cellFreeBorder.withValues(alpha: 0.5),
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          stat('$best', 'Best score'),
          stat('${b.bestStreak}', 'Clean run'),
          stat('${b.mostWaves}', 'Waves cleared'),
        ],
      ),
    );
  }
}
