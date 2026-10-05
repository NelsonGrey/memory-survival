import 'ruleset.dart';
import 'wave.dart';

/// How a process leaves memory.
enum ReleasePolicy {
  /// Released automatically when its lifetime runs out.
  normal,

  /// An intentional game rule: never released.
  leak,
}

/// A pending allocation request.
class Request {
  const Request({
    required this.id,
    required this.size,
    required this.lifetime,
    required this.deadline,
    this.releasePolicy = ReleasePolicy.normal,
    this.pinned = false,
    this.family = RequestFamily.standard,
    this.lifetimeMin,
    this.lifetimeMax,
    this.linkedWith,
  }) : assert(size > 0),
       assert(lifetime > 0);

  final int id;
  final int size;

  /// Ticks the process lives once placed.
  final int lifetime;

  /// Ticks left before the request fails.
  final int deadline;
  final ReleasePolicy releasePolicy;

  /// A pinned process cannot be moved by compaction.
  final bool pinned;
  final RequestFamily family;

  /// For a volatile request, the range the true [lifetime] is hidden in.
  final int? lifetimeMin;
  final int? lifetimeMax;

  /// For the second half of a linked pair, the id of the first. Both must
  /// end up side by side; the first half has none.
  final int? linkedWith;

  /// Priority requests are worth double.
  int get pointsFactor => family == RequestFamily.priority ? 2 : 1;

  Request withDeadline(int deadline) => Request(
    id: id,
    size: size,
    lifetime: lifetime,
    deadline: deadline,
    releasePolicy: releasePolicy,
    pinned: pinned,
    family: family,
    lifetimeMin: lifetimeMin,
    lifetimeMax: lifetimeMax,
    linkedWith: linkedWith,
  );
}

/// What a block of cells is: a real process, a locked cell, or a region
/// held for a forecast request.
enum ProcessKind { normal, quarantine, reserved }

/// A placed process: one contiguous cell range.
class MemoryProcess {
  const MemoryProcess({
    required this.id,
    required this.size,
    required this.start,
    required this.remaining,
    this.releasePolicy = ReleasePolicy.normal,
    this.pinned = false,
    this.kind = ProcessKind.normal,
    this.reservedFor,
    this.assisted = false,
    this.pointsFactor = 1,
    this.linkedWith,
  });

  /// Quarantines and reservations get negative synthetic ids.
  final int id;
  final int size;
  final int start;

  /// Ticks left; ignored for leaks.
  final int remaining;
  final ReleasePolicy releasePolicy;
  final bool pinned;
  final ProcessKind kind;

  /// For a reservation, the id of the forecast request it is held for.
  final int? reservedFor;

  /// Placed with the one-tap suggestion: earns no multiplier or streak.
  final bool assisted;
  final int pointsFactor;
  final int? linkedWith;

  int get end => start + size;

  bool get isNormal => kind == ProcessKind.normal;

  /// Compaction cannot move pinned processes, locks or reservations.
  bool get immovable => pinned || !isNormal;

  MemoryProcess copyWith({int? start, int? remaining}) => MemoryProcess(
    id: id,
    size: size,
    start: start ?? this.start,
    remaining: remaining ?? this.remaining,
    releasePolicy: releasePolicy,
    pinned: pinned,
    kind: kind,
    reservedFor: reservedFor,
    assisted: assisted,
    pointsFactor: pointsFactor,
    linkedWith: linkedWith,
  );
}

/// A run of free cells.
class Gap {
  const Gap(this.start, this.size);
  final int start;
  final int size;
  int get end => start + size;
}

enum RunStatus {
  playing,
  failed,

  /// Survived to [Ruleset.goalTicks].
  completed,
}

/// Why a request failed, in terms of visible state (MAS-TR-003).
enum FailureKind {
  /// Not enough free cells in total.
  capacity,

  /// Enough free cells in total, but no single gap is large enough.
  fragmentation,

  /// A gap was available but the request was not placed in time.
  deadline,

  /// A declared scenario rule, e.g. queue overflow.
  rule,
}

class Failure {
  const Failure({
    required this.kind,
    required this.cycle,
    required this.requestId,
    required this.requestSize,
    required this.freeCells,
    required this.largestFreeBlock,
  });

  final FailureKind kind;
  final int cycle;
  final int requestId;
  final int requestSize;
  final int freeCells;
  final int largestFreeBlock;
}

class Score {
  const Score({
    this.ticksSurvived = 0,
    this.placed = 0,
    this.completed = 0,
    this.compactions = 0,
    this.points = 0,
    this.peakStreak = 0,
    this.largestRescued = 0,
    this.wavesCleared = 0,
    this.fragmentationWarnings = 0,
    this.rejected = 0,
  });

  final int ticksSurvived;
  final int placed;
  final int completed;
  final int compactions;
  final int points;

