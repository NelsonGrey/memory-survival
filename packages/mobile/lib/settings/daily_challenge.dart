import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../engine/engine.dart';

/// Today's shared seed. Everyone who plays on the same calendar day (in
/// their own time zone) gets the same arrivals, so scores are comparable.
class DailyChallenge extends ChangeNotifier {
  DailyChallenge({
    DateTime Function()? now,
    int rulesetVersion = Ruleset.currentVersion,
  }) : _now = now ?? DateTime.now,
       _version = rulesetVersion;

  final DateTime Function() _now;
  final int _version;

  /// Best score per day, by [dayKey].
  final Map<String, int> _best = {};

  static String dayKeyFor(DateTime t) =>
      '${t.year.toString().padLeft(4, '0')}'
      '${t.month.toString().padLeft(2, '0')}'
      '${t.day.toString().padLeft(2, '0')}';

  String get dayKey => dayKeyFor(_now());

  /// A stable seed for the day: the date digits mixed with the ruleset
  /// version, so a rules change gives a fresh puzzle.
  int get seed => seedFor(dayKey, _version);

  static int seedFor(String dayKey, int version) {
    var h = 0x811C9DC5;
    for (final c in '$dayKey:$version'.codeUnits) {
      h = ((h ^ c) * 0x01000193) & 0x7FFFFFFF;
    }
    return h;
  }

  String get _prefsKey => 'daily.best.v$_version';

  int? get todaysBest => _best[dayKey];

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _best.clear();
    for (final entry in prefs.getStringList(_prefsKey) ?? const <String>[]) {
      final parts = entry.split('=');
      if (parts.length == 2) {
        final score = int.tryParse(parts[1]);
        if (score != null) _best[parts[0]] = score;
      }
    }
    notifyListeners();
  }

  /// Keeps the day's best, dropping entries older than a week. Returns
  /// whether [score] is a new best for the day.
  Future<bool> submit(int score) async {
    final key = dayKey;
    final current = _best[key];
    if (current != null && score <= current) return false;
    _best[key] = score;
    final cutoff = dayKeyFor(_now().subtract(const Duration(days: 7)));
    _best.removeWhere((k, _) => k.compareTo(cutoff) < 0);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_prefsKey, [
      for (final e in _best.entries) '${e.key}=${e.value}',
    ]);
    notifyListeners();
    return true;
  }
}
