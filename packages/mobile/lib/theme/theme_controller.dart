import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'game_theme.dart';

/// Holds the player's chosen gameplay palette and persists it by
/// [GameThemeId] name, so a palette survives relaunch.
class ThemeController extends ValueNotifier<GameThemeId> {
  ThemeController() : super(defaultGameTheme);

  static const _prefsKey = 'gameplay.theme';

  GameThemePalette get palette => gameThemePalettes[value]!;

  /// Reads the saved palette. An unknown name (a palette renamed or removed
  /// since it was saved) falls back to the default rather than throwing.
  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_prefsKey);
    value = GameThemeId.values.firstWhere(
      (id) => id.name == saved,
      orElse: () => defaultGameTheme,
    );
  }

  Future<void> select(GameThemeId id) async {
    value = id;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, id.name);
  }
}