  /// Longest run of completed processes without a break.
  final int peakStreak;

  /// Size of the biggest request placed with at most two ticks to spare.
  final int largestRescued;
  final int wavesCleared;

  /// Times fragmentation crossed the warning level.
  final int fragmentationWarnings;
  final int rejected;

  Score copyWith({
    int? ticksSurvived,
    int? placed,
    int? completed,
    int? compactions,
    int? points,
    int? peakStreak,
    int? largestRescued,
    int? wavesCleared,
    int? fragmentationWarnings,
    int? rejected,
  }) => Score(
    ticksSurvived: ticksSurvived ?? this.ticksSurvived,
    placed: placed ?? this.placed,
    completed: completed ?? this.completed,
    compactions: compactions ?? this.compactions,
    points: points ?? this.points,
    peakStreak: peakStreak ?? this.peakStreak,
    largestRescued: largestRescued ?? this.largestRescued,
    wavesCleared: wavesCleared ?? this.wavesCleared,
    fragmentationWarnings: fragmentationWarnings ?? this.fragmentationWarnings,
    rejected: rejected ?? this.rejected,
  );
}

sealed class EngineEvent {
  const EngineEvent(this.cycle);
  final int cycle;
}

class Arrived extends EngineEvent {
  const Arrived(super.cycle, this.requestId, this.size);
  final int requestId;
  final int size;
}

class Placed extends EngineEvent {
  const Placed(super.cycle, this.processId, this.start, this.size);
  final int processId;
  final int start;
  final int size;
}

class Released extends EngineEvent {
  const Released(super.cycle, this.processId, this.start, this.size);
  final int processId;
  final int start;
  final int size;
}

class Moved extends EngineEvent {
  const Moved(super.cycle, this.processId, this.from, this.to);
  final int processId;
  final int from;
  final int to;
}

class Compacted extends EngineEvent {
  const Compacted(super.cycle, this.movedCount);
  final int movedCount;
}

/// A quarantine or reservation timed out and its cells opened up.
class Unlocked extends EngineEvent {
  const Unlocked(super.cycle, this.start, this.size);
  final int start;
  final int size;
}

class Quarantined extends EngineEvent {
  const Quarantined(super.cycle, this.start, this.size);
  final int start;
  final int size;
}

class WaveCleared extends EngineEvent {
  const WaveCleared(
    super.cycle,
    this.wave, {
    required this.clean,
    this.bonus = 0,
  });
  final int wave;

  /// No fault during the storm.
  final bool clean;
  final int bonus;
}

class MultiplierDropped extends EngineEvent {
  const MultiplierDropped(super.cycle, this.reason);
  final String reason;
}

class Rejected extends EngineEvent {
  const Rejected(super.cycle, this.requestId);
  final int requestId;
}

class CleanedUp extends EngineEvent {
  const CleanedUp(super.cycle, this.processId, this.lockedCells);
  final int processId;
  final int lockedCells;
}

class OverclockStarted extends EngineEvent {
  const OverclockStarted(super.cycle);
}

class Reserved extends EngineEvent {
  const Reserved(super.cycle, this.start, this.size, this.requestId);
  final int start;
  final int size;
  final int requestId;
}

class Failed extends EngineEvent {
  Failed(this.failure) : super(failure.cycle);
  final Failure failure;
}

/// The authoritative simulation state. Immutable; every transition returns a
/// new value. Cell ownership is derived from [processes], never stored, so it
/// cannot drift out of sync.
class MemoryState {
  MemoryState({
    required this.rules,
    required this.seed,
    this.cycle = 0,
    List<MemoryProcess> processes = const [],
    List<Request> requestQueue = const [],
    this.compactionsLeft = 0,
    this.score = const Score(),
    this.status = RunStatus.playing,
    this.failure,
    this.livesLeft = 0,
    this.faultCount = 0,
    this.streak = 0,
    this.heat = 0,
    this.overclockLeft = 0,
    this.overclockReadyCycle = 0,
    this.lastFaultCycle = -1000,
    this.lastRejectWave = 0,
    this.nextSyntheticId = -1,
    List<EngineEvent> eventHistory = const [],
  }) : processes = List.unmodifiable(
         [...processes]..sort((a, b) => a.start.compareTo(b.start)),
       ),
       requestQueue = List.unmodifiable(requestQueue),
       eventHistory = List.unmodifiable(eventHistory);

  final Ruleset rules;
  final int seed;
  final int cycle;

  /// Active processes, ordered by start address.
  final List<MemoryProcess> processes;

  /// Pending requests, oldest first.
  final List<Request> requestQueue;
  final int compactionsLeft;
  final Score score;
  final RunStatus status;

  /// The most recent fault, fatal or not.
  final Failure? failure;

  /// Faults a run can still absorb; the run ends when this reaches 0.
  final int livesLeft;

