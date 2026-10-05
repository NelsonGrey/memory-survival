import 'package:flutter_test/flutter_test.dart';
import 'package:memory_survival/engine/engine.dart';

void main() {
  group('authored scenarios', () {
    test('there are 36: four chapters of nine', () {
      expect(scenarios.length, 36);
      for (final chapter in chapterTitles.keys) {
        expect(
          scenarios.where((s) => s.chapter == chapter).map((s) => s.number),
          [for (var i = 1; i <= 9; i++) i],
        );
      }
    });

    test('ids are stable, unique and well formed', () {
      final ids = scenarios.map((s) => s.id).toList();
      expect(ids.toSet().length, ids.length);
      expect(ids.first, 'c1-01');
      expect(ids.last, 'c4-09');
      expect(scenarioById('c3-05')!.chapter, 3);
      expect(scenarioById('nope'), isNull);
    });

    test('every scenario passes the validator', () {
      for (final s in scenarios) {
        expect(validateScenario(s), isEmpty, reason: s.id);
      }
    });

    test('the validator rejects broken scenarios', () {
      const bad = Scenario(
        id: 'x',
        chapter: 9,
        number: 0,
        title: '',
        lesson: '',
        rules: Ruleset(cellCount: 4, maxSize: 5),
        seed: 1,
      );
      expect(validateScenario(bad), hasLength(greaterThanOrEqualTo(5)));
    });

    test('every scenario is solvable by a scripted policy', () {
      for (final s in scenarios) {
        expect(isSolvable(s), isTrue, reason: '${s.id} ${s.title}');
      }
    });

    test('a careful scripted player clears every authored seed', () {
      for (final s in scenarios) {
        final end = playBot(
          s.rules,
          humanCareful,
          s.seed,
          cap: s.goalTicks + 5,
        );
        expect(end.status, RunStatus.completed, reason: s.id);
        expect(end.cycle, s.goalTicks);
      }
    });

    test('scenarios are deterministic', () {
      for (final s in scenarios.take(6)) {
        final a = playBot(s.rules, humanCareful, s.seed);
        final b = playBot(s.rules, humanCareful, s.seed);
        expect(a.score.points, b.score.points);
        expect(a.eventHistory.length, b.eventHistory.length);
      }
    });

    test('chapters teach their own mechanic', () {
      for (final s in scenarios.where((s) => s.chapter == 1)) {
        expect(s.rules.hasWaves, isFalse);
        expect(s.rules.families, isEmpty, reason: s.id);
      }
      for (final s in scenarios.where((s) => s.chapter == 3)) {
        expect(s.rules.compactionCharges, greaterThan(0), reason: s.id);
      }
      for (final s in scenarios.where((s) => s.chapter == 4)) {
        expect(s.rules.hasWaves, isTrue, reason: s.id);
      }
    });

    test('a failed run meets no objectives', () {
      final s = scenarios.first;
      const e = MemoryEngine(Ruleset());
      expect(s.objectivesMet(e.initial()), isEmpty);
    });

    test('objectives: survive, tidy and clean are judged separately', () {
      final s = scenarios.first;
      final done = MemoryState(
        rules: s.rules,
        seed: 1,
        status: RunStatus.completed,
      );
      expect(s.objectivesMet(done), Objective.values.toSet());
      final warned = done.copyWith(
        score: const Score(fragmentationWarnings: 1),
      );
      expect(s.objectivesMet(warned), {Objective.survive, Objective.clean});
      final compacted = done.copyWith(score: const Score(compactions: 1));
      expect(s.objectivesMet(compacted), {Objective.survive, Objective.tidy});
      final faulted = done.copyWith(faultCount: 1);
      expect(s.objectivesMet(faulted), {Objective.survive, Objective.tidy});
    });

    test('next scenario follows play order', () {
      expect(nextScenario('c1-01')!.id, 'c1-02');
      expect(nextScenario('c1-09')!.id, 'c2-01');
      expect(nextScenario('c4-09'), isNull);
    });
  });

  group('bots', () {
    test('scripted players are deterministic and respect the rules', () {
      for (final bot in allBots) {
        final a = playBot(const Ruleset(), bot, 9, cap: 80);
        final b = playBot(const Ruleset(), bot, 9, cap: 80);
        expect(a.score.points, b.score.points, reason: bot.name);
        var prev = 0;
        for (final p in a.processes) {
          expect(p.start, greaterThanOrEqualTo(prev));
          prev = p.end;
        }
      }
    });
  });
}
