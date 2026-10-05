import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../engine/engine.dart';

/// Which objectives the player has met in each authored scenario. Stored by
/// scenario id and ruleset version, so a rebalanced scenario starts fresh
/// rather than keeping stars earned under different rules.
class ScenarioProgress extends ChangeNotifier {
  ScenarioProgress({int rulesetVersion = Ruleset.currentVersion})
    : _prefix = 'scn.v$rulesetVersion';

  final String _prefix;
  final Map<String, Set<Objective>> _met = {};

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _met.clear();
    for (final s in scenarios) {
      final mask = prefs.getInt('$_prefix.${s.id}');
      if (mask != null) _met[s.id] = _fromMask(mask);
    }
    notifyListeners();
  }

  Set<Objective> metFor(String id) => _met[id] ?? const {};

  bool isCleared(String id) => metFor(id).contains(Objective.survive);

  /// Stars earned in one scenario, 0..3.
  int starsFor(String id) => metFor(id).length;

  int get totalStars => _met.values.fold(0, (sum, m) => sum + m.length);

  int get clearedCount => scenarios.where((s) => isCleared(s.id)).length;

  bool get campaignComplete => clearedCount == scenarios.length;

  /// A scenario is playable once the one before it (in play order) is
  /// cleared; the first is always open.
  bool isUnlocked(String id) {
    final i = scenarios.indexWhere((s) => s.id == id);
    if (i <= 0) return i == 0;
    return isCleared(scenarios[i - 1].id);
  }

  /// Merges [met] into what is already earned; returns the objectives that
  /// are new.
  Future<Set<Objective>> record(String id, Set<Objective> met) async {
    final before = metFor(id);
    final fresh = met.difference(before);
    if (fresh.isEmpty) return fresh;
    _met[id] = {...before, ...met};
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('$_prefix.$id', _toMask(_met[id]!));
    notifyListeners();
    return fresh;
  }

  static int _toMask(Set<Objective> m) =>
      m.fold(0, (mask, o) => mask | (1 << o.index));

  static Set<Objective> _fromMask(int mask) => {
    for (final o in Objective.values)
      if (mask & (1 << o.index) != 0) o,
  };
}
