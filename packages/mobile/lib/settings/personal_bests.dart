import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../engine/engine.dart';

/// Which personal bests a finished run beat.
class NewRecords {
  const NewRecords({
    this.streak = false,
    this.rescued = false,
    this.waves = false,
  });

  final bool streak;
  final bool rescued;
  final bool waves;

  bool get any => streak || rescued || waves;
}

/// Personal bests on this device, stored per ruleset version so a balance
/// change never compares incompatible runs (TRD section 6): longest
/// clean streak, largest request rescued at the last moment, and most waves
/// cleared.
class PersonalBests extends ChangeNotifier {
  PersonalBests({int rulesetVersion = Ruleset.currentVersion})
    : _prefix = 'pb.v$rulesetVersion';

  final String _prefix;

  int bestStreak = 0;
  int largestRescued = 0;
  int mostWaves = 0;

  String get _streakKey => '$_prefix.streak';
  String get _rescuedKey => '$_prefix.rescued';
  String get _wavesKey => '$_prefix.waves';

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    bestStreak = prefs.getInt(_streakKey) ?? 0;
    largestRescued = prefs.getInt(_rescuedKey) ?? 0;
    mostWaves = prefs.getInt(_wavesKey) ?? 0;
    notifyListeners();
  }

  /// Records a finished run and reports which bests it beat. Score bests
  /// live in [BestScore] (endless) and [DailyChallenge] (per day).
  Future<NewRecords> submit(Score s) async {
    final records = NewRecords(
      streak: s.peakStreak > bestStreak,
      rescued: s.largestRescued > largestRescued,
      waves: s.wavesCleared > mostWaves,
    );
    if (!records.any) return records;
    final prefs = await SharedPreferences.getInstance();
    if (records.streak) {
      bestStreak = s.peakStreak;
      await prefs.setInt(_streakKey, bestStreak);
    }
    if (records.rescued) {
      largestRescued = s.largestRescued;
      await prefs.setInt(_rescuedKey, largestRescued);
    }
    if (records.waves) {
      mostWaves = s.wavesCleared;
      await prefs.setInt(_wavesKey, mostWaves);
    }
    notifyListeners();
    return records;
  }
}
