import 'package:flutter_test/flutter_test.dart';
import 'package:memory_survival/engine/engine.dart';

const quiet = Ruleset(
  cellCount: 12,
  wavePeriod: 0,
  requestDeadline: 5,
  maxQueue: 4,
  lives: 3,
  multiplierStep: 2,
);
const eng = MemoryEngine(quiet);

Request req(
  int id,
  int size, {
  int life = 4,
  int deadline = 5,
  RequestFamily family = RequestFamily.standard,
  int? linkedWith,
  ReleasePolicy policy = ReleasePolicy.normal,
}) => Request(
  id: id,
  size: size,
  lifetime: life,
  deadline: deadline,
  family: family,
  linkedWith: linkedWith,
  releasePolicy: policy,
);

MemoryProcess proc(
  int id,
  int start,
  int size, {
  int remaining = 5,
  ReleasePolicy policy = ReleasePolicy.normal,
}) => MemoryProcess(
  id: id,
  size: size,
  start: start,
  remaining: remaining,
  releasePolicy: policy,
);

MemoryState withStreak(MemoryState s, int streak) => s.copyWith(streak: streak);

void main() {
  group('waves', () {
    const w = Ruleset();

    test('phases repeat: calm, warning, storm, recovery', () {
      expect(waveAt(w, 0).phase, WavePhase.calm);
      expect(waveAt(w, 14).phase, WavePhase.calm);
      expect(waveAt(w, 15).phase, WavePhase.warning);
      expect(waveAt(w, 19).phase, WavePhase.warning);
      expect(waveAt(w, 20).phase, WavePhase.storm);
      expect(waveAt(w, 24).phase, WavePhase.storm);
      expect(waveAt(w, 25).phase, WavePhase.recovery);
      expect(waveAt(w, 28).phase, WavePhase.recovery);
      expect(waveAt(w, 29).phase, WavePhase.calm);
      expect(waveAt(w, 45).phase, WavePhase.storm);
    });

    test('wave numbers climb and the storm counts down', () {
      expect(waveAt(w, 3).number, 1);
      expect(waveAt(w, 27).number, 2);
      expect(waveAt(w, 20).ticksLeftInStorm, 5);
      expect(waveAt(w, 24).ticksLeftInStorm, 1);
      expect(waveAt(w, 15).ticksToStorm, 5);
    });

    test('a period of 0 turns waves off', () {
      for (final c in [0, 20, 24, 100]) {
        expect(waveAt(const Ruleset(wavePeriod: 0), c).phase, WavePhase.calm);
      }
    });

    test('recovery brings no arrivals; storms bring more than calm', () {
      for (var seed = 0; seed < 20; seed++) {
        final g = RequestGenerator(w, seed);
        for (var c = 25; c <= 28; c++) {
          expect(g.arrivalAt(c), isNull, reason: 'seed $seed cycle $c');
        }
      }
      var storm = 0, calm = 0;
      for (var seed = 0; seed < 100; seed++) {
        final g = RequestGenerator(w, seed);
        for (var c = 20; c <= 24; c++) {
          if (g.arrivalAt(c) != null) storm++;
        }
        for (var c = 1; c <= 5; c++) {
          if (g.arrivalAt(c) != null) calm++;
        }
      }
      expect(storm, greaterThan(calm));
    });
  });

  group('generator', () {
    test('wave 1 has only standard requests; wave 2 unlocks burst', () {
      const rules = Ruleset(familyPerMille: 1000);
      final fams1 = <RequestFamily>{};
      final fams2 = <RequestFamily>{};
      for (var seed = 0; seed < 60; seed++) {
        final g = RequestGenerator(rules, seed);
        for (var c = 1; c < 25; c++) {
          final r = g.arrivalAt(c);
          if (r != null) fams1.add(r.family);
        }
        for (var c = 29; c < 50; c++) {
          final r = g.arrivalAt(c);
          if (r != null) fams2.add(r.family);
        }
      }
      expect(fams1, {RequestFamily.standard});
      expect(fams2, {RequestFamily.burst});
    });

    test('each wave unlocks exactly one more family', () {
      const rules = Ruleset(
        familyPerMille: 1000,
        arrivalPerMille: 1000,
        arrivalMaxPerMille: 1000,
      );
      for (var wave = 2; wave <= 8; wave++) {
        final seen = <RequestFamily>{};
        for (var seed = 0; seed < 80; seed++) {
          final g = RequestGenerator(rules, seed);
          final base = (wave - 1) * 25 + 4;
          for (var c = base; c < base + 15; c++) {
            final r = g.arrivalAt(c);
            if (r != null && r.linkedWith == null) seen.add(r.family);
          }
        }
        expect(
          seen,
          familyUnlockOrder.take(wave - 1).toSet(),
          reason: 'wave $wave',
        );
      }
    });

    test('family shapes: burst big and short, resident small and long', () {
      const rules = Ruleset(
        familyPerMille: 1000,
        arrivalPerMille: 1000,
        arrivalMaxPerMille: 1000,
        progressiveFamilies: false,
        families: {RequestFamily.burst},
        wavePeriod: 0,
      );
      for (var c = 1; c < 100; c++) {
        final r = RequestGenerator(rules, 1).arrivalAt(c)!;
        expect(r.family, RequestFamily.burst);
        expect(r.size, greaterThanOrEqualTo(rules.maxSize - 1));
        expect(r.lifetime, lessThanOrEqualTo(rules.minLifetime + 1));
      }
      const res = Ruleset(
        familyPerMille: 1000,
        arrivalPerMille: 1000,
        arrivalMaxPerMille: 1000,
        progressiveFamilies: false,
        families: {RequestFamily.resident},
        wavePeriod: 0,
      );
      for (var c = 1; c < 100; c++) {
        final r = RequestGenerator(res, 1).arrivalAt(c)!;
        expect(r.size, lessThanOrEqualTo(res.minSize + 1));
        expect(r.lifetime, greaterThanOrEqualTo(res.maxLifetime));
      }
    });

    test('priority waits less; volatile hides its lifetime in a range', () {
      Request find(RequestFamily f) {
        final rules = Ruleset(
          familyPerMille: 1000,
          arrivalPerMille: 1000,
          arrivalMaxPerMille: 1000,
          progressiveFamilies: false,
          families: {f},
          wavePeriod: 0,
        );
        return RequestGenerator(rules, 2).arrivalAt(5)!;
      }

      final p = find(RequestFamily.priority);
      expect(p.deadline, lessThan(const Ruleset().requestDeadline));
      expect(p.pointsFactor, 2);
      final v = find(RequestFamily.volatile);
      expect(v.lifetimeMin, isNotNull);
      expect(
        v.lifetimeMin! <= v.lifetime && v.lifetime <= v.lifetimeMax!,
        isTrue,
      );
      expect(v.lifetimeMax! - v.lifetimeMin!, greaterThan(0));
    });

    test('pinned and leak families set the matching flags', () {
      Request pick(RequestFamily f) => RequestGenerator(
        Ruleset(
          familyPerMille: 1000,
          arrivalPerMille: 1000,
          arrivalMaxPerMille: 1000,
          progressiveFamilies: false,
          families: {f},
          wavePeriod: 0,
        ),
        3,
      ).arrivalAt(7)!;
      expect(pick(RequestFamily.pinned).pinned, isTrue);
      expect(pick(RequestFamily.leak).releasePolicy, ReleasePolicy.leak);
    });

    test('a linked leader is always followed by its partner', () {
      const rules = Ruleset(
        familyPerMille: 1000,
        arrivalPerMille: 1000,
        arrivalMaxPerMille: 1000,
        progressiveFamilies: false,
        families: {RequestFamily.linked},
        wavePeriod: 0,
      );
      var leaders = 0;
      for (var seed = 0; seed < 30; seed++) {
        final g = RequestGenerator(rules, seed);
        for (var c = 1; c < 60; c++) {
          final r = g.arrivalAt(c)!;
          if (r.linkedWith == null) {
            leaders++;
            expect(g.arrivalAt(c + 1)!.linkedWith, c);
          } else {
            expect(r.linkedWith, c - 1);
          }
        }
      }
      expect(leaders, greaterThan(0));
    });

    test('overclock only adds arrivals, never changes them', () {
      final g = RequestGenerator(const Ruleset(familyPerMille: 0), 11);
      var extra = 0;
      for (var c = 1; c < 400; c++) {
        final calm = g.arrivalAt(c);
        final fast = g.arrivalAt(c, overclocked: true);
        if (calm != null && calm.linkedWith == null) {
          expect(fast, isNotNull);
          expect(fast!.size, calm.size);
          expect(fast.lifetime, calm.lifetime);
        } else if (calm == null && fast != null) {
          extra++;
        }
      }
      expect(extra, greaterThan(0));
    });

    test('upcoming lists the next arrivals with their distance', () {
      final g = RequestGenerator(const Ruleset(), 4);
      final up = g.upcoming(0, count: 3, horizon: 40);
      expect(up.length, 3);
      for (final u in up) {
        expect(g.arrivalAt(u.ticksAway)!.id, u.request.id);
      }
      final distances = up.map((u) => u.ticksAway).toList();
      expect(distances, [...distances]..sort());
    });
  });

  group('multiplier and scoring', () {
    test('a completed process builds the streak and tier', () {
      var s = eng.initial(
        processes: [proc(1, 0, 2, remaining: 1), proc(2, 2, 2, remaining: 1)],
      );
      expect(s.multiplier, 1);
      s = eng.tick(s);
      expect(s.streak, 2);
      expect(s.multiplier, 2);
      expect(s.score.peakStreak, 2);
      expect(s.completionsToNextTier, 2);
    });

    test('tiers cap at the maximum', () {
      final s = withStreak(eng.initial(), 100);
      expect(s.multiplier, quiet.multiplierMax);
      expect(s.completionsToNextTier, isNull);
    });

    test('points scale with the multiplier: survival, completion, tidy', () {
      var s = withStreak(
        eng.initial(processes: [proc(1, 0, 3, remaining: 1)]),
        2,
      );
      expect(s.scoreFactor, 2);
      s = eng.tick(s);
      // survival 1 x2, completion 3 cells x2.
      expect(s.score.points, 2 + 6);
      final placed = eng.place(
        withStreak(eng.initial(requests: [req(9, 2)]), 2),
        9,
        0,
      );
      // 2 cells x2, plus the tidy bonus 1 x2 (placed at the edge).
      expect(placed.state!.score.points, 4 + 2);
    });

    test('a placement that splits a gap earns no tidy bonus', () {
      final s = eng.initial(requests: [req(9, 2)]);
      expect(eng.place(s, 9, 0).state!.score.points, 2 + quiet.tidyBonus);
      expect(eng.place(s, 9, 5).state!.score.points, 2);
    });

    test('priority completions pay double', () {
      var s = eng.initial(
        requests: [req(1, 3, life: 1, family: RequestFamily.priority)],
      );
      s = eng.place(s, 1, 0).state!;
      final before = s.score.points;
      s = eng.tick(s);
      expect(s.score.points - before, quiet.survivalPoints + 3 * 2);
    });

    test('a fault resets the streak', () {
      var s = withStreak(eng.initial(requests: [req(1, 3, deadline: 1)]), 7);
      s = eng.tick(s);
      expect(s.faultCount, 1);
      expect(s.streak, 0);
    });

    test('compaction drops one tier but not to zero', () {
      final s = withStreak(
        eng.initial(processes: [proc(1, 4, 2, remaining: 9)]),
        6,
      );
      expect(s.multiplier, 4);
      final n = eng.compact(s).state!;
      expect(n.multiplier, 3);
      expect(n.eventHistory.whereType<MultiplierDropped>(), isNotEmpty);
    });

    test('the waiting list filling up drops a tier once', () {
      var s = withStreak(
        eng.initial(
          requests: [
            req(1, 9, deadline: 9),
            req(2, 9, deadline: 9),
            req(3, 9, deadline: 9),
          ],
        ),
        4,
      );
      expect(s.multiplier, 3);
      s = eng.tick(s, arrivals: [req(4, 9, deadline: 9)]);
      expect(s.requestQueue.length, 4);
      expect(s.multiplier, 2);
      s = eng.tick(s);
      expect(s.multiplier, 2, reason: 'staying full does not drop it again');
    });

    test('fragmentation crossing the warning drops a tier and is counted', () {
      var s = withStreak(
        eng.initial(
          processes: [
            proc(1, 0, 2, remaining: 99),
            proc(2, 2, 2, remaining: 1),
            proc(3, 4, 2, remaining: 99),
            proc(4, 6, 4, remaining: 99),
          ],
        ),
        4,
      );
      // Free: only cells 10-11, below the minimum free to count as split.
      expect(s.fragmentationWarning, isFalse);
      s = eng.tick(s);
      // Process 2 left: free 2-3 and 10-11, four cells in two halves.
      expect(s.fragmentationWarning, isTrue);
      expect(s.score.fragmentationWarnings, 1);
      // Streak 4 + 1 completion = 5 (tier 3), dropped one tier to 2.
      expect(s.streak, 2);
      expect(s.eventHistory.whereType<MultiplierDropped>(), isNotEmpty);
      // Staying split does not count again.
      s = eng.tick(s);
      expect(s.score.fragmentationWarnings, 1);
    });

    test('assisted placement earns no streak and no multiplier', () {
      var s = withStreak(eng.initial(requests: [req(1, 2, life: 1)]), 4);
      final before = s.score.points;
      s = eng.place(s, 1, 0, assisted: true).state!;
      expect(s.score.points - before, 2, reason: 'base points, no tidy bonus');
      s = eng.tick(s);
      expect(s.streak, 4, reason: 'an assisted completion earns no streak');
    });

    test('rescuing a request with two ticks or less left is recorded', () {
      var s = eng.initial(
        requests: [req(1, 4, deadline: 2), req(2, 2, deadline: 5)],
      );
      s = eng.place(s, 2, 0).state!;
      expect(s.score.largestRescued, 0);
      s = eng.place(s, 1, 4).state!;
      expect(s.score.largestRescued, 4);
    });
  });

  group('waves in the engine', () {
    const waved = Ruleset(cellCount: 12);
    const e = MemoryEngine(waved);

    MemoryState run(MemoryState s, int to) {
      while (s.cycle < to && s.status == RunStatus.playing) {
        s = e.tick(s);
      }
      return s;
    }

    test('a clean storm pays out, cools the system and counts', () {
      var s = e.initial().copyWith(heat: 1);
      s = run(s, 25);
      expect(s.score.wavesCleared, 1);
      expect(s.heat, 0);
      final event = s.eventHistory.whereType<WaveCleared>().single;
      expect(event.clean, isTrue);
      expect(event.bonus, waved.wavePayout);
    });

    test('a fault during the storm forfeits the payout', () {
      var s = run(e.initial(), 20);
      s = s.copyWith(lastFaultCycle: 22);
      s = run(s, 25);
      final event = s.eventHistory.whereType<WaveCleared>().single;
      expect(event.clean, isFalse);
      expect(s.score.wavesCleared, 0);
    });

    test('a fault before the storm does not forfeit it', () {
      var s = run(e.initial(), 19);
      s = s.copyWith(lastFaultCycle: 19);
      s = run(s, 25);
      expect(s.eventHistory.whereType<WaveCleared>().single.clean, isTrue);
    });
  });

  group('heat', () {
    test('a fault raises heat and shortens new deadlines', () {
      var s = eng.initial(requests: [req(1, 3, deadline: 1)]);
      s = eng.tick(s, arrivals: [req(2, 3, deadline: 5)]);
      expect(s.heat, 1);
      expect(s.requestQueue.single.deadline, 5 - quiet.heatDeadlinePenalty);
    });

    test('heat never shortens a deadline below the minimum', () {
      var s = eng.initial().copyWith(heat: 2);
      s = eng.tick(s, arrivals: [req(2, 3, deadline: 2)]);
      expect(s.requestQueue.single.deadline, quiet.minDeadline);
    });

    test('the second fault quarantines a free cell, which later opens up', () {
      var s = eng.initial().copyWith(heat: 1);
      s = s.copyWith(requestQueue: [req(1, 3, deadline: 1)]);
      s = eng.tick(s);
      expect(s.heat, 2);
      final locks = s.processes.where((p) => p.kind == ProcessKind.quarantine);
      expect(locks.length, 1);
      expect(s.eventHistory.whereType<Quarantined>(), isNotEmpty);
      for (var i = 0; i < quiet.quarantineTicks + 1; i++) {
        s = eng.tick(s);
      }
      expect(
        s.processes.where((p) => p.kind == ProcessKind.quarantine),
        isEmpty,
      );
      expect(s.eventHistory.whereType<Unlocked>(), isNotEmpty);
    });

    test('the first fault only shortens deadlines; the last ends the run', () {
      var s = eng.initial(requests: [req(1, 3, deadline: 1)]);
      s = eng.tick(s);
      expect(s.processes.where((p) => !p.isNormal), isEmpty);
      s = s.copyWith(
        requestQueue: [req(2, 3, deadline: 1), req(3, 3, deadline: 1)],
      );
      s = eng.tick(s);
      expect(s.status, RunStatus.failed);
    });

    test('lives are never refunded by cooling', () {
      const e = MemoryEngine(Ruleset(cellCount: 12, wavePeriod: 25));
      var s = e.initial().copyWith(livesLeft: 1, heat: 2);
      for (var i = 0; i < 25; i++) {
        s = e.tick(s);
      }
      expect(s.livesLeft, 1);
      expect(s.heat, 1);
    });

    test('quarantined cells are immovable under compaction', () {
      var s = eng
          .initial(processes: [proc(1, 6, 2, remaining: 9)])
          .copyWith(heat: 1);
      s = s.copyWith(
        processes: [
          ...s.processes,
          const MemoryProcess(
            id: -1,
            size: 1,
            start: 3,
            remaining: 6,
            kind: ProcessKind.quarantine,
          ),
        ],
      );
      final n = eng.compact(s).state!;
      expect(n.processes.firstWhere((p) => p.id == -1).start, 3);
      expect(n.processes.firstWhere((p) => p.id == 1).start, 4);
    });
  });

  group('compaction with traffic', () {
    test('arrivals keep coming during the consumed ticks', () {
      final s = eng.initial(processes: [proc(1, 4, 2, remaining: 99)]);
      final seen = <int>[];
      final n = eng
          .compact(
            s,
            arrivals: (c) {
              seen.add(c);
              return [req(100 + c, 1)];
            },
          )
          .state!;
      expect(seen, [1, 2]);
      expect(n.requestQueue.map((r) => r.id), [101, 102]);
    });

    test('a flood during compaction can still cost a life', () {
      final s = eng.initial(
        processes: [proc(1, 4, 2, remaining: 99)],
        requests: [req(50, 1), req(51, 1), req(52, 1), req(53, 1)],
      );
      final n = eng.compact(s, arrivals: (c) => [req(200 + c, 1)]).state!;
      expect(n.faultCount, greaterThan(0));
    });
  });

  group('risk and reward', () {
    test('rejecting removes the request, breaks the streak, no fault', () {
      final s = withStreak(eng.initial(requests: [req(1, 3), req(2, 2)]), 5);
      final r = eng.reject(s, 1);
      expect(r.isOk, isTrue);
      expect(r.state!.requestQueue.map((q) => q.id), [2]);
      expect(r.state!.streak, 0);
      expect(r.state!.faultCount, 0);
      expect(r.state!.score.rejected, 1);
      expect(eng.reject(s, 99).error, ActionError.unknownTarget);
    });

    test('only one rejection per wave', () {
      const waved = Ruleset(cellCount: 12);
      const e = MemoryEngine(waved);
      var s = e.initial(
        requests: [req(1, 3, deadline: 9), req(2, 3, deadline: 9)],
      );
      s = e.reject(s, 1).state!;
      expect(e.reject(s, 2).error, ActionError.unavailable);
      s = s.copyWith(cycle: 30);
      expect(e.reject(s, 2).isOk, isTrue);
    });

    test('overclock doubles score, then needs a cooldown', () {
      var s = eng.initial();
      s = eng.overclock(s).state!;
      expect(s.overclocked, isTrue);
      expect(s.scoreFactor, 2);
      expect(eng.overclock(s).error, ActionError.unavailable);
      for (var i = 0; i < quiet.overclockTicks; i++) {
        s = eng.tick(s);
      }
      expect(s.overclocked, isFalse);
      expect(
        eng.overclock(s).error,
        ActionError.unavailable,
        reason: 'still cooling down',
      );
      for (var i = 0; i < quiet.overclockCooldown; i++) {
        s = eng.tick(s);
      }
      expect(eng.overclock(s).isOk, isTrue);
    });

    test('reserve holds a region only for the forecast request', () {
      var s = eng.initial(requests: [req(7, 3), req(8, 2)]);
      s = eng.reserve(s, start: 4, size: 3, forRequestId: 7).state!;
      expect(s.reservation, isNotNull);
      expect(eng.place(s, 8, 5).error, PlacementError.occupied);
      expect(eng.place(s, 8, 0).isOk, isTrue);
      final claimed = eng.place(s, 7, 4).state!;
      expect(claimed.reservation, isNull);
      expect(claimed.processes.single.id, 7);
      expect(claimed.processes.single.start, 4);
    });

    test('a reservation expires and only one can be held', () {
      var s = eng.initial();
      s = eng.reserve(s, start: 0, size: 2, forRequestId: 40).state!;
      expect(
        eng.reserve(s, start: 6, size: 2, forRequestId: 41).error,
        ActionError.alreadyReserved,
      );
      for (var i = 0; i < quiet.reserveTicks + 1; i++) {
        s = eng.tick(s);
      }
      expect(s.reservation, isNull);
      expect(eng.reserve(s, start: 6, size: 2, forRequestId: 41).isOk, isTrue);
    });

    test('reserving needs free cells inside memory', () {
      final s = eng.initial(processes: [proc(1, 3, 2)]);
      expect(
        eng.reserve(s, start: 2, size: 3, forRequestId: 9).error,
        ActionError.regionBusy,
      );
      expect(
        eng.reserve(s, start: 10, size: 5, forRequestId: 9).error,
        ActionError.outOfBounds,
      );
    });

    test('a faulted request drops its reservation', () {
      var s = eng.initial(requests: [req(7, 3, deadline: 1)]);
      s = eng.reserve(s, start: 4, size: 3, forRequestId: 7).state!;
      s = eng.tick(s);
      expect(s.reservation, isNull);
    });

    test('cleanup ends a leak, locks half its cells and costs points', () {
      var s = eng.initial(
        processes: [proc(1, 2, 5, policy: ReleasePolicy.leak)],
      );
      s = eng.cleanup(s, 1).state!;
      expect(s.processes.single.kind, ProcessKind.quarantine);
      expect(s.processes.single.size, 3);
      expect(s.processes.single.start, 2);
      expect(s.score.points, -quiet.cleanupPointCost);
      expect(s.freeCells, 12 - 3);
      for (var i = 0; i < quiet.cleanupLockTicks + 1; i++) {
        s = eng.tick(s);
      }
      expect(s.processes, isEmpty);
    });

    test('cleanup refuses ordinary processes', () {
      final s = eng.initial(processes: [proc(1, 0, 2)]);
      expect(eng.cleanup(s, 1).error, ActionError.notALeak);
      expect(eng.cleanup(s, 5).error, ActionError.unknownTarget);
    });
  });

  group('linked pairs', () {
    Request leader() => req(1, 2, family: RequestFamily.linked);
    Request follower() =>
        req(2, 2, family: RequestFamily.linked, linkedWith: 1);

    test('the second half must sit beside the first', () {
      var s = eng.initial(requests: [leader(), follower()]);
      s = eng.place(s, 1, 4).state!;
      final far = eng.place(s, 2, 8);
      expect(far.error, PlacementError.notAdjacent);
      expect(far.linkedTo, 1);
      expect(eng.place(s, 2, 6).isOk, isTrue);
      expect(eng.place(s, 2, 2).isOk, isTrue);
    });

    test('placing the leader after the follower is checked too', () {
      var s = eng.initial(requests: [leader(), follower()]);
      s = eng.place(s, 2, 6).state!;
      expect(eng.place(s, 1, 0).error, PlacementError.notAdjacent);
      expect(eng.place(s, 1, 4).isOk, isTrue);
    });

    test('validStarts and validate agree', () {
      final s = eng.initial(
        processes: [proc(1, 4, 2)],
        requests: [req(2, 2, linkedWith: 1)],
      );
      expect(eng.validStarts(s, s.requestQueue.single), [2, 6]);
    });
  });

  group('placement help', () {
    test('previewPlacement reports what would be left', () {
      final s = eng.initial(processes: [proc(1, 5, 2)], requests: [req(2, 3)]);
      final r = s.requestQueue.single;
      final atEdge = eng.previewPlacement(s, r, 0)!;
      expect(atEdge.largestFreeBlock, 5);
      expect(atEdge.freeBlockCount, 2);
      expect(eng.previewPlacement(s, r, 1)!.freeBlockCount, 3);
      expect(eng.previewPlacement(s, r, 4), isNull);
    });

    test('the suggestion fills the tightest gap at its tidy edge', () {
      final s = eng.initial(
        processes: [proc(1, 3, 1), proc(2, 7, 1)],
        requests: [req(3, 3)],
      );
      final r = s.requestQueue.single;
      final start = eng.recommendedStart(s, r)!;
      expect(start == 0 || start == 4, isTrue);
      expect(
        eng.previewPlacement(s, r, start)!.freeBlockCount,
        2,
        reason: 'fills a gap exactly',
      );
    });

    test('no suggestion when nothing fits', () {
      final s = eng.initial(
        processes: [proc(1, 3, 1), proc(2, 5, 1)],
        requests: [req(3, 7)],
      );
      expect(eng.recommendedStart(s, s.requestQueue.single), isNull);
    });
  });

  group('goal', () {
    test('reaching the goal completes the run', () {
      const goal = Ruleset(cellCount: 8, wavePeriod: 0, goalTicks: 3);
      const e = MemoryEngine(goal);
      var s = e.initial();
      s = e.tick(e.tick(s));
      expect(s.status, RunStatus.playing);
      s = e.tick(s);
      expect(s.status, RunStatus.completed);
      expect(e.tick(s).cycle, s.cycle, reason: 'a finished run is frozen');
    });
  });
}
