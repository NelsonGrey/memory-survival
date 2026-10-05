import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:memory_survival/engine/engine.dart';

const rules = Ruleset(cellCount: 10, requestDeadline: 3, maxQueue: 3, lives: 1);
const engine = MemoryEngine(rules);

Request req(
  int id,
  int size, {
  int life = 5,
  int deadline = 3,
  bool pinned = false,
  ReleasePolicy policy = ReleasePolicy.normal,
}) => Request(
  id: id,
  size: size,
  lifetime: life,
  deadline: deadline,
  pinned: pinned,
  releasePolicy: policy,
);

MemoryProcess proc(
  int id,
  int start,
  int size, {
  int remaining = 5,
  bool pinned = false,
}) => MemoryProcess(
  id: id,
  size: size,
  start: start,
  remaining: remaining,
  pinned: pinned,
);

void main() {
  group('placement', () {
    test('places a request into free cells', () {
      final s = engine.initial(requests: [req(1, 3)]);
      final r = engine.place(s, 1, 2);
      expect(r.isOk, isTrue);
      expect(r.state!.cells.sublist(0, 6), [null, null, 1, 1, 1, null]);
      expect(r.state!.requestQueue, isEmpty);
    });

    test('rejects out of bounds, occupied and unknown', () {
      final s = engine.initial(
        processes: [proc(9, 4, 2)],
        requests: [req(1, 3)],
      );
      expect(engine.place(s, 1, 8).error, PlacementError.outOfBounds);
      expect(engine.place(s, 1, -1).error, PlacementError.outOfBounds);
      final occ = engine.place(s, 1, 3);
      expect(occ.error, PlacementError.occupied);
      expect(occ.blockedBy, 9);
      expect(engine.place(s, 2, 0).error, PlacementError.unknownRequest);
    });
  });

  group('metrics', () {
    test('gaps, largest block and fragmentation', () {
      final s = engine.initial(processes: [proc(1, 2, 2), proc(2, 6, 1)]);
      expect(s.gaps.map((g) => (g.start, g.size)), [(0, 2), (4, 2), (7, 3)]);
      expect(s.freeCells, 7);
      expect(s.largestFreeBlock, 3);
      expect(s.freeBlockCount, 3);
      expect(s.fragmentation, closeTo(1 - 3 / 7, 1e-9));
      expect(s.utilization, closeTo(0.3, 1e-9));
    });
  });

  group('tick', () {
    test('releases a process when its lifetime ends, leaks persist', () {
      var s = engine.initial(
        processes: [
          proc(1, 0, 2, remaining: 2),
          MemoryProcess(
            id: 2,
            size: 1,
            start: 5,
            remaining: 1,
            releasePolicy: ReleasePolicy.leak,
          ),
        ],
      );
      s = engine.tick(s);
      expect(s.processes.length, 2);
      s = engine.tick(s);
      expect(s.processes.map((p) => p.id), [2]);
      expect(s.score.completed, 1);
      expect(s.eventHistory.whereType<Released>().single.processId, 1);
    });

    test('classifies capacity failure', () {
      var s = engine.initial(
        processes: [proc(1, 0, 9, remaining: 99)],
        requests: [req(5, 3, deadline: 1)],
      );
      s = engine.tick(s);
      expect(s.status, RunStatus.failed);
      expect(s.failure!.kind, FailureKind.capacity);
    });

    test('classifies fragmentation failure', () {
      var s = engine.initial(
        processes: [
          proc(1, 2, 1, remaining: 99),
          proc(2, 5, 1, remaining: 99),
          proc(3, 8, 1, remaining: 99),
        ],
        requests: [req(5, 4, deadline: 1)],
      );
      s = engine.tick(s);
      expect(s.failure!.kind, FailureKind.fragmentation);
      expect(s.failure!.freeCells, 7);
      expect(s.failure!.largestFreeBlock, 2);
    });

    test('classifies deadline failure when a gap existed', () {
      var s = engine.initial(requests: [req(5, 2, deadline: 1)]);
      s = engine.tick(s);
      expect(s.failure!.kind, FailureKind.deadline);
    });

    test('space freed on the expiry tick is too late: deadline failure', () {
      var s = engine.initial(
        processes: [proc(1, 0, 10, remaining: 1)],
        requests: [req(5, 4, deadline: 1)],
      );
      s = engine.tick(s);
      expect(s.failure!.kind, FailureKind.deadline);
    });

    test('queue overflow is a rule failure', () {
      var s = engine.initial(requests: [req(1, 1), req(2, 1), req(3, 1)]);
      s = engine.tick(s, arrivals: [req(4, 1)]);
      expect(s.failure!.kind, FailureKind.rule);
    });

    test('a failed run no longer changes', () {
      var s = engine.initial(requests: [req(5, 2, deadline: 1)]);
      s = engine.tick(s);
      expect(identical(engine.tick(s), s), isTrue);
      expect(engine.place(s, 5, 0).error, PlacementError.notPlaying);
    });
  });

  group('lives', () {
    const threeLives = Ruleset(cellCount: 10, requestDeadline: 3, lives: 3);
    const eng3 = MemoryEngine(threeLives);

    test('an expired request costs a life and is dropped', () {
      var s = eng3.initial(requests: [req(5, 2, deadline: 1)]);
      s = eng3.tick(s);
      expect(s.status, RunStatus.playing);
      expect(s.livesLeft, 2);
      expect(s.faultCount, 1);
      expect(s.requestQueue, isEmpty);
      expect(s.failure!.kind, FailureKind.deadline);
    });

    test('a refused arrival costs a life and is not queued', () {
      const tight = Ruleset(cellCount: 10, maxQueue: 1, lives: 3);
      final e = MemoryEngine(tight);
      var s = e.initial(requests: [req(1, 1)]);
      s = e.tick(s, arrivals: [req(2, 1)]);
      expect(s.livesLeft, 2);
      expect(s.failure!.kind, FailureKind.rule);
      expect(s.requestQueue.map((r) => r.id), [1]);
    });

    test('the run ends when the last life is lost', () {
      var s = eng3.initial(
        requests: [
          req(1, 2, deadline: 1),
          req(2, 2, deadline: 1),
          req(3, 2, deadline: 1),
        ],
      );
      s = eng3.tick(s);
      expect(s.status, RunStatus.failed);
      expect(s.livesLeft, 0);
      expect(s.faultCount, 3);
    });
  });

  group('compaction', () {
    test('slides processes down in order and charges the cost', () {
      var s = engine.initial(processes: [proc(1, 2, 2), proc(2, 6, 3)]);
      final r = engine.compact(s);
      expect(r.isOk, isTrue);
      final n = r.state!;
      expect(n.processes.map((p) => p.start), [0, 2]);
      expect(n.compactionsLeft, rules.compactionCharges - 1);
      expect(n.cycle, rules.compactionTickCost);
      // Two surviving ticks at ×1 earn 2 points; the compaction costs 5.
      expect(
        n.score.points,
        rules.survivalPoints * rules.compactionTickCost -
            rules.compactionPointCost,
      );
      expect(n.eventHistory.whereType<Moved>().length, 2);
    });

    test('pinned processes stay and block movement past them', () {
      final s = engine.initial(
        processes: [proc(1, 1, 2), proc(2, 4, 2, pinned: true), proc(3, 8, 2)],
      );
      final n = engine.compact(s).state!;
      expect(n.processes.map((p) => (p.id, p.start)), [(1, 0), (2, 4), (3, 6)]);
    });

    test('requests keep waiting during compaction', () {
      final s = engine.initial(
        processes: [proc(1, 3, 2, remaining: 99)],
        requests: [req(9, 1, deadline: 2)],
      );
      final n = engine.compact(s).state!;
      expect(n.status, RunStatus.failed);
      expect(n.failure!.kind, FailureKind.deadline);
    });

    test('rejects when out of charges or nothing to move', () {
      final packed = engine.initial(processes: [proc(1, 0, 2)]);
      expect(engine.compact(packed).error, CompactionError.nothingToMove);
      final s = engine.initial(processes: [proc(1, 3, 2)]);
      final none = MemoryState(
        rules: rules,
        seed: 0,
        processes: s.processes,
        compactionsLeft: 0,
      );
      expect(engine.compact(none).error, CompactionError.noChargesLeft);
    });
  });

  group('determinism and invariants', () {
    const endless = Ruleset(cellCount: 16);
    const eng = MemoryEngine(endless);

    /// Plays first-fit with occasional compaction; returns the final state.
    MemoryState play(
      int seed, {
      int ticks = 300,
      void Function(MemoryState)? check,
    }) {
      final gen = RequestGenerator(endless, seed);
      var s = eng.initial(seed: seed);
      for (var i = 0; i < ticks && s.status == RunStatus.playing; i++) {
        for (final r in List.of(s.requestQueue)) {
          for (final g in s.gaps) {
            if (g.size >= r.size && eng.validate(s, r, g.start) == null) {
              s = eng.place(s, r.id, g.start).state!;
              break;
            }
          }
        }
        s = eng.tick(s, arrivals: gen.arrivalsFor(s.cycle + 1));
        check?.call(s);
      }
      return s;
    }

    test('identical seed and actions replay identically', () {
      final a = play(42), b = play(42);
      expect(a.cycle, b.cycle);
      expect(a.score.points, b.score.points);
      expect(a.eventHistory.length, b.eventHistory.length);
      expect(a.failure?.kind, b.failure?.kind);
      expect(
        a.eventHistory.length == play(43).eventHistory.length &&
            a.score.points == play(43).score.points,
        isFalse,
      );
    });

    test('generator is independent of call order', () {
      final gen = RequestGenerator(endless, 7);
      final forward = [for (var i = 1; i <= 50; i++) gen.arrivalAt(i)?.size];
      final backward = [
        for (var i = 50; i >= 1; i--) gen.arrivalAt(i)?.size,
      ].reversed.toList();
      expect(forward, backward);
    });

    test('no overlap and cells conserved across many seeds', () {
      for (var seed = 0; seed < 100; seed++) {
        play(
          seed,
          check: (s) {
            var used = 0;
            var prevEnd = 0;
            for (final p in s.processes) {
              expect(p.start, greaterThanOrEqualTo(prevEnd));
              expect(p.end, lessThanOrEqualTo(s.cellCount));
              prevEnd = p.end;
              used += p.size;
            }
            expect(used + s.freeCells, s.cellCount);
            expect(s.cells.where((c) => c != null).length, used);
          },
        );
      }
    });

    test('compaction preserves order and sizes under random states', () {
      final rnd = Random(1);
      for (var n = 0; n < 200; n++) {
        final procs = <MemoryProcess>[];
        var cursor = 0;
        for (var id = 1; cursor < 14; id++) {
          cursor += rnd.nextInt(3);
          final size = 1 + rnd.nextInt(3);
          if (cursor + size > 16) break;
          procs.add(proc(id, cursor, size, pinned: rnd.nextInt(5) == 0));
          cursor += size;
        }
        final s = MemoryState(
          rules: endless,
          seed: 0,
          processes: procs,
          compactionsLeft: 1,
        );
        final r = eng.compact(s);
        if (!r.isOk) continue;
        final after = r.state!.processes;
        expect(after.map((p) => p.id), procs.map((p) => p.id));
        expect(after.map((p) => p.size), procs.map((p) => p.size));
        for (final p in after) {
          if (p.pinned) {
            expect(p.start, procs.firstWhere((q) => q.id == p.id).start);
          }
        }
      }
    });
  });
}
