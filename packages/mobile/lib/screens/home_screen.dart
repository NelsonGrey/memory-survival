import 'package:flutter/material.dart';

import '../app/app_services.dart';
import '../game/game_screen.dart';
import '../shell/shell.dart';
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
      listenable: Listenable.merge([services.theme, services.daily]),
      builder: (context, _) {
        final p = services.theme.palette;
        return Scaffold(
          backgroundColor: p.pageBg,
          body: GameScreenShell(
            adService: services.ads,
            body: SafeArea(
              top: false,
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Semantics(
                        header: true,
                        child: Text(
                          'Memory Survival',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: p.textPrimary,
                            fontSize: 28,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(height: 32),
                      FilledButton(onPressed: _play, child: const Text('Play')),
                      const SizedBox(height: 12),
                      OutlinedButton(
                        onPressed: () => _play(mode: RunMode.daily),
                        child: Text(
                          services.daily.todaysBest == null
                              ? 'Daily run'
                              : 'Daily run · best ${services.daily.todaysBest}',
                        ),
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton(
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) =>
                                ScenarioSelectScreen(services: services),
                          ),
                        ),
                        child: const Text('Scenarios'),
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton(
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => HowToPlayScreen(services: services),
                          ),
                        ),
                        child: const Text('How to play'),
                      ),
                      const SizedBox(height: 12),
                      GameCenterBadge(services: services),
                      const SizedBox(height: 16),
                      OutlinedButton(
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => SettingsScreen(services: services),
                          ),
                        ),
                        child: const Text('Settings'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
