import 'package:flutter/material.dart';

import '../engine/engine.dart';
import '../theme/game_theme.dart';
import 'explain.dart';
import 'game_controller.dart';

/// The pressure-wave banner: what phase the run is in and how long until
/// the next one. Text first, colour second.
class WaveBanner extends StatelessWidget {
  const WaveBanner({super.key, required this.state, required this.palette});

  final MemoryState state;
  final GameThemePalette palette;

  @override
  Widget build(BuildContext context) {
    final rules = state.rules;
    if (!rules.hasWaves) return const SizedBox.shrink();
    final w = state.wave;
    final storm = w.phase == WavePhase.storm;
    final warning = w.phase == WavePhase.warning;
    final recovery = w.phase == WavePhase.recovery;
    final color = storm
        ? palette.danger
        : recovery
        ? palette.ok
        : palette.textMuted;
    final icon = storm
        ? Icons.bolt
        : warning
        ? Icons.warning_amber
        : recovery
        ? Icons.spa_outlined
        : Icons.waves;
    final span = storm
        ? rules.stormTicks
        : warning
        ? rules.warningTicks
        : 0;
    final left = storm ? w.ticksLeftInStorm : w.ticksToStorm;
    return Semantics(
      label: waveLabel(w),
      excludeSemantics: true,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: palette.cellFree,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color, width: storm ? 2 : 1),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                waveLabel(w),
                style: TextStyle(
                  color: storm ? palette.danger : palette.textPrimary,
                  fontWeight: storm || warning
                      ? FontWeight.w700
                      : FontWeight.w400,
                  fontSize: 13,
                ),
              ),
            ),
            if (span > 0)
              SizedBox(
                width: 64,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: LinearProgressIndicator(
                    value: storm
                        ? left / span
                        : (1 - left / span).clamp(0.0, 1.0),
                    minHeight: 6,
                    color: color,
                    backgroundColor: palette.cellFreeBorder.withValues(
                      alpha: 0.35,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// A small labelled pill used for the multiplier, heat and overclock.
class StatusPill extends StatelessWidget {
  const StatusPill({
    super.key,
    required this.palette,
    required this.icon,
    required this.text,
    this.semantics,
    this.alert = false,
    this.good = false,
  });

  final GameThemePalette palette;
  final IconData icon;
  final String text;
  final String? semantics;
  final bool alert;
  final bool good;

  @override
  Widget build(BuildContext context) {
    final color = alert
        ? palette.danger
        : good
        ? palette.ok
        : palette.textMuted;
    return Semantics(
      label: semantics ?? text,
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                text,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: palette.textPrimary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One incoming request in the forecast.
class ForecastChip extends StatelessWidget {
  const ForecastChip({
    super.key,
    required this.item,
    required this.palette,
    this.onReserve,
  });

  final ForecastItem item;
  final GameThemePalette palette;

  /// Shown when the player may hold space for it.
  final VoidCallback? onReserve;

  @override
  Widget build(BuildContext context) {
    final size = item.shownSize;
    final lines = <String>[
      size == null ? 'size ?' : '$size cells',
      if (item.lifetimeLabel.isNotEmpty) item.lifetimeLabel,
      if (item.tag != null) item.tag!,
    ];
    return Semantics(
      label:
          'Coming in ${item.ticksAway} ticks: '
          '${size == null ? 'size unknown' : '$size cells'}. '
          '${lines.skip(1).join(', ')}',
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onReserve,
        child: Container(
          constraints: const BoxConstraints(minHeight: 48),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: onReserve != null ? palette.ok : palette.cellFreeBorder,
              width: onReserve != null ? 1.5 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'in ${item.ticksAway} · ${lines.first}',
                style: TextStyle(
                  color: palette.textPrimary,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
              for (final l in lines.skip(1))
                Text(
                  l,
                  style: TextStyle(color: palette.textMuted, fontSize: 11),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A rounded tile with an icon, a big value and a small label, for the
/// score, best, time and lives readouts.
class StatTile extends StatelessWidget {
  const StatTile({
    super.key,
    required this.palette,
    required this.icon,
    required this.label,
    required this.value,
    this.iconColor,
    this.semantics,
  });

  final GameThemePalette palette;
  final IconData icon;
  final String label;
  final String value;
  final Color? iconColor;
  final String? semantics;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: semantics ?? '$label $value',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: palette.cellFree,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: palette.cellFreeBorder.withValues(alpha: 0.5),
          ),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: iconColor ?? palette.textMuted),
            const SizedBox(width: 6),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      value,
                      style: TextStyle(
                        color: palette.textPrimary,
                        fontSize: 16,
                        height: 1.15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: palette.textMuted, fontSize: 10),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
