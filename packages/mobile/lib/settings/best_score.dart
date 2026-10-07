import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../engine/engine.dart';

/// Best endless score on this device, kept per difficulty. Stored per ruleset
/// version so a balance change never silently compares incompatible runs
/// (TRD section 6). [value] is the best for the [selected] difficulty.
/// Normal keeps the pre-difficulty key, so existing bests carry over.
class BestScore extends ValueNotifier<int> {
  BestScore({int rulesetVersion = Ruleset.currentVersion})
    : _version = rulesetVersion,
      super(0);

  final int _version;
  final Map<Difficulty, int> _best = {};
  Difficulty _selected = Difficulty.normal;

  Difficulty get selected => _selected;

  String _key(Difficulty d) => d == Difficulty.normal
      ? 'best.score.v$_version'
      : 'best.score.v$_version.${d.name}';

  int bestFor(Difficulty d) => _best[d] ?? 0;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    for (final d in Difficulty.values) {
      _best[d] = prefs.getInt(_key(d)) ?? 0;
    }
    value = bestFor(_selected);
  }

  /// Switches [value] to the best for [difficulty].
  void select(Difficulty difficulty) {
    _selected = difficulty;
    value = bestFor(difficulty);
  }

  /// Records [score] for [difficulty] (default: the selected one) if it beats
  /// that difficulty's best; returns whether it did.
  Future<bool> submit(int score, {Difficulty? difficulty}) async {
    final d = difficulty ?? _selected;
    if (score <= bestFor(d)) return false;
    _best[d] = score;
    if (d == _selected) value = score;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_key(d), score);
    return true;
  }
}
