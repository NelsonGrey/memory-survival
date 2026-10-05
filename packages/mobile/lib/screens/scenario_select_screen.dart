import 'package:flutter/material.dart';

import '../app/app_services.dart';
import '../engine/engine.dart';
import '../game/game_screen.dart';
import '../shell/shell.dart';

/// The 36 authored scenarios in four chapters. Each is a short, scored
/// challenge with three objectives: survive, finish tidy, and finish clean.
/// A non-gameplay screen, so it carries the banner (MAS-BR-015).
class ScenarioSelectScreen extends StatelessWidget {
  const ScenarioSelectScreen({super.key, required this.services});

  final AppServices services;

  void _play(BuildContext context, Scenario s) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            GameScreen(services: services, mode: RunMode.scenario, scenario: s),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = services.theme.palette;
    return Scaffold(
      appBar: AppBar(title: const Text('Scenarios')),
      body: GameScreenShell(
        adService: services.ads,
        body: ListenableBuilder(
          listenable: Listenable.merge([
            services.scenarioProgress,
            services.theme,
          ]),
          builder: (context, _) {
            final progress = services.scenarioProgress;
            return ListView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                  child: Text(
                    '${progress.totalStars} of ${scenarios.length * 3} stars · '
                    '${progress.clearedCount} of ${scenarios.length} cleared',
                    style: TextStyle(color: p.textMuted, fontSize: 13),
                  ),
                ),
                for (final chapter in chapterTitles.entries) ...[
                  Semantics(
                    header: true,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                      child: Text(
                        'Chapter ${chapter.key}: ${chapter.value}',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                    ),
                  ),
                  for (final s in scenarios.where(
                    (s) => s.chapter == chapter.key,
                  ))
                    _tile(
                      context,
                      s,
                      progress.isUnlocked(s.id),
                      progress.starsFor(s.id),
                    ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _tile(BuildContext context, Scenario s, bool unlocked, int stars) {
    return ListTile(
      enabled: unlocked,
      minTileHeight: 56,
      leading: Icon(unlocked ? Icons.play_circle_outline : Icons.lock_outline),
      title: Text('${s.number}. ${s.title}'),
      subtitle: Text(
        unlocked ? s.lesson : 'Clear the previous scenario to unlock',
      ),
      trailing: Semantics(
        label: '$stars of 3 stars',
        excludeSemantics: true,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < 3; i++)
              Icon(i < stars ? Icons.star : Icons.star_border, size: 18),
          ],
        ),
      ),
      onTap: unlocked ? () => _play(context, s) : null,
    );
  }
}
