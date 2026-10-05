import 'model.dart';
import 'ruleset.dart';
import 'wave.dart';

/// Why a placement was refused. Each reason is explainable from visible state.
enum PlacementError {
  notPlaying,
  unknownRequest,
  outOfBounds,

  /// At least one required cell is owned by another process.
  occupied,

  /// One half of a linked pair must sit directly beside the other.
  notAdjacent,
}

class PlaceResult {
  const PlaceResult.ok(MemoryState this.state)
    : error = null,
      blockedBy = null,
      linkedTo = null;
  const PlaceResult.rejected(
    PlacementError this.error, {
    this.blockedBy,
    this.linkedTo,
  }) : state = null;

  final MemoryState? state;
  final PlacementError? error;

  /// For [PlacementError.occupied]: id of the first process in the way.
  final int? blockedBy;

  /// For [PlacementError.notAdjacent]: the id it has to sit beside.
  final int? linkedTo;

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

/// Why an optional action (reject, overclock, reserve, cleanup) was refused.
enum ActionError {
  notPlaying,
  unknownTarget,
  notALeak,

  /// Already used this wave (reject) or still cooling down (overclock).
  unavailable,

  /// A reservation is already held.
  alreadyReserved,

  /// The region to reserve is not entirely free.
  regionBusy,
  outOfBounds,
}

class ActionResult {
  const ActionResult.ok(MemoryState this.state) : error = null;
  const ActionResult.rejected(ActionError this.error) : state = null;

  final MemoryState? state;
  final ActionError? error;
  bool get isOk => state != null;
}

/// Supplies the arrivals for a tick. The engine never rolls dice itself, so
/// a caller (the seeded generator, or a scenario script) provides them.
typedef ArrivalSource = List<Request> Function(int cycle);

/// What a placement would leave behind, for previews.
class PlacementPreview {
  const PlacementPreview(this.largestFreeBlock, this.freeBlockCount);
  final int largestFreeBlock;
  final int freeBlockCount;
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

  // ---------------------------------------------------------------------
  // Placement

  /// Whether [request] fits at [start], without changing anything.
  PlacementError? validate(MemoryState s, Request request, int start) {
    if (start < 0 || start + request.size > s.cellCount) {
      return PlacementError.outOfBounds;
    }
    if (_blocker(s, request, start) != null) return PlacementError.occupied;
    return _linkError(s, request, start) == null
        ? null
        : PlacementError.notAdjacent;
  }

  /// Every start address where [request] could be placed right now.
  List<int> validStarts(MemoryState s, Request request) => [
    for (var i = 0; i + request.size <= s.cellCount; i++)
      if (validate(s, request, i) == null) i,
  ];

  /// The first process in the way of [request] at [start]. A reservation
  /// held for this very request is not in the way.
  MemoryProcess? _blocker(MemoryState s, Request request, int start) {
    final end = start + request.size;
    for (final p in s.processes) {
      if (p.start < end && start < p.end) {
        if (p.kind == ProcessKind.reserved && p.reservedFor == request.id) {
          continue;
        }
        return p;
      }
    }
    return null;
  }

  /// For a linked request whose partner is already placed: the partner's id
  /// when [start] is not directly beside it, else null.
  int? _linkError(MemoryState s, Request request, int start) {
    for (final p in s.processes) {
      final linked =
          p.id == request.linkedWith ||
          (p.linkedWith != null && p.linkedWith == request.id);
      if (!linked || !p.isNormal) continue;
      final beside = start == p.end || start + request.size == p.start;
      return beside ? null : p.id;
    }
    return null;
  }

  PlaceResult place(
    MemoryState s,
    int requestId,
    int start, {
    bool assisted = false,
  }) {
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
    final blocker = _blocker(s, request, start);
    if (blocker != null) {
      return PlaceResult.rejected(
        PlacementError.occupied,
        blockedBy: blocker.id,
      );
    }
    final linkedTo = _linkError(s, request, start);
    if (linkedTo != null) {
      return PlaceResult.rejected(
        PlacementError.notAdjacent,
        linkedTo: linkedTo,
      );
    }

    final blocksBefore = s.freeBlockCount;
    final kept = [
      for (final p in s.processes)
        if (!(p.kind == ProcessKind.reserved && p.reservedFor == request.id)) p,
    ];
    final process = MemoryProcess(
      id: request.id,
      size: request.size,
      start: start,
      remaining: request.lifetime,
      releasePolicy: request.releasePolicy,
      pinned: request.pinned,
      assisted: assisted,
      pointsFactor: request.pointsFactor,
      linkedWith: request.linkedWith,
    );
    final placed = s.copyWith(
      processes: [...kept, process],
      requestQueue: [
        for (final r in s.requestQueue)
          if (r.id != requestId) r,
      ],
    );
    final tidy = placed.freeBlockCount <= blocksBefore;
    final factor = assisted ? 1 : s.scoreFactor;
    final points =
        request.size * factor +
        (tidy && !assisted ? rules.tidyBonus * factor : 0);
    final rescued =
        request.deadline <= 2 && request.size > s.score.largestRescued;
    return PlaceResult.ok(
      placed.copyWith(
        score: s.score.copyWith(
          placed: s.score.placed + 1,
          points: s.score.points + points,
          largestRescued: rescued ? request.size : null,
        ),
        appendEvents: [Placed(s.cycle, request.id, start, request.size)],
      ),
    );
  }

