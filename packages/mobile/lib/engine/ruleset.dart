/// Process archetypes. Each pressure wave unlocks the next one (see
/// [Ruleset.progressiveFamilies]), so a run gains tactical variety while
/// the allocation model stays the same.
enum RequestFamily {
  /// Plain request: random size and lifetime.
  standard,

  /// Large but short-lived.
  burst,

  /// Small but long-lived.
  resident,

  /// Worth double, but with a short deadline.
  priority,

  /// Lifetime is shown only as a range.
  volatile,

  /// Cannot be moved by compaction.
  pinned,

  /// Two requests that must end up side by side.
  linked,

  /// Never releases on its own; needs a cleanup.
  leak,
}

/// The order families unlock in: wave 2 adds the first, wave 3 the next.
const familyUnlockOrder = <RequestFamily>[
  RequestFamily.burst,
  RequestFamily.resident,
  RequestFamily.priority,
  RequestFamily.volatile,
  RequestFamily.pinned,
  RequestFamily.linked,
  RequestFamily.leak,
];

/// Versioned rules for one simulation. The version is stored with every best
/// score so balance changes never silently compare incompatible runs
/// (TRD section 6).
class Ruleset {
  const Ruleset({
    this.version = currentVersion,
    this.cellCount = 16,
    this.requestDeadline = 8,
    this.minDeadline = 2,
    this.maxQueue = 4,
    this.lives = 3,
    this.compactionCharges = 2,
    this.compactionTickCost = 2,
    this.compactionPointCost = 5,
    this.arrivalPerMille = 400,
    this.arrivalRampPerMille = 30,
    this.arrivalMaxPerMille = 750,
    this.minSize = 1,
    this.maxSize = 5,
    this.minLifetime = 3,
    this.maxLifetime = 9,
    this.familyPerMille = 350,
    this.families = const {
      RequestFamily.burst,
      RequestFamily.resident,
      RequestFamily.priority,
      RequestFamily.volatile,
      RequestFamily.pinned,
      RequestFamily.linked,
      RequestFamily.leak,
    },
    this.progressiveFamilies = true,
    this.wavePeriod = 25,
    this.firstWaveDelay = 20,
    this.warningTicks = 5,
    this.stormTicks = 5,
    this.recoveryTicks = 4,
    this.stormPerMille = 500,
    this.stormRampPerMille = 20,
    this.wavePayout = 10,
    this.multiplierStep = 4,
    this.multiplierMax = 5,
    this.survivalPoints = 1,
    this.tidyBonus = 1,
    this.fragmentationWarnPerMille = 500,
    this.fragmentationMinFree = 4,
    this.heatDeadlinePenalty = 1,
    this.heatQuarantineAt = 2,
    this.quarantineTicks = 8,
    this.overclockTicks = 10,
    this.overclockCooldown = 20,
    this.overclockBonusPerMille = 250,
    this.reserveTicks = 8,
    this.cleanupLockTicks = 6,
    this.cleanupPointCost = 3,
    this.goalTicks = 0,
  }) : assert(cellCount > 0),
       assert(requestDeadline > 0),
       assert(maxQueue > 0),
       assert(lives > 0),
       assert(minSize > 0 && minSize <= maxSize),
       assert(minLifetime > 0 && minLifetime <= maxLifetime),
       assert(multiplierStep > 0 && multiplierMax >= 1);

  /// Bump whenever any rule or default balance value changes.
  static const currentVersion = 5;

  final int version;

  /// Number of addressable cells in the strip.
  final int cellCount;

  /// Ticks a request may wait in the queue before it fails.
  final int requestDeadline;

  /// Heat and priority never shorten a deadline below this.
  final int minDeadline;

  /// A request arriving to a full queue of this length is refused (a fault).
  final int maxQueue;

  /// Faults a run survives: an expired or refused request costs one, and the
  /// run ends when none are left.
  final int lives;

  /// Compactions available per run.
  final int compactionCharges;

  /// Ticks that elapse while compaction runs. Arrivals and lifetimes keep
  /// going; the player just cannot act.
  final int compactionTickCost;

  /// Points deducted per compaction.
  final int compactionPointCost;

  // Seeded generator parameters (endless mode).

  /// Chance per calm tick, in thousandths, during wave 1.
  final int arrivalPerMille;

  /// Added to the calm chance with every wave, up to [arrivalMaxPerMille].
  final int arrivalRampPerMille;
  final int arrivalMaxPerMille;
  final int minSize;
  final int maxSize;
  final int minLifetime;
  final int maxLifetime;

  /// Share of arrivals that belong to a non-standard family.
  final int familyPerMille;

  /// Families a run may draw from.
  final Set<RequestFamily> families;

  /// When true each wave unlocks one more family from [familyUnlockOrder];
  /// when false every family in [families] is available from the start.
  final bool progressiveFamilies;

