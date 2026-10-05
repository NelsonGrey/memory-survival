import 'package:flutter/material.dart';

import '../app/app_services.dart';
import '../engine/engine.dart';
import '../game/game_screen.dart';
import '../shell/shell.dart';
import '../theme/memory_survival_brand.dart';

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
        body: CorridorBackdrop(
          palette: p,
          intensity: 0.5,
          pressure: 0.2,
          child: ListenableBuilder(
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
                    _chapterHeader(context, chapter.key, chapter.value),
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
      ),
    );
  }

  static const _chapterPatterns = <int, String>{
    1: 'uuu...hh.',
    2: 'u.hhhh.uu',
    3: 'u.u..hh.d',
    4: 'uhhd.uuul',
  };

  /// A banner for a chapter: its number and name, a small picture of the
  /// idea it teaches, and how many of its scenarios are cleared.
  Widget _chapterHeader(BuildContext context, int chapter, String title) {
    final p = services.theme.palette;
    final all = scenarios.where((s) => s.chapter == chapter).toList();
    final cleared = all
        .where((s) => services.scenarioProgress.isCleared(s.id))
        .length;
    return Semantics(
      header: true,
      label: 'Chapter $chapter: $title, $cleared of ${all.length} cleared',
      excludeSemantics: true,
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 20, 16, 6),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: p.cellFree,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: p.cellFreeBorder),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'CHAPTER $chapter',
                    style: TextStyle(
                      color: p.ok,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.6,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    title,
                    style: TextStyle(
                      color: p.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  MiniStrip(
                    pattern: _chapterPatterns[chapter] ?? 'uuu.....',
                    palette: p,
                    cell: 16,
                  ),
                ],
              ),
            ),
            Text(
              '$cleared/${all.length}',
              style: TextStyle(
                color: p.textMuted,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
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
              Icon(
                i < stars ? Icons.star : Icons.star_border,
                size: 18,
                color: i < stars ? services.theme.palette.ok : null,
              ),
          ],
        ),
      ),
      onTap: unlocked ? () => _play(context, s) : null,
    );
  }
}
