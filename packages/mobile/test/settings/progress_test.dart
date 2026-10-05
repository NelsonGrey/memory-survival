import 'package:flutter_test/flutter_test.dart';
import 'package:memory_survival/engine/engine.dart';
import 'package:memory_survival/settings/daily_challenge.dart';
import 'package:memory_survival/settings/personal_bests.dart';
import 'package:memory_survival/settings/scenario_progress.dart';
import 'package:memory_survival/settings/suggestions_setting.dart';
import 'package:memory_survival/settings/unlocks.dart';
import 'package:memory_survival/theme/game_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('PersonalBests', () {
    test('records each best separately and persists them', () async {
      final b = PersonalBests();
      var r = await b.submit(
        const Score(peakStreak: 5, largestRescued: 3, wavesCleared: 2),
      );
      expect(r.streak && r.rescued && r.waves, isTrue);
      r = await b.submit(
        const Score(peakStreak: 4, largestRescued: 4, wavesCleared: 1),
      );
      expect(r.streak, isFalse);
      expect(r.rescued, isTrue);
      expect(r.waves, isFalse);
      expect((b.bestStreak, b.largestRescued, b.mostWaves), (5, 4, 2));

      final again = PersonalBests();
      await again.load();
      expect(
        (again.bestStreak, again.largestRescued, again.mostWaves),
        (5, 4, 2),
      );
    });

    test('an equal or worse run is not a record', () async {
      final b = PersonalBests();
      await b.submit(const Score(peakStreak: 3));
      final r = await b.submit(const Score(peakStreak: 3));
      expect(r.any, isFalse);
    });

    test('bests are kept per ruleset version', () async {
      await PersonalBests(rulesetVersion: 1).submit(const Score(peakStreak: 9));
      final other = PersonalBests(rulesetVersion: 2);
      await other.load();
      expect(other.bestStreak, 0);
    });
  });

  group('DailyChallenge', () {
    DailyChallenge on(int y, int m, int d, {int version = 4}) =>
        DailyChallenge(now: () => DateTime(y, m, d), rulesetVersion: version);

    test('the seed is stable within a day and differs between days', () {
      expect(on(2026, 10, 5).seed, on(2026, 10, 5).seed);
      expect(on(2026, 10, 5).seed, isNot(on(2026, 10, 6).seed));
      expect(on(2026, 10, 5).seed, isNot(on(2026, 10, 5, version: 5).seed));
      expect(on(2026, 10, 5).dayKey, '20261005');
      expect(on(2026, 10, 5).seed, greaterThanOrEqualTo(0));
    });

    test('keeps the best score per day and persists it', () async {
      final d = on(2026, 10, 5);
      expect(d.todaysBest, isNull);
      expect(await d.submit(100), isTrue);
      expect(await d.submit(80), isFalse);
      expect(await d.submit(120), isTrue);
      final again = on(2026, 10, 5);
      await again.load();
      expect(again.todaysBest, 120);
      final tomorrow = on(2026, 10, 6);
      await tomorrow.load();
      expect(tomorrow.todaysBest, isNull);
    });

    test('drops entries older than a week', () async {
      await on(2026, 10, 1).submit(50);
      final later = on(2026, 10, 20);
      await later.load();
      await later.submit(10);
      final check = on(2026, 10, 20);
      await check.load();
      expect(check.todaysBest, 10);
      final old = on(2026, 10, 1);
      await old.load();
      expect(old.todaysBest, isNull);
    });
  });

  group('ScenarioProgress', () {
    test('only the first scenario is open at the start', () {
      final p = ScenarioProgress();
      expect(p.isUnlocked('c1-01'), isTrue);
      expect(p.isUnlocked('c1-02'), isFalse);
      expect(p.isUnlocked('missing'), isFalse);
    });

    test('clearing a scenario opens the next', () async {
      final p = ScenarioProgress();
      final fresh = await p.record('c1-01', {Objective.survive});
      expect(fresh, {Objective.survive});
      expect(p.isCleared('c1-01'), isTrue);
      expect(p.isUnlocked('c1-02'), isTrue);
      expect(p.isUnlocked('c1-03'), isFalse);
    });

    test('a run without the survive objective clears nothing', () async {
      final p = ScenarioProgress();
      await p.record('c1-01', {Objective.tidy});
      expect(p.isCleared('c1-01'), isFalse);
      expect(p.isUnlocked('c1-02'), isFalse);
    });

    test('stars accumulate and only new ones are reported', () async {
      final p = ScenarioProgress();
      await p.record('c1-01', {Objective.survive});
      final fresh = await p.record('c1-01', {
        Objective.survive,
        Objective.tidy,
        Objective.clean,
      });
      expect(fresh, {Objective.tidy, Objective.clean});
      expect(p.starsFor('c1-01'), 3);
      expect(p.totalStars, 3);
      expect(await p.record('c1-01', {Objective.survive}), isEmpty);
    });

    test('progress persists across loads', () async {
      final p = ScenarioProgress();
      await p.record('c1-01', {Objective.survive, Objective.clean});
      final again = ScenarioProgress();
      await again.load();
      expect(again.metFor('c1-01'), {Objective.survive, Objective.clean});
      expect(again.clearedCount, 1);
    });

    test('the campaign is complete only when all 36 are cleared', () async {
      final p = ScenarioProgress();
      for (final s in scenarios.take(35)) {
        await p.record(s.id, {Objective.survive});
      }
      expect(p.campaignComplete, isFalse);
      await p.record(scenarios.last.id, {Objective.survive});
      expect(p.campaignComplete, isTrue);
    });
  });

  group('SuggestionsSetting', () {
    test('is off by default and persists', () async {
      final s = SuggestionsSetting();
      expect(s.value, isFalse);
      await s.set(true);
      final again = SuggestionsSetting();
      await again.load();
      expect(again.value, isTrue);
    });
  });

  group('palette unlocks', () {
    test('accessible and base palettes are always open', () {
      final bests = PersonalBests();
      final progress = ScenarioProgress();
      for (final id in [
        GameThemeId.dark,
        GameThemeId.light,
        GameThemeId.highContrast,
      ]) {
        expect(isPaletteUnlocked(id, bests, progress), isTrue, reason: '$id');
      }
    });

    test('ember needs a long clean streak', () async {
      final bests = PersonalBests();
      final progress = ScenarioProgress();
      expect(isPaletteUnlocked(GameThemeId.ember, bests, progress), isFalse);
      await bests.submit(const Score(peakStreak: 12));
      expect(isPaletteUnlocked(GameThemeId.ember, bests, progress), isTrue);
    });

    test('forest needs scenario stars', () async {
      final bests = PersonalBests();
      final progress = ScenarioProgress();
      expect(isPaletteUnlocked(GameThemeId.forest, bests, progress), isFalse);
      for (final s in scenarios.take(7)) {
        await progress.record(s.id, {
          Objective.survive,
          Objective.tidy,
          Objective.clean,
        });
      }
      expect(progress.totalStars, 21);
      expect(isPaletteUnlocked(GameThemeId.forest, bests, progress), isTrue);
    });

    test('unlocks never touch gameplay values', () {
      // Palettes are cosmetic: the rules a run plays under are unaffected.
      expect(const Ruleset().cellCount, 16);
      expect(
        paletteUnlocks.keys.every((k) => gameThemePalettes.containsKey(k)),
        isTrue,
      );
    });
  });
}
