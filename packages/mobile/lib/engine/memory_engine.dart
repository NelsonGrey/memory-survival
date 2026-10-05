import 'model.dart';
import 'ruleset.dart';

/// Why a placement was refused. Each reason is explainable from visible state.
enum PlacementError {
  notPlaying,
  unknownRequest,
  outOfBounds,

  /// At least one required cell is owned by another process.
  occupied,
}

class PlaceResult {
  const PlaceResult.ok(MemoryState this.state) : error = null, blockedBy = null;
  const PlaceResult.rejected(PlacementError this.error, {this.blockedBy})
    : state = null;

  final MemoryState? state;
  final PlacementError? error;

  /// For [PlacementError.occupied]: id of the first process in the way.
  final int? blockedBy;

  bool get isOk => state != null;
}

enum CompactionError { notPlaying, noChargesLeft, nothingToMove }

class CompactResult {
  const CompactResult.ok(MemoryState this.state) : error = null;
  const CompactResult.rejected(CompactionError this.error) : state = null;

  final MemoryState? state;
  final CompactionError? error;
  bool get isOk => state != null;
}

/// The deterministic simulation. Pure functions over [MemoryState]: no clock,
/// no randomness, no I/O. Arrivals are supplied by the caller (a scenario or
/// the seeded generator), so identical inputs always give identical results
/// (MAS-TR-001).
class MemoryEngine {
  const MemoryEngine(this.rules);

  final Ruleset rules;

  MemoryState initial({
    int seed = 0,
    List<MemoryProcess> processes = const [],
    List<Request> requests = const [],
  }) => MemoryState(
    rules: rules,
    seed: seed,
    processes: processes,
    requestQueue: requests,
    compactionsLeft: rules.compactionCharges,
    livesLeft: rules.lives,
  );

  /// Whether [request] fits at [start], without changing anything.
  PlacementError? validate(MemoryState s, Request request, int start) {
    if (start < 0 || start + request.size > s.cellCount) {
      return PlacementError.outOfBounds;
    }
    return _blocker(s, start, request.size) == null
        ? null
        : PlacementError.occupied;
  }

  MemoryProcess? _blocker(MemoryState s, int start, int size) {
    final end = start + size;
    for (final p in s.processes) {
      if (p.start < end && start < p.end) return p;
    }
    return null;
  }

  PlaceResult place(MemoryState s, int requestId, int start) {
    if (s.status != RunStatus.playing) {
      return const PlaceResult.rejected(PlacementError.notPlaying);
    }
    final request = s.requestById(requestId);
    if (request == null) {
      return const PlaceResult.rejected(PlacementError.unknownRequest);
    }
    if (start < 0 || start + request.size > s.cellCount) {
      return const PlaceResult.rejected(PlacementError.outOfBounds);
    }
    final blocker = _blocker(s, start, request.size);
    if (blocker != null) {
      return PlaceResult.rejected(
        PlacementError.occupied,
        blockedBy: blocker.id,
      );
    }
    return PlaceResult.ok(
      s.copyWith(
        processes: [
          ...s.processes,
          MemoryProcess(
            id: request.id,
            size: request.size,
            start: start,
            remaining: request.lifetime,
            releasePolicy: request.releasePolicy,
            pinned: request.pinned,
          ),
        ],
        requestQueue: [
          for (final r in s.requestQueue)
            if (r.id != requestId) r,
        ],
        score: s.score.copyWith(
          placed: s.score.placed + 1,
          points: s.score.points + request.size,
        ),
        appendEvents: [Placed(s.cycle, request.id, start, request.size)],
      ),
    );
  }

