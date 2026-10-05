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
  });

  final MemoryState state;
  final GameThemePalette palette;
  final ValueChanged<int> onCellTap;

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
        return SizedBox(
          height: cellH * state.cellCount,
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
                              : 'Cell $i, process ${cells[i]}',
                          excludeSemantics: true,
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () => onCellTap(i),
                            child: Container(
                              decoration: BoxDecoration(
                                color: palette.cellFree,
                                border: Border.all(
                                  color: palette.cellFreeBorder,
                                  width: 0.5,
                                ),
                              ),
                              alignment: Alignment.centerLeft,
                              padding: const EdgeInsets.only(left: 4),
                              child: Text(
                                '$i',
                                style: TextStyle(
                                  color: palette.textMuted,
                                  fontSize: 9,
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

  Widget _block(MemoryProcess p) {
    final shade = Color.lerp(
      palette.cellUsed,
      Colors.black,
      (p.id % 3) * 0.18,
    )!;
    final leak = p.releasePolicy == ReleasePolicy.leak;
    return Container(
      margin: const EdgeInsets.all(1),
      decoration: BoxDecoration(
        color: shade,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: leak ? palette.danger : palette.cellUsedFg,
          width: leak ? 2 : 1,
        ),
      ),
      alignment: Alignment.center,
      child: FittedBox(
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
            ],
          ),
        ),
      ),
    );
  }
}
