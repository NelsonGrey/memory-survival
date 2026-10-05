import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../engine/engine.dart';

/// Best endless score on this device. Stored per ruleset version so a balance
/// change never silently compares incompatible runs (TRD section 6).
class BestScore extends ValueNotifier<int> {
  BestScore({int rulesetVersion = Ruleset.currentVersion})
    : _key = 'best.score.v$rulesetVersion',
      super(0);

  final String _key;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    value = prefs.getInt(_key) ?? 0;
  }

  /// Records [score] if it beats the current best; returns whether it did.
  Future<bool> submit(int score) async {
    if (score <= value) return false;
    value = score;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_key, score);
    return true;
  }
}
