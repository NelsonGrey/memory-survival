import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../engine/engine.dart';

/// The endless-mode difficulty. Normal by default. Read when a run starts,
/// so changing it never alters a run in progress.
class DifficultySetting extends ValueNotifier<Difficulty> {
  DifficultySetting() : super(Difficulty.normal);

  static const _prefsKey = 'gameplay.difficulty';

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final name = prefs.getString(_prefsKey);
    value = Difficulty.values.firstWhere(
      (d) => d.name == name,
      orElse: () => Difficulty.normal,
    );
  }

  Future<void> set(Difficulty difficulty) async {
    value = difficulty;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, difficulty.name);
  }
}