  /// Faults suffered so far this run.
  final int faultCount;

  /// Processes completed since the clean-run multiplier last broke.
  final int streak;

  /// Rises with each fault and cools by surviving a wave cleanly; never
  /// refunds a life.
  final int heat;

  /// Ticks of overclock left (double score, faster arrivals).
  final int overclockLeft;

  /// First cycle overclock can be used again.
  final int overclockReadyCycle;
  final int lastFaultCycle;

  /// The wave number a request was last rejected in; one per wave.
  final int lastRejectWave;

  /// Next id for a quarantine or reservation (counts down from -1).
  final int nextSyntheticId;
  final List<EngineEvent> eventHistory;

  /// Clean-run multiplier, 1..[Ruleset.multiplierMax].
  int get multiplier {
    final tier = 1 + streak ~/ rules.multiplierStep;
    return tier > rules.multiplierMax ? rules.multiplierMax : tier;
  }

  bool get overclocked => overclockLeft > 0;

  /// What positive points are multiplied by.
  int get scoreFactor => multiplier * (overclocked ? 2 : 1);

  /// Completions until the next multiplier tier, or null at the cap.
  int? get completionsToNextTier => multiplier >= rules.multiplierMax
      ? null
      : rules.multiplierStep - streak % rules.multiplierStep;

  /// Whether free space is split enough to threaten the multiplier.
  bool get fragmentationWarning =>
      freeCells >= rules.fragmentationMinFree &&
      fragmentation * 1000 >= rules.fragmentationWarnPerMille;

  WaveInfo get wave => waveAt(rules, cycle);

  /// The active reservation, if any.
  MemoryProcess? get reservation {
    for (final p in processes) {
      if (p.kind == ProcessKind.reserved) return p;
    }
    return null;
  }

  int get cellCount => rules.cellCount;

  /// Owner process id per cell, or null when free. Cells held for a
  /// reservation or locked by quarantine count as owned.
  List<int?> get cells {
    final out = List<int?>.filled(cellCount, null);
    for (final p in processes) {
      for (var i = p.start; i < p.end; i++) {
        out[i] = p.id;
      }
    }
    return out;
  }

  /// Free runs in address order.
  List<Gap> get gaps {
    final out = <Gap>[];
    var cursor = 0;
    for (final p in processes) {
      if (p.start > cursor) out.add(Gap(cursor, p.start - cursor));
      cursor = p.end;
    }
    if (cursor < cellCount) out.add(Gap(cursor, cellCount - cursor));
    return out;
  }

  int get freeCells => gaps.fold(0, (sum, g) => sum + g.size);

  int get largestFreeBlock =>
      gaps.fold(0, (best, g) => g.size > best ? g.size : best);

  int get freeBlockCount => gaps.length;

  /// Fraction of cells in use, 0..1.
  double get utilization => (cellCount - freeCells) / cellCount;

  /// 0 when all free space is one block; approaches 1 as it splinters.
  double get fragmentation {
    final free = freeCells;
    return free == 0 ? 0 : 1 - largestFreeBlock / free;
  }

  Request? requestById(int id) {
    for (final r in requestQueue) {
      if (r.id == id) return r;
    }
    return null;
  }

  MemoryState copyWith({
    int? cycle,
    List<MemoryProcess>? processes,
    List<Request>? requestQueue,
    int? compactionsLeft,
    Score? score,
    RunStatus? status,
    Failure? failure,
    int? livesLeft,
    int? faultCount,
    int? streak,
    int? heat,
    int? overclockLeft,
    int? overclockReadyCycle,
    int? lastFaultCycle,
    int? lastRejectWave,
    int? nextSyntheticId,
    List<EngineEvent>? appendEvents,
  }) => MemoryState(
    rules: rules,
    seed: seed,
    cycle: cycle ?? this.cycle,
    processes: processes ?? this.processes,
    requestQueue: requestQueue ?? this.requestQueue,
    compactionsLeft: compactionsLeft ?? this.compactionsLeft,
    score: score ?? this.score,
    status: status ?? this.status,
    failure: failure ?? this.failure,
    livesLeft: livesLeft ?? this.livesLeft,
    faultCount: faultCount ?? this.faultCount,
    streak: streak ?? this.streak,
    heat: heat ?? this.heat,
    overclockLeft: overclockLeft ?? this.overclockLeft,
    overclockReadyCycle: overclockReadyCycle ?? this.overclockReadyCycle,
    lastFaultCycle: lastFaultCycle ?? this.lastFaultCycle,
    lastRejectWave: lastRejectWave ?? this.lastRejectWave,
    nextSyntheticId: nextSyntheticId ?? this.nextSyntheticId,
    eventHistory: appendEvents == null
        ? eventHistory
        : [...eventHistory, ...appendEvents],
  );
}
