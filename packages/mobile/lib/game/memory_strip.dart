import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../engine/engine.dart';
import '../theme/game_theme.dart';

/// The one-dimensional memory strip. Free cells are outlined and empty;
/// processes are filled blocks labelled with their remaining lifetime
/// (infinity for a leak, a pin icon for a pinned process), so nothing relies
/// on colour alone (MAS-BR-013).
///
/// The strip can be folded into several rows ([lines]) or drawn as a column
/// ([vertical]); addresses always run continuously, and a process crossing a
/// fold is drawn once per row.
class MemoryStrip extends StatelessWidget {
  const MemoryStrip({
    super.key,
    required this.state,
    required this.palette,
    required this.onCellTap,
    this.lines = 1,
    this.vertical = false,
    this.showAddresses = true,
  });

  final MemoryState state;
  final GameThemePalette palette;
  final ValueChanged<int> onCellTap;
  final int lines;
  final bool vertical;
  final bool showAddresses;

  static const double _lineHeight = 64;
  static const double _addressHeight = 16;
  static const double _gutter = 26;

  @override
  Widget build(BuildContext context) {
    final cells = state.cells;
    return LayoutBuilder(
      builder: (context, constraints) {
        if (vertical) {
          final cellH = math.min(
            48.0,
            constraints.maxHeight.isFinite
                ? constraints.maxHeight / state.cellCount
                : 32.0,
          );
          return SizedBox(
            height: cellH * state.cellCount,
            child: _line(cells, 0, state.cellCount, cellH, vertical: true),
          );
        }
        final perLine = (state.cellCount / lines).ceil();
        final cellW = constraints.maxWidth / perLine;
        return Column(
          children: [
            for (var from = 0; from < state.cellCount; from += perLine) ...[
              SizedBox(
                height: _lineHeight,
                child: _line(
                  cells,
                  from,
                  math.min(from + perLine, state.cellCount),
                  cellW,
                  vertical: false,
                ),
              ),
              if (showAddresses)
                SizedBox(
                  height: _addressHeight,
                  child: Row(
                    children: [
                      for (var i = from; i < from + perLine; i++)
                        SizedBox(
                          width: cellW,
                          child: i < state.cellCount
                              ? Text(
                                  '$i',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: palette.textMuted,
                                    fontSize: 9,
                                  ),
                                )
                              : null,
                        ),
                    ],
                  ),
                )
              else
                const SizedBox(height: 6),
            ],
          ],
        );
      },
    );
  }

  /// Cells [from, to) along one axis; [extent] is the size of one cell.
  Widget _line(
    List<int?> cells,
    int from,
    int to,
    double extent, {
    required bool vertical,
  }) {
    final children = <Widget>[
      for (var i = from; i < to; i++)
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
              width: vertical ? null : extent,
              height: vertical ? extent : null,
              decoration: BoxDecoration(
                color: palette.cellFree,
                border: Border.all(color: palette.cellFreeBorder, width: 0.5),
              ),
              alignment: Alignment.centerLeft,
              child: vertical && showAddresses
                  ? Padding(
                      padding: const EdgeInsets.only(left: 4),
                      child: Text(
                        '$i',
                        style: TextStyle(color: palette.textMuted, fontSize: 9),
                      ),
                    )
                  : null,
            ),
          ),
        ),
    ];

    final blocks = <Widget>[];
    for (final p in state.processes) {
      final a = math.max(p.start, from);
      final b = math.min(p.end, to);
      if (a >= b) continue;
      final offset = (a - from) * extent;
      final length = (b - a) * extent;
      blocks.add(
        vertical
            ? Positioned(
                top: offset,
                height: length,
                left: showAddresses ? _gutter : 0,
                right: 0,
                child: IgnorePointer(child: _block(p, compact: true)),
              )
            : Positioned(
                left: offset,
                width: length,
                top: 0,
                bottom: 0,
                child: IgnorePointer(child: _block(p)),
              ),
      );
    }

    return Stack(
      children: [
        Positioned.fill(
          child: vertical
              ? Column(children: children)
              : Row(children: children),
        ),
        ...blocks,
      ],
    );
  }

  Widget _block(MemoryProcess p, {bool compact = false}) {
    final shade = Color.lerp(
      palette.cellUsed,
      Colors.black,
      (p.id % 3) * 0.18,
    )!;
    final leak = p.releasePolicy == ReleasePolicy.leak;
    final label = leak ? '∞' : '${p.remaining}';
    final text = TextStyle(
      color: palette.cellUsedFg,
      fontWeight: FontWeight.w700,
      fontSize: 16,
    );
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
          child: compact
              ? Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(label, style: text),
                    const SizedBox(width: 4),
                    Text(
                      '#${p.id}',
                      style: TextStyle(color: palette.cellUsedFg, fontSize: 10),
                    ),
                    if (p.pinned)
                      Icon(Icons.push_pin, size: 10, color: palette.cellUsedFg),
                  ],
                )
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(label, style: text),
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
