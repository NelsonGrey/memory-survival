import 'ruleset.dart';

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

  Request withDeadline(int deadline) => Request(
    id: id,
    size: size,
    lifetime: lifetime,
    deadline: deadline,
    releasePolicy: releasePolicy,
    pinned: pinned,
  );
}

/// A placed process: one contiguous cell range.
class MemoryProcess {
  const MemoryProcess({
    required this.id,
    required this.size,
    required this.start,
    required this.remaining,
    this.releasePolicy = ReleasePolicy.normal,
    this.pinned = false,
  });

  final int id;
  final int size;
  final int start;

  /// Ticks left; ignored for leaks.
  final int remaining;
  final ReleasePolicy releasePolicy;
  final bool pinned;

  int get end => start + size;

  MemoryProcess copyWith({int? start, int? remaining}) => MemoryProcess(
    id: id,
    size: size,
    start: start ?? this.start,
    remaining: remaining ?? this.remaining,
    releasePolicy: releasePolicy,
    pinned: pinned,
  );
}

/// A run of free cells.
class Gap {
  const Gap(this.start, this.size);
  final int start;
  final int size;
  int get end => start + size;
}

enum RunStatus { playing, failed }

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
  });

  final int ticksSurvived;
  final int placed;
  final int completed;
  final int compactions;
  final int points;

  Score copyWith({
    int? ticksSurvived,
    int? placed,
    int? completed,
    int? compactions,
    int? points,
  }) => Score(
    ticksSurvived: ticksSurvived ?? this.ticksSurvived,
    placed: placed ?? this.placed,
    completed: completed ?? this.completed,
    compactions: compactions ?? this.compactions,
    points: points ?? this.points,
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
  final Failure? failure;
  final List<EngineEvent> eventHistory;

  int get cellCount => rules.cellCount;

  /// Owner process id per cell, or null when free.
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
    eventHistory: appendEvents == null
        ? eventHistory
        : [...eventHistory, ...appendEvents],
  );
}
