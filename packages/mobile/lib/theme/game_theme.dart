import 'package:flutter/material.dart';

/// Identifies one of the built-in gameplay palettes. Persisted by name (see
/// [ThemeController]) — renaming a value here changes what a player who
/// already picked a non-default palette sees next launch.
enum GameThemeId { dark, light, highContrast, ember, forest }

/// A complete color palette for the gameplay screen. Every themed surface
/// reads from one of these rather than hardcoding a color;
/// test/theme/game_theme_contrast_test.dart holds each palette to WCAG AA.
///
/// Placeholder identity: the visual metaphor is still to be designed (see
/// MAS-BR-009), so these are deliberately plain.
class GameThemePalette {
  const GameThemePalette({
    required this.name,
    required this.pageBg,
    required this.textPrimary,
    required this.textMuted,
    required this.cellFree,
    required this.cellFreeBorder,
    required this.cellUsed,
    required this.cellUsedFg,
    required this.ok,
    required this.danger,
    required this.buttonBg,
    required this.buttonFg,
  });

  final String name;
  final Color pageBg;
  final Color textPrimary;
  final Color textMuted;

  /// An unallocated memory cell and its outline.
  final Color cellFree;
  final Color cellFreeBorder;

  /// An allocated cell and the label drawn on it.
  final Color cellUsed;
  final Color cellUsedFg;

  /// A valid placement / a failed allocation.
  final Color ok;
  final Color danger;

  final Color buttonBg;
  final Color buttonFg;
}

const Map<GameThemeId, GameThemePalette> gameThemePalettes = {
  GameThemeId.dark: GameThemePalette(
    name: 'Dark',
    pageBg: Color(0xFF10151C),
    textPrimary: Color(0xFFEEF2F6),
    textMuted: Color(0xFFA9B4C2),
    cellFree: Color(0xFF1B2430),
    cellFreeBorder: Color(0xFF7D8DA3),
    cellUsed: Color(0xFF2F6AA0),
    cellUsedFg: Color(0xFFFFFFFF),
    ok: Color(0xFF6FD9B0),
    danger: Color(0xFFFF8A75),
    buttonBg: Color(0xFF2F6AA0),
    buttonFg: Color(0xFFFFFFFF),
  ),
  GameThemeId.light: GameThemePalette(
    name: 'Light',
    pageBg: Color(0xFFF6F4EF),
    textPrimary: Color(0xFF1B2430),
    textMuted: Color(0xFF4F5B6B),
    cellFree: Color(0xFFE6E1D6),
    cellFreeBorder: Color(0xFF6B7686),
    cellUsed: Color(0xFF2F6AA0),
    cellUsedFg: Color(0xFFFFFFFF),
    ok: Color(0xFF1B7A55),
    danger: Color(0xFFB3261E),
    buttonBg: Color(0xFF2F6AA0),
    buttonFg: Color(0xFFFFFFFF),
  ),
  // Maximum-legibility option: pure black page, white text, saturated marks.
  GameThemeId.highContrast: GameThemePalette(
    name: 'High contrast',
    pageBg: Color(0xFF000000),
    textPrimary: Color(0xFFFFFFFF),
    textMuted: Color(0xFFE0E0E0),
    cellFree: Color(0xFF111111),
    cellFreeBorder: Color(0xFFFFFFFF),
    cellUsed: Color(0xFF1F5FD1),
    cellUsedFg: Color(0xFFFFFFFF),
    ok: Color(0xFFFFE066),
    danger: Color(0xFFFF9C8F),
    buttonBg: Color(0xFF1F5FD1),
    buttonFg: Color(0xFFFFFFFF),
  ),
  // Warm dark: coals and amber. Used blocks are orange-brown, free cells ash.
  GameThemeId.ember: GameThemePalette(
    name: 'Ember',
    pageBg: Color(0xFF1C1411),
    textPrimary: Color(0xFFF7EBDD),
    textMuted: Color(0xFFCDB8A4),
    cellFree: Color(0xFF2A1F1A),
    cellFreeBorder: Color(0xFF9C8573),
    cellUsed: Color(0xFFB5501A),
    cellUsedFg: Color(0xFFFFFFFF),
    ok: Color(0xFFA6E08A),
    danger: Color(0xFFFF8F7A),
    buttonBg: Color(0xFFB5501A),
    buttonFg: Color(0xFFFFFFFF),
  ),
  // Cool dark green: moss and mint.
  GameThemeId.forest: GameThemePalette(
    name: 'Forest',
    pageBg: Color(0xFF0E1A15),
    textPrimary: Color(0xFFE6F2EA),
    textMuted: Color(0xFFA4BDAE),
    cellFree: Color(0xFF16261E),
    cellFreeBorder: Color(0xFF6F9A84),
    cellUsed: Color(0xFF2E7D5B),
    cellUsedFg: Color(0xFFFFFFFF),
    ok: Color(0xFFF2D675),
    danger: Color(0xFFFF8F80),
    buttonBg: Color(0xFF2E7D5B),
    buttonFg: Color(0xFFFFFFFF),
  ),
};

/// Display order for the palette picker; dark is the default for new players.
const List<GameThemeId> gameThemeOrder = [
  GameThemeId.dark,
  GameThemeId.light,
  GameThemeId.highContrast,
  GameThemeId.ember,
  GameThemeId.forest,
];

const GameThemeId defaultGameTheme = GameThemeId.dark;

/// Builds the Material shell from the same palette used by gameplay so menus,
/// dialogs and settings change appearance with the player's selection too.
ThemeData materialThemeFor(GameThemePalette p) {
  final brightness = ThemeData.estimateBrightnessForColor(p.pageBg);
  final scheme =
      ColorScheme.fromSeed(
        seedColor: p.cellUsed,
        brightness: brightness,
        surface: p.pageBg,
      ).copyWith(
        primary: p.buttonBg,
        onPrimary: p.buttonFg,
        secondary: p.ok,
        onSecondary: p.buttonFg,
        surface: p.pageBg,
        onSurface: p.textPrimary,
        error: p.danger,
      );

  return ThemeData(
    colorScheme: scheme,
    scaffoldBackgroundColor: p.pageBg,
    canvasColor: p.pageBg,
    useMaterial3: true,
    fontFamily: 'Sora',
    appBarTheme: AppBarTheme(
      backgroundColor: p.pageBg,
      foregroundColor: p.textPrimary,
      surfaceTintColor: Colors.transparent,
      centerTitle: true,
    ),
    dividerColor: p.cellFreeBorder,
    listTileTheme: ListTileThemeData(
      iconColor: p.textMuted,
      textColor: p.textPrimary,
      selectedColor: p.textPrimary,
      selectedTileColor: p.cellFree,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: p.buttonBg,
        foregroundColor: p.buttonFg,
        textStyle: const TextStyle(fontWeight: FontWeight.w700),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: p.textPrimary,
        side: BorderSide(color: p.cellFreeBorder),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
  );
}