  /// Advances one tick: processes age and release, waiting requests age (a
  /// request out of time ends the run), then [arrivals] join the queue.
  MemoryState tick(MemoryState s, {List<Request> arrivals = const []}) {
    if (s.status != RunStatus.playing) return s;
    final cycle = s.cycle + 1;
    final events = <EngineEvent>[];
    var score = s.score.copyWith(ticksSurvived: s.score.ticksSurvived + 1);

    final kept = <MemoryProcess>[];
    for (final p in s.processes) {
      if (p.releasePolicy == ReleasePolicy.leak) {
        kept.add(p);
      } else if (p.remaining <= 1) {
        events.add(Released(cycle, p.id, p.start, p.size));
        score = score.copyWith(
          completed: score.completed + 1,
          points: score.points + p.size,
        );
      } else {
        kept.add(p.copyWith(remaining: p.remaining - 1));
      }
    }

    var next = s.copyWith(
      cycle: cycle,
      processes: kept,
      score: score,
      appendEvents: events,
    );

    final aged = [
      for (final r in next.requestQueue) r.withDeadline(r.deadline - 1),
    ];
    next = next.copyWith(
      requestQueue: [
        for (final r in aged)
          if (r.deadline > 0) r,
      ],
    );
    for (final r in aged) {
      if (r.deadline <= 0) {
        next = _fault(next, r, expired: true);
        if (next.status != RunStatus.playing) return next;
      }
    }

    for (final a in arrivals) {
      if (next.requestQueue.length >= rules.maxQueue) {
        next = _fault(next, a, expired: false);
        if (next.status != RunStatus.playing) return next;
        continue;
      }
      next = next.copyWith(
        requestQueue: [...next.requestQueue, a],
        appendEvents: [Arrived(cycle, a.id, a.size)],
      );
    }
    return next;
  }

  /// Records a fault for [r]: it costs a life and the request is gone. The
  /// run ends when no lives are left.
  MemoryState _fault(MemoryState s, Request r, {required bool expired}) {
    final free = s.freeCells;
    final largest = s.largestFreeBlock;
    final FailureKind kind;
    if (!expired) {
      kind = FailureKind.rule;
    } else if (free < r.size) {
      kind = FailureKind.capacity;
    } else if (largest < r.size) {
      kind = FailureKind.fragmentation;
    } else {
      kind = FailureKind.deadline;
    }
    final failure = Failure(
      kind: kind,
      cycle: s.cycle,
      requestId: r.id,
      requestSize: r.size,
      freeCells: free,
      largestFreeBlock: largest,
    );
    final lives = s.livesLeft - 1;
    return s.copyWith(
      status: lives <= 0 ? RunStatus.failed : RunStatus.playing,
      failure: failure,
      livesLeft: lives,
      faultCount: s.faultCount + 1,
      appendEvents: [Failed(failure)],
    );
  }

  /// Slides every movable process toward address 0, preserving order. Pinned
  /// processes stay put and movable ones never cross them. Costs one charge,
  /// points, and [Ruleset.compactionTickCost] ticks during which requests
  /// keep waiting. The moves are decided here; animation only replays them.
  CompactResult compact(MemoryState s) {
    if (s.status != RunStatus.playing) {
      return const CompactResult.rejected(CompactionError.notPlaying);
    }
    if (s.compactionsLeft <= 0) {
      return const CompactResult.rejected(CompactionError.noChargesLeft);
    }
    final moved = <MemoryProcess>[];
    final events = <EngineEvent>[];
    var cursor = 0;
    for (final p in s.processes) {
      if (p.pinned) {
        moved.add(p);
        cursor = p.end;
      } else {
        if (p.start != cursor) {
          events.add(Moved(s.cycle, p.id, p.start, cursor));
        }
        moved.add(p.copyWith(start: cursor));
        cursor += p.size;
      }
    }
    if (events.isEmpty) {
      return const CompactResult.rejected(CompactionError.nothingToMove);
    }
    events.add(Compacted(s.cycle, events.length));
    var next = s.copyWith(
      processes: moved,
      compactionsLeft: s.compactionsLeft - 1,
      score: s.score.copyWith(
        compactions: s.score.compactions + 1,
        points: s.score.points - rules.compactionPointCost,
      ),
      appendEvents: events,
    );
    for (var i = 0; i < rules.compactionTickCost; i++) {
      next = tick(next);
    }
    return CompactResult.ok(next);
  }
}