  /// What the strip would look like after placing [request] at [start], or
  /// null if it does not fit there.
  PlacementPreview? previewPlacement(
    MemoryState s,
    Request request,
    int start,
  ) {
    if (validate(s, request, start) != null) return null;
    final r = place(s, request.id, start);
    final after = r.state;
    if (after == null) return null;
    return PlacementPreview(after.largestFreeBlock, after.freeBlockCount);
  }

  /// The one-tap suggestion: the tidiest edge of the tightest fitting gap.
  /// It keeps the biggest block free, which is a fine move but a predictable
  /// one, so it scores less than choosing for yourself.
  int? recommendedStart(MemoryState s, Request request) {
    int? best;
    PlacementPreview? bestPreview;
    int bestGap = 1 << 30;
    for (final g in s.gaps) {
      if (g.size < request.size) continue;
      for (final start in {g.start, g.end - request.size}) {
        final pv = previewPlacement(s, request, start);
        if (pv == null) continue;
        final better =
            bestPreview == null ||
            pv.freeBlockCount < bestPreview.freeBlockCount ||
            (pv.freeBlockCount == bestPreview.freeBlockCount &&
                (g.size < bestGap ||
                    (g.size == bestGap &&
                        pv.largestFreeBlock > bestPreview.largestFreeBlock)));
        if (better) {
          best = start;
          bestPreview = pv;
          bestGap = g.size;
        }
      }
    }
    return best;
  }

  // ---------------------------------------------------------------------
  // Time

