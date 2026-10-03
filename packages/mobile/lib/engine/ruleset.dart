/// Versioned rules for one simulation. The version is stored with every best
/// score so balance changes never silently compare incompatible runs
/// (TRD section 6).
class Ruleset {
  const Ruleset({
    this.version = currentVersion,
    this.cellCount = 16,
    this.requestDeadline = 6,
    this.maxQueue = 4,
    this.compactionCharges = 2,
    this.compactionTickCost = 2,
    this.compactionPointCost = 5,
    this.arrivalPerMille = 350,
    this.arrivalRampPerMille = 100,
    this.arrivalMaxPerMille = 800,
    this.minSize = 1,
    this.maxSize = 5,
    this.minLifetime = 3,
    this.maxLifetime = 9,
    this.leakPerMille = 0,
    this.pinnedPerMille = 0,
  }) : assert(cellCount > 0),
       assert(requestDeadline > 0),
       assert(maxQueue > 0),
       assert(minSize > 0 && minSize <= maxSize),
       assert(minLifetime > 0 && minLifetime <= maxLifetime);

  /// Bump whenever any rule or default balance value changes.
  static const currentVersion = 2;

  final int version;

  /// Number of addressable cells in the strip.
  final int cellCount;

  /// Ticks a request may wait in the queue before it fails.
  final int requestDeadline;

  /// A request that would push the queue past this length ends the run.
  final int maxQueue;

  /// Compactions available per run.
  final int compactionCharges;

  /// Ticks that elapse (requests keep waiting) while compaction runs.
  final int compactionTickCost;

  /// Points deducted per compaction.
  final int compactionPointCost;

  // Seeded generator parameters (endless mode).

  /// Chance per tick, in thousandths, that a request arrives at tick 0.
  final int arrivalPerMille;

  /// Added to the arrival chance for every 100 ticks survived, so every
  /// endless run eventually ends, up to [arrivalMaxPerMille].
  final int arrivalRampPerMille;
  final int arrivalMaxPerMille;
  final int minSize;
  final int maxSize;
  final int minLifetime;
  final int maxLifetime;
  final int leakPerMille;
  final int pinnedPerMille;
}
