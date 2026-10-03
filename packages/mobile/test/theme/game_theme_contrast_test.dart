import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memory_survival/theme/game_theme.dart';

double _linearChannel(int channel) {
  final value = channel / 255;
  return value <= 0.04045
      ? value / 12.92
      : math.pow((value + 0.055) / 1.055, 2.4).toDouble();
}

double _luminance(Color color) {
  final argb = color.toARGB32();
  return 0.2126 * _linearChannel((argb >> 16) & 0xff) +
      0.7152 * _linearChannel((argb >> 8) & 0xff) +
      0.0722 * _linearChannel(argb & 0xff);
}

double _contrast(Color first, Color second) {
  final values = [_luminance(first), _luminance(second)]..sort();
  return (values.last + 0.05) / (values.first + 0.05);
}

/// WCAG AA: 4.5:1 for small text, 3:1 for large text and non-text marks
/// (cell outlines, placement/failure indicators).
const _smallText = 4.5;
const _nonText = 3.0;

typedef _Pair = (
  String,
  Color Function(GameThemePalette),
  Color Function(GameThemePalette),
  double,
);

final List<_Pair> _pairs = [
  ('textPrimary on pageBg', (p) => p.textPrimary, (p) => p.pageBg, _smallText),
  ('textMuted on pageBg', (p) => p.textMuted, (p) => p.pageBg, _smallText),
  (
    'cellUsedFg on cellUsed',
    (p) => p.cellUsedFg,
    (p) => p.cellUsed,
    _smallText,
  ),
  ('buttonFg on buttonBg', (p) => p.buttonFg, (p) => p.buttonBg, _smallText),
  (
    'cellFreeBorder on pageBg',
    (p) => p.cellFreeBorder,
    (p) => p.pageBg,
    _nonText,
  ),
  ('cellUsed on pageBg', (p) => p.cellUsed, (p) => p.pageBg, _nonText),
  ('ok on pageBg', (p) => p.ok, (p) => p.pageBg, _nonText),
  ('danger on pageBg', (p) => p.danger, (p) => p.pageBg, _nonText),
];

void main() {
  for (final entry in gameThemePalettes.entries) {
    group('${entry.value.name} palette', () {
      for (final (label, fg, bg, minimum) in _pairs) {
        test('$label >= $minimum:1', () {
          expect(
            _contrast(fg(entry.value), bg(entry.value)),
            greaterThanOrEqualTo(minimum),
          );
        });
      }
    });
  }

  test('every theme id has a palette and appears in the picker order', () {
    expect(gameThemePalettes.keys.toSet(), GameThemeId.values.toSet());
    expect(gameThemeOrder.toSet(), GameThemeId.values.toSet());
  });
}