  /// Advances one tick: processes age and release, waiting requests age (an
  /// expired one is a fault), a wave may pay out, then [arrivals] join the
  /// queue.
  MemoryState tick(MemoryState s, {List<Request> arrivals = const []}) {
    if (s.status != RunStatus.playing) return s;
    final cycle = s.cycle + 1;
    final events = <EngineEvent>[];
    final factorAtStart = s.scoreFactor;
    var streak = s.streak;
    var score = s.score.copyWith(
      ticksSurvived: s.score.ticksSurvived + 1,
      points: s.score.points + rules.survivalPoints * factorAtStart,
    );

    final kept = <MemoryProcess>[];
    for (final p in s.processes) {
      if (!p.isNormal) {
        if (p.remaining <= 1) {
          events.add(Unlocked(cycle, p.start, p.size));
        } else {
          kept.add(p.copyWith(remaining: p.remaining - 1));
        }
      } else if (p.releasePolicy == ReleasePolicy.leak) {
        kept.add(p);
      } else if (p.remaining <= 1) {
        events.add(Released(cycle, p.id, p.start, p.size));
        final factor = p.assisted ? 1 : factorAtStart;
        score = score.copyWith(
          completed: score.completed + 1,
          points: score.points + p.size * p.pointsFactor * factor,
        );
        if (!p.assisted) streak++;
      } else {
        kept.add(p.copyWith(remaining: p.remaining - 1));
      }
    }
    if (streak > score.peakStreak) score = score.copyWith(peakStreak: streak);

    final queueWasFull = s.requestQueue.length >= rules.maxQueue;
    var next = s.copyWith(
      cycle: cycle,
      processes: kept,
      score: score,
      streak: streak,
      overclockLeft: s.overclockLeft > 0 ? s.overclockLeft - 1 : 0,
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

    next = _settleWave(next);

    for (final raw in arrivals) {
      final a = _heated(next, raw);
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

    if (!queueWasFull && next.requestQueue.length >= rules.maxQueue) {
      next = _dropTier(next, 'The waiting list filled up.');
    }
    if (!s.fragmentationWarning && next.fragmentationWarning) {
      next = _dropTier(
        next,
        'Free memory is split into pieces.',
        warning: true,
      );
    }

    if (rules.goalTicks > 0 && next.cycle >= rules.goalTicks) {
      next = next.copyWith(status: RunStatus.completed);
    }
    return next;
  }

  /// While the system is hot every new deadline is shorter.
  Request _heated(MemoryState s, Request r) {
    if (s.heat <= 0) return r;
    final shorter = (r.deadline - rules.heatDeadlinePenalty).clamp(
      rules.minDeadline,
      r.deadline,
    );
    return r.withDeadline(shorter);
  }

  /// At the end of a storm, pays out a clean one and cools the system.
  MemoryState _settleWave(MemoryState s) {
    final period = rules.wavePeriod;
    if (period <= 0 || s.cycle % period != 0) return s;
    final wave = s.cycle ~/ period;
    final clean = s.lastFaultCycle < s.cycle - rules.stormTicks;
    if (!clean) {
      return s.copyWith(
        appendEvents: [WaveCleared(s.cycle, wave, clean: false)],
      );
    }
    final bonus = rules.wavePayout * wave * s.scoreFactor;
    return s.copyWith(
      heat: s.heat > 0 ? s.heat - 1 : 0,
      score: s.score.copyWith(
        points: s.score.points + bonus,
        wavesCleared: s.score.wavesCleared + 1,
      ),
      appendEvents: [WaveCleared(s.cycle, wave, clean: true, bonus: bonus)],
    );
  }

  /// Lowers the multiplier one tier (never below 1).
  MemoryState _dropTier(MemoryState s, String reason, {bool warning = false}) {
    final tiers = s.streak ~/ rules.multiplierStep;
    final next = s.copyWith(
      streak: tiers > 0 ? (tiers - 1) * rules.multiplierStep : 0,
      score: warning
          ? s.score.copyWith(
              fragmentationWarnings: s.score.fragmentationWarnings + 1,
            )
          : null,
      appendEvents: tiers > 0 ? [MultiplierDropped(s.cycle, reason)] : null,
    );
    return next;
  }

  /// Records a fault for [r]: it costs a life, raises heat and breaks the
  /// multiplier; the request is gone. The run ends when no lives are left.
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
    final heat = s.heat + 1;
    var next = s.copyWith(
      status: lives <= 0 ? RunStatus.failed : RunStatus.playing,
      failure: failure,
      livesLeft: lives,
      faultCount: s.faultCount + 1,
      heat: heat,
      streak: 0,
      lastFaultCycle: s.cycle,
      processes: _withoutReservationFor(s, r.id),
      appendEvents: [Failed(failure)],
    );
    if (lives > 0 && heat >= rules.heatQuarantineAt) {
      next = _quarantineCell(next);
    }
    return next;
  }

  List<MemoryProcess> _withoutReservationFor(MemoryState s, int requestId) => [
    for (final p in s.processes)
      if (!(p.kind == ProcessKind.reserved && p.reservedFor == requestId)) p,
  ];

  /// Locks one free cell in the middle of the biggest gap, where it hurts
  /// most.
  MemoryState _quarantineCell(MemoryState s) {
    Gap? widest;
    for (final g in s.gaps) {
      if (widest == null || g.size > widest.size) widest = g;
    }
    if (widest == null) return s;
    final start = widest.start + widest.size ~/ 2;
    return s.copyWith(
      processes: [
        ...s.processes,
        MemoryProcess(
          id: s.nextSyntheticId,
          size: 1,
          start: start,
          remaining: rules.quarantineTicks + 1,
          kind: ProcessKind.quarantine,
        ),
      ],
      nextSyntheticId: s.nextSyntheticId - 1,
      appendEvents: [Quarantined(s.cycle, start, 1)],
    );
  }

  // ---------------------------------------------------------------------
  // Compaction

  /// Slides every movable process toward address 0, preserving order. Pinned
  /// processes, locks and reservations stay put and movable ones never cross
  /// them. Costs one charge, points, a multiplier tier, and
  /// [Ruleset.compactionTickCost] ticks during which lifetimes run down and,
  /// when [arrivals] is given, new requests keep arriving. The moves are
  /// decided here; animation only replays them.
  CompactResult compact(MemoryState s, {ArrivalSource? arrivals}) {
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
      if (p.immovable) {
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
    next = _dropTier(next, 'You compacted memory.');
    for (var i = 0; i < rules.compactionTickCost; i++) {
      next = tick(next, arrivals: arrivals?.call(next.cycle + 1) ?? const []);
    }
    return CompactResult.ok(next);
  }

  // ---------------------------------------------------------------------
  // Risk and reward

  /// Turns away a waiting request without a fault, at the price of the
  /// multiplier. Once per wave.
  ActionResult reject(MemoryState s, int requestId) {
    if (s.status != RunStatus.playing) {
      return const ActionResult.rejected(ActionError.notPlaying);
    }
    if (s.requestById(requestId) == null) {
      return const ActionResult.rejected(ActionError.unknownTarget);
    }
    final wave = s.wave.number;
    if (rules.hasWaves && s.lastRejectWave == wave) {
      return const ActionResult.rejected(ActionError.unavailable);
    }
    return ActionResult.ok(
      s.copyWith(
        requestQueue: [
          for (final r in s.requestQueue)
            if (r.id != requestId) r,
        ],
        processes: _withoutReservationFor(s, requestId),
        streak: 0,
        lastRejectWave: wave,
        score: s.score.copyWith(rejected: s.score.rejected + 1),
        appendEvents: [Rejected(s.cycle, requestId)],
      ),
    );
  }

  /// Double score and faster arrivals for [Ruleset.overclockTicks], then a
  /// cooldown.
  ActionResult overclock(MemoryState s) {
    if (s.status != RunStatus.playing) {
      return const ActionResult.rejected(ActionError.notPlaying);
    }
    if (s.overclocked || s.cycle < s.overclockReadyCycle) {
      return const ActionResult.rejected(ActionError.unavailable);
    }
    return ActionResult.ok(
      s.copyWith(
        overclockLeft: rules.overclockTicks,
        overclockReadyCycle:
            s.cycle + rules.overclockTicks + rules.overclockCooldown,
        appendEvents: [OverclockStarted(s.cycle)],
      ),
    );
  }

  /// Holds [size] free cells at [start] for the forecast request
  /// [forRequestId], keeping everyone else out until it arrives or
  /// [Ruleset.reserveTicks] pass. The cells are unusable meanwhile.
  ActionResult reserve(
    MemoryState s, {
    required int start,
    required int size,
    required int forRequestId,
  }) {
    if (s.status != RunStatus.playing) {
      return const ActionResult.rejected(ActionError.notPlaying);
    }
    if (s.reservation != null) {
      return const ActionResult.rejected(ActionError.alreadyReserved);
    }
    if (size <= 0 || start < 0 || start + size > s.cellCount) {
      return const ActionResult.rejected(ActionError.outOfBounds);
    }
    for (final p in s.processes) {
      if (p.start < start + size && start < p.end) {
        return const ActionResult.rejected(ActionError.regionBusy);
      }
    }
    return ActionResult.ok(
      s.copyWith(
        processes: [
          ...s.processes,
          MemoryProcess(
            id: s.nextSyntheticId,
            size: size,
            start: start,
            remaining: rules.reserveTicks + 1,
            kind: ProcessKind.reserved,
            reservedFor: forRequestId,
          ),
        ],
        nextSyntheticId: s.nextSyntheticId - 1,
        appendEvents: [Reserved(s.cycle, start, size, forRequestId)],
      ),
    );
  }

  /// Ends a leaking process. Half of its cells (rounded up) stay locked for
  /// [Ruleset.cleanupLockTicks], and it costs points.
  ActionResult cleanup(MemoryState s, int processId) {
    if (s.status != RunStatus.playing) {
      return const ActionResult.rejected(ActionError.notPlaying);
    }
    MemoryProcess? target;
    for (final p in s.processes) {
      if (p.id == processId && p.isNormal) target = p;
    }
    if (target == null) {
      return const ActionResult.rejected(ActionError.unknownTarget);
    }
    if (target.releasePolicy != ReleasePolicy.leak) {
      return const ActionResult.rejected(ActionError.notALeak);
    }
    final locked = (target.size + 1) ~/ 2;
    return ActionResult.ok(
      s.copyWith(
        processes: [
          for (final p in s.processes)
            if (p.id != processId) p,
          MemoryProcess(
            id: s.nextSyntheticId,
            size: locked,
            start: target.start,
            remaining: rules.cleanupLockTicks + 1,
            kind: ProcessKind.quarantine,
          ),
        ],
        nextSyntheticId: s.nextSyntheticId - 1,
        score: s.score.copyWith(
          points: s.score.points - rules.cleanupPointCost,
        ),
        appendEvents: [
          Released(s.cycle, target.id, target.start, target.size),
          CleanedUp(s.cycle, target.id, locked),
        ],
      ),
    );
  }

  /// Wave info for the next tick, for callers deciding arrivals.
  WaveInfo upcomingWave(MemoryState s) => waveAt(rules, s.cycle + 1);
}
