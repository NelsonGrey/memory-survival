import 'package:flutter/material.dart';

import '../engine/engine.dart';
import 'game_theme.dart';

const markAsset = 'assets/branding/memory-survival-mark.png';
const wordmarkAsset = 'assets/branding/memory-survival-wordmark.png';
const stackedWordmarkAsset =
    'assets/branding/memory-survival-wordmark-stacked.png';

/// How hard the pressure walls squeeze, 0 (barely visible) to 1 (storm).
/// Calm traffic leans in a little more each wave, the warning builds toward
/// the storm, recovery lets go, and heat from faults adds to all of it.
double wavePressure(MemoryState s) {
  final w = s.wave;
  final base = switch (w.phase) {
    WavePhase.calm => 0.12 + 0.03 * (w.number - 1).clamp(0, 5),
    WavePhase.warning =>
      0.3 +
          0.3 *
              (1 -
                      w.ticksToStorm /
                          (s.rules.warningTicks <= 0
                              ? 1
                              : s.rules.warningTicks))
                  .clamp(0.0, 1.0),
    WavePhase.storm => 1.0,
    WavePhase.recovery => 0.05,
  };
  return (base + 0.08 * s.heat).clamp(0.0, 1.0);
}

/// The S2 picture as a living backdrop: two pressure walls close in from the
/// edges of the screen, leaving the corridor in the middle. It is decorative
/// and excluded from semantics. [pressure] moves the walls; [intensity]
/// fades the whole thing (use less behind dense content).
class CorridorBackdrop extends StatelessWidget {
  const CorridorBackdrop({
    super.key,
    required this.palette,
    required this.child,
    this.intensity = 1,
    this.pressure = 0.3,
  });

  final GameThemePalette palette;
  final Widget child;
  final double intensity;
  final double pressure;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        ExcludeSemantics(
          child: TweenAnimationBuilder<double>(
            tween: Tween(end: pressure.clamp(0.0, 1.0)),
            duration: const Duration(milliseconds: 700),
            curve: Curves.easeOutCubic,
            builder: (context, value, _) => CustomPaint(
              painter: _CorridorPainter(
                palette,
                intensity.clamp(0.0, 1.0),
                value,
              ),
            ),
          ),
        ),
        child,
      ],
    );
  }
}

class _CorridorPainter extends CustomPainter {
  const _CorridorPainter(this.palette, this.intensity, this.pressure);

  final GameThemePalette palette;
  final double intensity;
  final double pressure;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    // Inner edge of each wall, as a distance from its side of the screen.
    final inner = w * (0.05 + 0.13 * pressure);
    final fill = Paint()
      ..color = palette.danger.withValues(
        alpha: (0.11 + 0.12 * pressure) * intensity,
      );
    final facet = Paint()
      ..color = palette.danger.withValues(
        alpha: (0.22 + 0.18 * pressure) * intensity,
      )
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeJoin = StrokeJoin.round;
    for (final mirror in [false, true]) {
      double x(double d) => mirror ? w - d : d;
      final path = Path()
        ..moveTo(x(0), h * 0.09)
        ..lineTo(x(inner * 0.9), h * 0.25)
        ..lineTo(x(inner), h * 0.38)
        ..lineTo(x(inner), h * 0.62)
        ..lineTo(x(inner * 0.9), h * 0.75)
        ..lineTo(x(0), h * 0.91)
        ..close();
      canvas.drawPath(path, fill);
      final edge = Path()
        ..moveTo(x(0), h * 0.09)
        ..lineTo(x(inner * 0.9), h * 0.25)
        ..lineTo(x(inner), h * 0.38);
      canvas.drawPath(edge, facet);
    }
    // A faint corridor guide down the middle: the space still holding.
    final guide = Paint()
      ..color = palette.cellFreeBorder.withValues(alpha: 0.10 * intensity)
      ..strokeWidth = 1;
    canvas.drawLine(Offset(w / 2, h * 0.04), Offset(w / 2, h * 0.96), guide);
  }

  @override
  bool shouldRepaint(_CorridorPainter old) =>
      old.palette != palette ||
      old.intensity != intensity ||
      old.pressure != pressure;
}

/// The rounded S2 mark.
class BrandMark extends StatelessWidget {
  const BrandMark({super.key, this.size = 40});

  final double size;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: Image.asset(markAsset, width: size, height: size),
  );
}

/// What a cell in a [MiniStrip] shows.
enum MiniCell { free, used, healthy, danger, locked }

/// A small horizontal picture of memory cells, for teaching and for empty
/// states. Pass a pattern such as `"uu.hh..d"`: `u` used, `h` healthy
/// (mint), `d` fault (coral), `l` locked, `.` free.
class MiniStrip extends StatelessWidget {
  const MiniStrip({
    super.key,
    required this.pattern,
    required this.palette,
    this.cell = 22,
    this.semanticsLabel,
  });

  final String pattern;
  final GameThemePalette palette;
  final double cell;
  final String? semanticsLabel;

  static MiniCell _parse(String c) => switch (c) {
    'u' => MiniCell.used,
    'h' => MiniCell.healthy,
    'd' => MiniCell.danger,
    'l' => MiniCell.locked,
    _ => MiniCell.free,
  };

  @override
  Widget build(BuildContext context) {
    final cells = [for (final c in pattern.split('')) _parse(c)];
    return Semantics(
      label: semanticsLabel,
      excludeSemantics: semanticsLabel != null,
      child: CustomPaint(
        size: Size(cells.length * (cell + 3) - 3, cell),
        painter: _MiniStripPainter(cells, palette, cell),
      ),
    );
  }
}

class _MiniStripPainter extends CustomPainter {
  _MiniStripPainter(this.cells, this.palette, this.cell);

  final List<MiniCell> cells;
  final GameThemePalette palette;
  final double cell;

  @override
  void paint(Canvas canvas, Size size) {
    for (var i = 0; i < cells.length; i++) {
      final r = RRect.fromRectAndRadius(
        Rect.fromLTWH(i * (cell + 3), 0, cell, cell),
        Radius.circular(cell * 0.2),
      );
      final kind = cells[i];
      if (kind == MiniCell.free) {
        canvas.drawRRect(r, Paint()..color = palette.cellFree);
        canvas.drawRRect(
          r,
          Paint()
            ..color = palette.cellFreeBorder
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.2,
        );
        continue;
      }
      final base = switch (kind) {
        MiniCell.used => palette.cellUsed,
        MiniCell.healthy => palette.ok,
        MiniCell.danger => palette.danger,
        _ => palette.cellFree,
      };
      canvas.drawRRect(r, Paint()..color = base);
      // The same restrained bevel as the app icon: a light top edge and a
      // darker lower edge.
      canvas.save();
      canvas.clipRRect(r);
      canvas.drawRect(
        Rect.fromLTWH(r.left, r.top, cell, cell * 0.12),
        Paint()..color = Colors.white.withValues(alpha: 0.28),
      );
      canvas.drawRect(
        Rect.fromLTWH(r.left, r.bottom - cell * 0.14, cell, cell * 0.14),
        Paint()..color = Colors.black.withValues(alpha: 0.22),
      );
      canvas.restore();
      if (kind == MiniCell.locked) {
        canvas.drawRRect(
          r,
          Paint()
            ..color = palette.danger
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_MiniStripPainter old) =>
      old.cells != cells || old.palette != palette || old.cell != cell;
}
