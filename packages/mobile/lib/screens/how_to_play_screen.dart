import 'package:flutter/material.dart';

import '../app/app_services.dart';
import '../theme/game_theme.dart';
import '../theme/memory_survival_brand.dart';
import 'ad_top_scaffold.dart';

/// Plain-language instructions. Shown once before the first run and always
/// reachable from Home and the pause menu. A non-gameplay screen, so it
/// carries the banner (MAS-BR-015).
class HowToPlayScreen extends StatelessWidget {
  const HowToPlayScreen({super.key, required this.services, this.onStart});

  final AppServices services;

  /// When set (first run), the primary button starts the game instead of
  /// just closing the screen.
  final VoidCallback? onStart;

  static const _steps = <(IconData, String, String, String)>[
    (
      Icons.inbox_outlined,
      'Requests arrive',
      'Each waiting request needs a number of cells in a row, and lives for '
          'a number of ticks once placed. The ⏱ bar is how long it will wait. '
          '"Coming up" shows what arrives next.',
      'uu.....u',
    ),
    (
      Icons.touch_app_outlined,
      'Place them',
      'Tap a request, then tap a ▸ cell or choose Start or End of a gap. '
          'Where you put it decides what space is left: each option shows the '
          'biggest gap you would keep.',
      'uuhhh.uu',
    ),
    (
      Icons.timelapse,
      'Time frees space',
      'The number on a block counts down each tick. At 0 the process ends '
          'and its cells open up again.',
      'uu...uu.',
    ),
    (
      Icons.local_fire_department_outlined,
      'Keep your run clean',
      'Finishing processes builds a multiplier on every point you score. '
          'It drops when you fault, compact, fill the waiting list or let '
          'free memory splinter. Tidy placements that do not split a gap earn '
          'a bonus.',
      '',
    ),
    (
      Icons.waves,
      'Waves of pressure',
      'Traffic builds to a storm every so often, with a warning first. Clear '
          'one without a fault for a payout and to cool the system. Each wave '
          'brings a new kind of process.',
      '',
    ),
    (
      Icons.favorite_border,
      'Faults add heat',
      'If a request runs out of time, or the waiting list is full, you lose '
          'a life and the system heats up: new requests wait less, and then a '
          'cell is locked for a while. Lose all 3 lives and the run is over. '
          'A clean wave cools it, but lives never come back.',
      'uu.l.uu.',
    ),
    (
      Icons.grid_view,
      'Free space is not enough',
      'Four free cells split into pieces cannot hold a request that needs '
          'four in a row. Put short-lived processes together and long-lived '
          'ones together so gaps stay useful.',
      'uu.u.uu.',
    ),
    (
      Icons.compress,
      'Compact in an emergency',
      'Compact slides everything down to close the gaps. It takes ticks '
          'during which requests keep arriving, costs points and your '
          'multiplier, and you only get a few. Pinned blocks (pin icon) will '
          'not move. Leaks (∞) never end unless you clean them up.',
      'u.uu.u..>uuuu....',
    ),
    (
      Icons.speed,
      'Take a risk',
      'Overclock for double score but faster arrivals. Reserve space for a '
          'request you can see coming. Turn away one request per wave if you '
          'must, at the cost of your multiplier.',
      '',
    ),
  ];

  /// A small picture of the idea; `>` splits a before and an after.
  Widget _diagram(GameThemePalette p, String pattern) {
    final parts = pattern.split('>');
    return Align(
      alignment: Alignment.centerLeft,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < parts.length; i++) ...[
              if (i > 0)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Icon(Icons.arrow_forward, size: 18, color: p.ok),
                ),
              MiniStrip(pattern: parts[i], palette: p, cell: 16),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = services.theme.palette;
    return AdTopScaffold(
      adService: services.ads,
      title: 'How to play',
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
                  for (final (icon, title, body, pattern) in _steps)
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
                                if (pattern.isNotEmpty) ...[
                                  const SizedBox(height: 10),
                                  _diagram(p, pattern),
                                ],
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
    );
  }
}