  // Pressure waves. A [wavePeriod] of 0 disables them.

  /// Ticks between storms.
  final int wavePeriod;

  /// Extra calm ticks before wave 1, so a new player gets a longer runway.
  final int firstWaveDelay;
  final int warningTicks;
  final int stormTicks;

  /// Ticks with no arrivals after a storm.
  final int recoveryTicks;

  /// Arrival chance during a wave-1 storm; rises by [stormRampPerMille].
  final int stormPerMille;
  final int stormRampPerMille;

  /// Base bonus for surviving a storm without a fault, times the wave
  /// number and the score factor.
  final int wavePayout;

  // Scoring.

  /// Completed processes needed to climb one multiplier tier.
  final int multiplierStep;
  final int multiplierMax;

  /// Points per surviving tick, times the score factor.
  final int survivalPoints;

  /// Extra points for a placement that does not split a free gap.
  final int tidyBonus;

  /// Fragmentation (1 - largest/free, in thousandths) at which the clean
  /// run multiplier drops a tier, once at least [fragmentationMinFree]
  /// cells are free.
  final int fragmentationWarnPerMille;
  final int fragmentationMinFree;

  // Faults raise heat: shorter deadlines, then a quarantined cell.

  /// Ticks shaved off every new deadline while the system is hot.
  final int heatDeadlinePenalty;

  /// Heat at which a fault also quarantines a free cell.
  final int heatQuarantineAt;
  final int quarantineTicks;

  // Risk and reward.
  final int overclockTicks;
  final int overclockCooldown;
  final int overclockBonusPerMille;

  /// Ticks a reservation holds a region for a forecast request.
  final int reserveTicks;

  /// Ticks half of a cleaned-up leak's cells stay locked.
  final int cleanupLockTicks;
  final int cleanupPointCost;

  /// Ticks to survive to complete the run; 0 means endless.
  final int goalTicks;

  bool get hasWaves => wavePeriod > 0;

  Ruleset copyWith({
    int? cellCount,
    int? requestDeadline,
    int? maxQueue,
    int? lives,
    int? compactionCharges,
    int? arrivalPerMille,
    int? arrivalRampPerMille,
    int? arrivalMaxPerMille,
    int? minSize,
    int? maxSize,
    int? minLifetime,
    int? maxLifetime,
    int? familyPerMille,
    Set<RequestFamily>? families,
    bool? progressiveFamilies,
    int? wavePeriod,
    int? stormPerMille,
    int? goalTicks,
  }) => Ruleset(
    version: version,
    cellCount: cellCount ?? this.cellCount,
    requestDeadline: requestDeadline ?? this.requestDeadline,
    minDeadline: minDeadline,
    maxQueue: maxQueue ?? this.maxQueue,
    lives: lives ?? this.lives,
    compactionCharges: compactionCharges ?? this.compactionCharges,
    compactionTickCost: compactionTickCost,
    compactionPointCost: compactionPointCost,
    arrivalPerMille: arrivalPerMille ?? this.arrivalPerMille,
    arrivalRampPerMille: arrivalRampPerMille ?? this.arrivalRampPerMille,
    arrivalMaxPerMille: arrivalMaxPerMille ?? this.arrivalMaxPerMille,
    minSize: minSize ?? this.minSize,
    maxSize: maxSize ?? this.maxSize,
    minLifetime: minLifetime ?? this.minLifetime,
    maxLifetime: maxLifetime ?? this.maxLifetime,
    familyPerMille: familyPerMille ?? this.familyPerMille,
    families: families ?? this.families,
    progressiveFamilies: progressiveFamilies ?? this.progressiveFamilies,
    wavePeriod: wavePeriod ?? this.wavePeriod,
    firstWaveDelay: firstWaveDelay,
    warningTicks: warningTicks,
    stormTicks: stormTicks,
    recoveryTicks: recoveryTicks,
    stormPerMille: stormPerMille ?? this.stormPerMille,
    stormRampPerMille: stormRampPerMille,
    wavePayout: wavePayout,
    multiplierStep: multiplierStep,
    multiplierMax: multiplierMax,
    survivalPoints: survivalPoints,
    tidyBonus: tidyBonus,
    fragmentationWarnPerMille: fragmentationWarnPerMille,
    fragmentationMinFree: fragmentationMinFree,
    heatDeadlinePenalty: heatDeadlinePenalty,
    heatQuarantineAt: heatQuarantineAt,
    quarantineTicks: quarantineTicks,
    overclockTicks: overclockTicks,
    overclockCooldown: overclockCooldown,
    overclockBonusPerMille: overclockBonusPerMille,
    reserveTicks: reserveTicks,
    cleanupLockTicks: cleanupLockTicks,
    cleanupPointCost: cleanupPointCost,
    goalTicks: goalTicks ?? this.goalTicks,
  );
}
