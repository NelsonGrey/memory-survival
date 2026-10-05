import 'package:flutter/material.dart';

import '../app/app_services.dart';
import '../shell/shell.dart';

/// Plain-language instructions. Shown once before the first run and always
/// reachable from Home and the pause menu. A non-gameplay screen, so it
/// carries the banner (MAS-BR-015).
class HowToPlayScreen extends StatelessWidget {
  const HowToPlayScreen({super.key, required this.services, this.onStart});

  final AppServices services;

  /// When set (first run), the primary button starts the game instead of
  /// just closing the screen.
  final VoidCallback? onStart;

  static const _steps = <(IconData, String, String)>[
    (
      Icons.inbox_outlined,
      'Requests arrive',
      'Each waiting request needs a number of cells in a row, and lives for '
          'a number of ticks once placed. The ⏱ bar is how long it will wait.',
    ),
    (
      Icons.touch_app_outlined,
      'Place them',
      'Tap a request, then tap a cell or a gap button. It fills that many '
          'cells starting there. They must all be free.',
    ),
    (
      Icons.timelapse,
      'Time frees space',
      'The number on a block counts down each tick. At 0 the process ends '
          'and its cells open up again.',
    ),
    (
      Icons.favorite_border,
      'Protect your lives',
      'If a request runs out of time, or the waiting list is full, you lose '
          'a life. Lose all 3 and the run is over. Your score is your '
          'reward: cells placed and processes finished.',
    ),
    (
      Icons.grid_view,
      'Free space is not enough',
      'Four free cells split into pieces cannot hold a request that needs '
          'four in a row. Plan where short and long processes go so gaps '
          'stay useful.',
    ),
    (
      Icons.compress,
      'Compact in an emergency',
      'Compact slides everything down to close the gaps. It takes time while '
          'requests keep waiting, costs points, and you only get a few. '
          'Pinned blocks (pin icon) will not move. Leaks (∞) never end.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final p = services.theme.palette;
    return Scaffold(
      appBar: AppBar(title: const Text('How to play')),
      body: GameScreenShell(
        adService: services.ads,
        body: SafeArea(
          top: false,
          child: Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    Text(
                      'Keep memory from filling up. Fit each request into free '
                      'cells before its timer runs out, and the run keeps going.',
                      style: TextStyle(color: p.textPrimary, fontSize: 15),
                    ),
                    const SizedBox(height: 16),
                    for (final (icon, title, body) in _steps)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(icon, color: p.ok),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Semantics(
                                    header: true,
                                    child: Text(
                                      title,
                                      style: TextStyle(
                                        color: p.textPrimary,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    body,
                                    style: TextStyle(
                                      color: p.textMuted,
                                      fontSize: 13,
                                      height: 1.4,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () {
                      services.howToPlay.markSeen();
                      if (onStart != null) {
                        onStart!();
                      } else {
                        Navigator.of(context).pop();
                      }
                    },
                    child: Text(onStart != null ? 'Start playing' : 'Got it'),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
