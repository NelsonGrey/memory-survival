// Simulated-player evidence for the requirements a usability study would
// otherwise have to answer. Scripted bots (lib/engine/bots.dart) play fixed
// seeds, so every number here is deterministic. They show what the rules
// allow, not what players enjoy: real playtests are still listed in
// ACCEPTANCE_TESTING.md for MAS-BR-011.
import 'package:flutter_test/flutter_test.dart';
import 'package:memory_survival/engine/engine.dart';

const _seeds = 30;

class _Result {
  _Result(this.points, this.cycles, this.firstPlaced);
  final double points;
  final double cycles;
  final double firstPlaced;
}

_Result _play(Bot bot, Difficulty d) {
  var points = 0, cycles = 0, placed = 0;
  for (var seed = 1; seed <= _seeds; seed++) {
    final s = playBot(d.rules, bot, seed);
    points += s.score.points;
    cycles += s.cycle;
    if (s.score.placed > 0) placed++;
  }
  return _Result(points / _seeds, cycles / _seeds, placed / _seeds);
}

void main() {
  group('MAS-BR-002: size and lifetime both matter', () {
    test('different strategies give clearly different results', () {
      final firstFitResult = _play(firstFit, Difficulty.normal);
      final lifetime = _play(lifetimeAware, Difficulty.normal);
      final tidyResult = _play(tidyCompact, Difficulty.normal);
      expect(lifetime.points, isNot(closeTo(firstFitResult.points, 1)));
      // Thinking about space beyond "first hole that fits" pays off.
      expect(tidyResult.points, greaterThan(firstFitResult.points * 1.5));
    });

    test('reading lifetimes beats ignoring them on every difficulty', () {
      for (final d in Difficulty.values) {
        final ignoring = _play(firstFit, d);
        final reading = _play(lifetimeAware, d);
        expect(
          reading.points,
          greaterThan(ignoring.points),
          reason: 'lifetime-aware should beat first-fit on ${d.label}',
        );
      }
    });
  });

  group('MAS-BR-004: compaction is a worthwhile, costed tool', () {
    test('using compaction well scores much higher than never using it', () {
      final without = _play(lifetimeAware, Difficulty.normal);
      final withCompaction = _play(lifetimeCompact, Difficulty.normal);
      expect(withCompaction.points, greaterThan(without.points * 1.5));
    });
  });

  group('Difficulty levels are ordered', () {
    test('Easy outlasts Normal, which outlasts Hard', () {
      final easy = _play(lifetimeAware, Difficulty.easy);
      final normal = _play(lifetimeAware, Difficulty.normal);
      final hard = _play(lifetimeAware, Difficulty.hard);
      expect(easy.cycles, greaterThan(normal.cycles));
      expect(normal.cycles, greaterThan(hard.cycles));
    });
  });

  group('MAS-BR-001: placement is understood', () {
    test('a casual player places a first process on every difficulty', () {
      for (final d in Difficulty.values) {
        expect(
          _play(humanCasual, d).firstPlaced,
          greaterThanOrEqualTo(0.8),
          reason: 'first-allocation success on ${d.label}',
        );
      }
    });

    test('a casual player lasts beyond the opening on Normal', () {
      // Well past the first wave: nobody fails at once on a sensible start.
      expect(_play(humanCasual, Difficulty.normal).cycles, greaterThan(30));
    });
  });
}
