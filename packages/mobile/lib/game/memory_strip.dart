import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../engine/engine.dart';
import '../theme/game_theme.dart';

/// The memory strip, drawn as a column with address 0 at the top. Free cells
/// are outlined and empty; processes are filled blocks labelled with their
/// remaining lifetime (infinity for a leak, a pin icon for a pinned
/// process), so nothing relies on colour alone (MAS-BR-013).
class MemoryStrip extends StatelessWidget {
  const MemoryStrip({
    super.key,
    required this.state,
    required this.palette,
    required this.onCellTap,
    this.validStarts = const {},
  });

  final MemoryState state;
  final GameThemePalette palette;
  final ValueChanged<int> onCellTap;

  /// Cells where the selected request could start, marked on the strip so
  /// the placement choice lives here rather than only in buttons.
  final Set<int> validStarts;

  static const double _gutter = 26;

  @override
  Widget build(BuildContext context) {
    final cells = state.cells;
    return LayoutBuilder(
      builder: (context, constraints) {
        final cellH = math.min(
          48.0,
          constraints.maxHeight.isFinite
              ? constraints.maxHeight / state.cellCount
              : 32.0,
        );
        return Container(
          height: cellH * state.cellCount,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: palette.cellFreeBorder.withValues(alpha: 0.6),
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            children: [
              Positioned.fill(
                child: Column(
                  children: [
                    for (var i = 0; i < state.cellCount; i++)
                      Expanded(
                        child: Semantics(
                          button: true,
                          label: cells[i] == null
                              ? 'Cell $i, free'
                                    '${validStarts.contains(i) ? ', valid start' : ''}'
                              : 'Cell $i, ${_ownerLabel(cells[i]!)}',
                          excludeSemantics: true,
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () => onCellTap(i),
                            child: Container(
                              decoration: BoxDecoration(
                                color: palette.cellFree,
                                border: Border.all(
                                  color: validStarts.contains(i)
                                      ? palette.ok
                                      : palette.cellFreeBorder,
                                  width: validStarts.contains(i) ? 2 : 0.5,
                                ),
                              ),
                              alignment: Alignment.centerLeft,
                              padding: const EdgeInsets.only(left: 4),
                              child: Text(
                                validStarts.contains(i) ? '▸$i' : '$i',
                                style: TextStyle(
                                  color: validStarts.contains(i)
                                      ? palette.ok
                                      : palette.textMuted,
                                  fontSize: 9,
                                  fontWeight: validStarts.contains(i)
                                      ? FontWeight.w700
                                      : FontWeight.w400,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              for (final p in state.processes)
                Positioned(
                  top: p.start * cellH,
                  height: p.size * cellH,
                  left: _gutter,
                  right: 0,
                  child: IgnorePointer(child: _block(p)),
                ),
            ],
          ),
        );
      },
    );
  }

  String _ownerLabel(int id) {
    for (final p in state.processes) {
      if (p.id != id) continue;
      switch (p.kind) {
        case ProcessKind.quarantine:
          return 'locked';
        case ProcessKind.reserved:
          return 'held for request ${p.reservedFor}';
        case ProcessKind.normal:
          return 'process $id';
      }
    }
    return 'process $id';
  }

  Widget _block(MemoryProcess p) {
    if (!p.isNormal) return _lockBlock(p);
    final shade = Color.lerp(
      palette.cellUsed,
      Colors.black,
      (p.id % 3) * 0.18,
    )!;
    final leak = p.releasePolicy == ReleasePolicy.leak;
    final label = FittedBox(
      fit: BoxFit.scaleDown,
      child: Padding(
        padding: const EdgeInsets.all(2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              leak ? '∞' : '${p.remaining}',
              style: TextStyle(
                color: palette.cellUsedFg,
                fontWeight: FontWeight.w700,
                fontSize: 16,
              ),
            ),
            const SizedBox(width: 4),
            Text(
              '#${p.id}',
              style: TextStyle(color: palette.cellUsedFg, fontSize: 10),
            ),
            if (p.pinned)
              Icon(Icons.push_pin, size: 10, color: palette.cellUsedFg),
            if (p.pointsFactor > 1)
              Icon(Icons.star, size: 10, color: palette.cellUsedFg),
            if (p.linkedWith != null)
              Icon(Icons.link, size: 10, color: palette.cellUsedFg),
          ],
        ),
      ),
    );
    return Container(
      margin: const EdgeInsets.all(1),
      decoration: BoxDecoration(
        color: shade,
        borderRadius: BorderRadius.circular(7),
        border: Border.all(
          color: leak
              ? palette.danger
              : palette.cellUsedFg.withValues(alpha: 0.55),
          width: leak ? 2 : 1,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // The app icon's restrained bevel: light top edge, darker base.
            Positioned(
              left: 0,
              right: 0,
              top: 0,
              height: 4,
              child: ColoredBox(color: Colors.white.withValues(alpha: 0.26)),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: 5,
              child: ColoredBox(color: Colors.black.withValues(alpha: 0.22)),
            ),
            Center(child: label),
          ],
        ),
      ),
    );
  }

  /// A locked cell or a held region: hatched-looking, countdown only.
  Widget _lockBlock(MemoryProcess p) {
    final held = p.kind == ProcessKind.reserved;
    return Container(
      margin: const EdgeInsets.all(1),
      decoration: BoxDecoration(
        color: palette.cellFree,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: held ? palette.ok : palette.danger, width: 2),
      ),
      alignment: Alignment.center,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Padding(
          padding: const EdgeInsets.all(2),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                held ? Icons.bookmark : Icons.lock,
                size: 12,
                color: held ? palette.ok : palette.danger,
              ),
              const SizedBox(width: 3),
              Text(
                held
                    ? '#${p.reservedFor} · ${p.remaining - 1}'
                    : '${p.remaining - 1}',
                style: TextStyle(color: palette.textPrimary, fontSize: 11),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
