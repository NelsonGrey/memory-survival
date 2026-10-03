import 'package:flutter/material.dart';

import '../engine/engine.dart';
import '../theme/game_theme.dart';

/// The one-dimensional memory strip. Free cells are outlined and empty;
/// processes are filled blocks labelled with their remaining lifetime
/// (infinity for a leak, a pin icon for a pinned process), so nothing relies
/// on colour alone (MAS-BR-013).
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

  static const double height = 64;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final cellW = constraints.maxWidth / state.cellCount;
        final cells = state.cells;
        return SizedBox(
          height: height + 18,
          child: Column(
            children: [
              SizedBox(
                height: height,
                child: Stack(
                  children: [
                    Row(
                      children: [
                        for (var i = 0; i < state.cellCount; i++)
                          Semantics(
                            button: true,
                            label: cells[i] == null
                                ? 'Cell $i, free'
                                : 'Cell $i, process ${cells[i]}',
                            excludeSemantics: true,
                            child: GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: () => onCellTap(i),
                              child: Container(
                                width: cellW,
                                height: height,
                                decoration: BoxDecoration(
                                  color: palette.cellFree,
                                  border: Border.all(
                                    color: palette.cellFreeBorder,
                                    width: 0.5,
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                    for (final p in state.processes)
                      Positioned(
                        left: p.start * cellW,
                        width: p.size * cellW,
                        top: 0,
                        height: height,
                        child: IgnorePointer(child: _block(p)),
                      ),
                  ],
                ),
              ),
              SizedBox(
                height: 18,
                child: Row(
                  children: [
                    for (var i = 0; i < state.cellCount; i++)
                      SizedBox(
                        width: cellW,
                        child: Text(
                          '$i',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: palette.textMuted,
                            fontSize: 9,
                          ),
                        ),
                      ),
                  ],
                ),
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
    final label = p.releasePolicy == ReleasePolicy.leak
        ? '∞'
        : '${p.remaining}';
    return Container(
      margin: const EdgeInsets.all(1),
      decoration: BoxDecoration(
        color: shade,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: p.releasePolicy == ReleasePolicy.leak
              ? palette.danger
              : palette.cellUsedFg,
          width: p.releasePolicy == ReleasePolicy.leak ? 2 : 1,
        ),
      ),
      alignment: Alignment.center,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Padding(
          padding: const EdgeInsets.all(2),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: palette.cellUsedFg,
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
              ),
              Text(
                '#${p.id}',
                style: TextStyle(color: palette.cellUsedFg, fontSize: 9),
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
